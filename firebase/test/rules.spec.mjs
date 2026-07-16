// Firestore + Storage security-rules tests (F36).
//
// Runs against the local emulator via @firebase/rules-unit-testing and the
// Node built-in test runner (no mocha/jest dependency):
//
//   cd firebase
//   firebase emulators:exec --only firestore,storage \
//     "npm --prefix test install && npm --prefix test test"
//
// Scope: the security-critical matches — user isolation, the admin-editable
// legalityRules collection (P0-2 write surface), the userSaves owner-list
// clause added for the Saved Places screen (F30), notification field
// clamping, behaviorEvents identity pinning, and the recommendations/ photo
// path in Storage (F15).
//
// NOTE (offline honesty): these tests are AUTHORED here and executed by the
// `firestore-rules` CI job; the remediation environment had no network to
// install the emulator, so first execution happens in CI.

import { test, before, after, beforeEach } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc,
  collection, query, where, orderBy, getDocs,
} from "firebase/firestore";
import { ref as sRef, uploadBytes, getBytes, deleteObject } from "firebase/storage";

let env;

const APPROVED = { accountStatus: "approved", rank: "CA" };
const PENDING  = { accountStatus: "pending",  rank: "CA" };
const ADMIN    = { ...APPROVED, admin: true, privileges: ["approve_users"] };
const SUPER    = { ...APPROVED, superAdmin: true };

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "cip-najm-rules-test",
    firestore: { rules: readFileSync("../firestore.rules", "utf8") },
    storage:   { rules: readFileSync("../storage.rules",   "utf8") },
  });
});

after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
});

const db = (uid, claims) =>
  uid ? env.authenticatedContext(uid, claims).firestore()
      : env.unauthenticatedContext().firestore();
const storage = (uid, claims) =>
  uid ? env.authenticatedContext(uid, claims).storage()
      : env.unauthenticatedContext().storage();

/** Seed data bypassing rules. */
const seed = (fn) => env.withSecurityRulesDisabled((ctx) => fn(ctx.firestore()));

// ─── users ───────────────────────────────────────────────────────────────────

test("users: owner reads own doc; stranger cannot; admin can", async () => {
  await seed((d) => setDoc(doc(d, "users/alice"), { name: "Alice" }));
  await assertSucceeds(getDoc(doc(db("alice", APPROVED), "users/alice")));
  await assertFails(getDoc(doc(db("bob", APPROVED), "users/alice")));
  await assertSucceeds(getDoc(doc(db("root", ADMIN), "users/alice")));
});

test("users: self-signup must be pending and carry required keys", async () => {
  const me = db("carol", PENDING);
  await assertSucceeds(setDoc(doc(me, "users/carol"), {
    crewId: "12345", name: "Carol", email: "c@x.com",
    rankCode: "FA", accountStatus: "pending",
  }));
  // self-approval on create is rejected
  await assertFails(setDoc(doc(db("dave", PENDING), "users/dave"), {
    crewId: "9", name: "Dave", email: "d@x.com",
    rankCode: "FA", accountStatus: "approved",
  }));
});

test("users: owner cannot self-promote accountStatus via update", async () => {
  await seed((d) => setDoc(doc(d, "users/erin"),
    { name: "Erin", accountStatus: "pending" }));
  await assertFails(updateDoc(doc(db("erin", PENDING), "users/erin"),
    { accountStatus: "approved" }));
});

// ─── legalityRules (P0-2 write surface) ──────────────────────────────────────

test("legalityRules: approved read yes; pending read no", async () => {
  await seed((d) => setDoc(doc(d, "legalityRules/min_rest_domestic_hours"),
    { value: 14 }));
  await assertSucceeds(getDoc(doc(db("alice", APPROVED),
    "legalityRules/min_rest_domestic_hours")));
  await assertFails(getDoc(doc(db("newbie", PENDING),
    "legalityRules/min_rest_domestic_hours")));
});

test("legalityRules: only superAdmin writes; plain admin and users denied", async () => {
  const path = "legalityRules/min_rest_domestic_hours";
  await assertSucceeds(setDoc(doc(db("root", SUPER), path), { value: 14.5 }));
  await assertFails(setDoc(doc(db("mod", ADMIN), path), { value: 1 }));
  await assertFails(setDoc(doc(db("alice", APPROVED), path), { value: 1 }));
});

// ─── userSaves (F30 owner-list clause) ───────────────────────────────────────

test("userSaves: owner writes own {uid}_{recId} doc; forged docId denied", async () => {
  const me = db("alice", APPROVED);
  await assertSucceeds(setDoc(doc(me, "userSaves/alice_rec1"),
    { userId: "alice", recId: "rec1", createdAt: new Date() }));
  await assertFails(setDoc(doc(me, "userSaves/bob_rec1"),
    { userId: "bob", recId: "rec1", createdAt: new Date() }));
});

test("userSaves: owner list query allowed; someone else's list denied", async () => {
  await seed(async (d) => {
    await setDoc(doc(d, "userSaves/alice_rec1"),
      { userId: "alice", recId: "rec1", createdAt: new Date() });
    await setDoc(doc(d, "userSaves/alice_rec2"),
      { userId: "alice", recId: "rec2", createdAt: new Date() });
  });
  const mine = query(collection(db("alice", APPROVED), "userSaves"),
    where("userId", "==", "alice"), orderBy("createdAt", "desc"));
  await assertSucceeds(getDocs(mine));

  const theirs = query(collection(db("bob", APPROVED), "userSaves"),
    where("userId", "==", "alice"));
  await assertFails(getDocs(theirs));
});

