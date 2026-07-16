// Offline structural stub for firebase-admin v12 (surface used by this repo).
declare namespace FirebaseFirestore {
  type DocumentData = Record<string, any>;
  interface DocumentSnapshot {
    id: string; exists: boolean; ref: DocumentReference;
    data(): DocumentData | undefined; get(field: string): any;
  }
  interface QueryDocumentSnapshot extends DocumentSnapshot { data(): DocumentData; }
  interface QuerySnapshot {
    empty: boolean; size: number; docs: QueryDocumentSnapshot[];
    forEach(cb: (d: QueryDocumentSnapshot) => void): void;
  }
  interface Query {
    where(field: any, op: string, value: any): Query;
    orderBy(field: any, dir?: "asc" | "desc"): Query;
    limit(n: number): Query;
    select(...fields: any[]): Query;
    startAt(...v: any[]): Query;
    endAt(...v: any[]): Query;
    endBefore(...v: any[]): Query;
    startAfter(...v: any[]): Query;
    get(): Promise<QuerySnapshot>;
  }
  interface CollectionReference extends Query {
    doc(id?: string): DocumentReference;
    add(data: DocumentData): Promise<DocumentReference>;
  }
  interface DocumentReference {
    id: string; path: string;
    get(): Promise<DocumentSnapshot>;
    set(data: DocumentData, opts?: { merge?: boolean }): Promise<unknown>;
    update(data: DocumentData): Promise<unknown>;
    delete(): Promise<unknown>;
    collection(name: string): CollectionReference;
  }
  interface WriteBatch {
    set(ref: DocumentReference, data: DocumentData, opts?: { merge?: boolean }): WriteBatch;
    update(ref: DocumentReference, data: DocumentData): WriteBatch;
    delete(ref: DocumentReference): WriteBatch;
    commit(): Promise<unknown>;
  }
  interface Firestore {
    collection(name: string): CollectionReference;
    doc(path: string): DocumentReference;
    batch(): WriteBatch;
    runTransaction<T>(fn: (tx: any) => Promise<T>): Promise<T>;
  }
}

declare module "firebase-admin" {
  export function initializeApp(options?: object): unknown;

  export namespace firestore {
    const FieldValue: {
      serverTimestamp(): unknown;
      increment(n: number): unknown;
      arrayUnion(...v: unknown[]): unknown;
      arrayRemove(...v: unknown[]): unknown;
      delete(): unknown;
    };
    const FieldPath: { documentId(): unknown };
    class Timestamp {
      static now(): Timestamp;
      static fromDate(d: Date): Timestamp;
      toDate(): Date;
      seconds: number;
    }
  }
  export function firestore(): FirebaseFirestore.Firestore;

  export interface UserRecord {
    uid: string; email?: string; displayName?: string; disabled?: boolean;
    customClaims?: Record<string, any>;
  }
  export interface Auth {
    getUser(uid: string): Promise<UserRecord>;
    getUserByEmail(email: string): Promise<UserRecord>;
    setCustomUserClaims(uid: string, claims: Record<string, any> | null): Promise<void>;
    revokeRefreshTokens(uid: string): Promise<void>;
    updateUser(uid: string, props: Record<string, any>): Promise<UserRecord>;
    deleteUser(uid: string): Promise<void>;
  }
  export function auth(): Auth;

  export interface Messaging {
    sendEachForMulticast(msg: {
      tokens: string[];
      notification?: { title?: string; body?: string };
      data?: Record<string, string>;
    }): Promise<{ successCount: number; failureCount: number }>;
    send(msg: object): Promise<string>;
  }
  export function messaging(): Messaging;

  export interface Storage { bucket(name?: string): any; }
  export function storage(): Storage;
}
