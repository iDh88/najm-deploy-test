// Unit tests for src/mapping.ts (F36) — the exact Functions⇄Python contract
// translations that were broken pre-remediation (F16/F17) plus the shared
// runtime-config precedence (F19/F20).
//
// Runs on the COMPILED output so the test exercises exactly what deploys:
//   npm run build && npm test          (wired in package.json)
//
// Uses the Node built-in test runner — zero test-framework dependencies.

const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  buildLegalityPayload,
  buildAiChatPayload,
  resolveSubscriptionsEnabled,
  resolveAiDailyLimit,
} = require("../lib/mapping.js");

// ─── F16: buildLegalityPayload ───────────────────────────────────────────────

test("legality: documented keys pass through", () => {
  const duty = { id: "d1", duty_start: "2026-06-01T04:00:00Z", sector_count: 2 };
  const r = buildLegalityPayload({ crew_schedule: [duty], proposed_duty: duty });
  assert.equal(r.ok, true);
  assert.deepEqual(r.value, { crew_schedule: [duty], proposed_duty: duty });
});

test("legality: legacy client keys (schedule/proposedChange) are translated", () => {
  const duty = { id: "d1" };
  const r = buildLegalityPayload({
    schedule: [duty], proposedChange: duty, changeType: "swap",
  });
  assert.equal(r.ok, true);
  assert.deepEqual(r.value, { crew_schedule: [duty], proposed_duty: duty });
  // changeType has no server-side field and must not leak into the payload
  assert.equal("changeType" in r.value, false);
});

test("legality: documented keys win over legacy keys when both present", () => {
  const r = buildLegalityPayload({
    crew_schedule: [{ id: "new" }], schedule: [{ id: "old" }],
  });
  assert.equal(r.ok, true);
  assert.deepEqual(r.value.crew_schedule, [{ id: "new" }]);
});

test("legality: schedule-only check omits proposed_duty entirely", () => {
  const r = buildLegalityPayload({ crew_schedule: [] });
  assert.equal(r.ok, true);
  assert.equal("proposed_duty" in r.value, false);
});

test("legality: missing/non-array schedule is a mapping error, not a crash", () => {
  for (const bad of [undefined, null, {}, { schedule: "not-an-array" },
                     { crew_schedule: 42 }]) {
    const r = buildLegalityPayload(bad);
    assert.equal(r.ok, false);
    assert.match(r.error, /crew_schedule/);
  }
});

// ─── F17: buildAiChatPayload ─────────────────────────────────────────────────

test("ai chat: snake_case user_id, defaults for history/context", () => {
  const p = buildAiChatPayload("uid-1", { message: "hi" }, null);
  assert.equal(p.user_id, "uid-1");
  assert.equal(p.message, "hi");
  assert.deepEqual(p.history, []);
  assert.equal(p.context.userMode, "balanced");
  assert.equal(p.context.locale, "ar");
});

test("ai chat: request context userMode beats profile; profile beats default", () => {
  const fromRequest = buildAiChatPayload(
    "u", { message: "m", context: { userMode: "money" } }, { userMode: "rest" });
  assert.equal(fromRequest.context.userMode, "money");

  const fromProfile = buildAiChatPayload(
    "u", { message: "m" }, { userMode: "rest" });
  assert.equal(fromProfile.context.userMode, "rest");
});

test("ai chat: locale mirrors profile; extra context keys survive", () => {
  const p = buildAiChatPayload(
    "u",
    { message: "m", history: [{ role: "user", content: "x" }],
      context: { activeMonth: "JUN-2026" } },
    { locale: "en" });
  assert.equal(p.context.locale, "en");
  assert.equal(p.context.activeMonth, "JUN-2026");
  assert.equal(p.history.length, 1);
});

test("ai chat: non-array history is coerced to []", () => {
  const p = buildAiChatPayload("u", { message: "m", history: "bad" }, null);
  assert.deepEqual(p.history, []);
});

// ─── F19: resolveSubscriptionsEnabled ────────────────────────────────────────

test("subscriptions switch: Firestore boolean wins over env", () => {
  assert.equal(resolveSubscriptionsEnabled(true, "false"), true);
  assert.equal(resolveSubscriptionsEnabled(false, "true"), false);
});

test("subscriptions switch: env fallback only when cfg is not boolean", () => {
  assert.equal(resolveSubscriptionsEnabled(undefined, "true"), true);
  assert.equal(resolveSubscriptionsEnabled("yes", "false"), false);
  assert.equal(resolveSubscriptionsEnabled(null, undefined), false);
});

// ─── F20: resolveAiDailyLimit ────────────────────────────────────────────────

test("ai limit: finite positive cfg number wins, floored", () => {
  assert.equal(resolveAiDailyLimit(75, "10"), 75);
  assert.equal(resolveAiDailyLimit(12.9, "10"), 12);
});

test("ai limit: invalid cfg falls to env; invalid env falls to 50", () => {
  assert.equal(resolveAiDailyLimit(0, "30"), 30);
  assert.equal(resolveAiDailyLimit(-5, "30"), 30);
  assert.equal(resolveAiDailyLimit(NaN, "30"), 30);
  assert.equal(resolveAiDailyLimit("100", "30"), 30);
  assert.equal(resolveAiDailyLimit(undefined, undefined), 50);
  assert.equal(resolveAiDailyLimit(undefined, "garbage"), 50);
});