// ─── notifications ───────────────────────────────────────────────────────────

test("notifications: owner may only flip 'read'; other fields clamped", async () => {
  await seed((d) => setDoc(doc(d, "notifications/n1"),
    { userId: "alice", title: "Hi", read: false }));
  const mine = db("alice", APPROVED);
  await assertSucceeds(updateDoc(doc(mine, "notifications/n1"), { read: true }));
  await assertFails(updateDoc(doc(mine, "notifications/n1"),
    { title: "forged" }));
  await assertFails(getDoc(doc(db("bob", APPROVED), "notifications/n1")));
});

// ─── behaviorEvents ──────────────────────────────────────────────────────────

test("behaviorEvents: create pinned to own uid; reads admin-only; immutable", async () => {
  const me = db("alice", APPROVED);
  await assertSucceeds(setDoc(doc(me, "behaviorEvents/e1"),
    { userId: "alice", eventType: "line_viewed", timestamp: new Date() }));
  await assertFails(setDoc(doc(me, "behaviorEvents/e2"),
    { userId: "bob", eventType: "line_viewed", timestamp: new Date() }));
  await assertFails(getDoc(doc(me, "behaviorEvents/e1")));
  await assertSucceeds(getDoc(doc(db("root", ADMIN), "behaviorEvents/e1")));
  await assertFails(updateDoc(doc(db("root", SUPER), "behaviorEvents/e1"),
    { eventType: "x" }));
});

// ─── Storage: recommendations/ photos (F15) ─────────────────────────────────

test("storage recommendations/: authed image ≤5MB create OK; oversize/PDF/anon denied", async () => {
  const small = new Uint8Array(1024);
  const okRef = sRef(storage("alice", APPROVED), "recommendations/p1.jpg");
  await assertSucceeds(uploadBytes(okRef, small, { contentType: "image/jpeg" }));

  const big = new Uint8Array(5 * 1024 * 1024 + 1);
  await assertFails(uploadBytes(
    sRef(storage("alice", APPROVED), "recommendations/p2.jpg"),
    big, { contentType: "image/jpeg" }));

  await assertFails(uploadBytes(
    sRef(storage("alice", APPROVED), "recommendations/p3.pdf"),
    small, { contentType: "application/pdf" }));

  await assertFails(uploadBytes(
    sRef(storage(null), "recommendations/p4.jpg"),
    small, { contentType: "image/jpeg" }));
});

test("storage recommendations/: read requires auth; delete admin-only", async () => {
  const bytes = new Uint8Array(64);
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(sRef(ctx.storage(), "recommendations/seeded.jpg"),
      bytes, { contentType: "image/jpeg" });
  });
  await assertSucceeds(getBytes(
    sRef(storage("alice", APPROVED), "recommendations/seeded.jpg")));
  await assertFails(getBytes(
    sRef(storage(null), "recommendations/seeded.jpg")));
  await assertFails(deleteObject(
    sRef(storage("alice", APPROVED), "recommendations/seeded.jpg")));
  await assertSucceeds(deleteObject(
    sRef(storage("root", { ...APPROVED, admin: true }), "recommendations/seeded.jpg")));
});

// ─── Storage: roster path unchanged behavior ─────────────────────────────────

test("storage rosters/: owner Excel OK; wrong type / wrong owner denied", async () => {
  const bytes = new Uint8Array(128);
  const xlsx = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
  await assertSucceeds(uploadBytes(
    sRef(storage("alice", APPROVED), "users/alice/rosters/june.xlsx"),
    bytes, { contentType: xlsx }));
  await assertFails(uploadBytes(
    sRef(storage("alice", APPROVED), "users/alice/rosters/june.pdf"),
    bytes, { contentType: "application/pdf" }));
  await assertFails(uploadBytes(
    sRef(storage("bob", APPROVED), "users/alice/rosters/evil.xlsx"),
    bytes, { contentType: xlsx }));
});

// ── Roster sync collections (v1.4.0-dev) ────────────────────────────────────
test("rosterSources: owner can read own connection, cannot write", async () => {
  await withAdmin(async (db) => {
    await db.doc("rosterSources/alice_ics_feed").set({
      user_id: "alice", provider_id: "ics_feed", status: "connected",
    });
  });
  const alice = authedDb("alice");
  await assertSucceeds(alice.doc("rosterSources/alice_ics_feed").get());
  await assertFails(alice.doc("rosterSources/alice_ics_feed")
    .set({ status: "connected", user_id: "alice" }));
});

test("rosterSources: stranger cannot read another user's connection", async () => {
  await withAdmin(async (db) => {
    await db.doc("rosterSources/alice_ics_feed").set({
      user_id: "alice", provider_id: "ics_feed", status: "connected",
    });
  });
  await assertFails(authedDb("mallory").doc("rosterSources/alice_ics_feed").get());
});

test("syncEvents: clients can neither read nor write analytics", async () => {
  const alice = authedDb("alice");
  await assertFails(alice.collection("syncEvents")
    .add({ userId: "alice", type: "sync_ok" }));
  await withAdmin(async (db) => {
    await db.doc("syncEvents/e1").set({ userId: "alice", type: "sync_ok" });
  });
  await assertFails(alice.doc("syncEvents/e1").get());
});
