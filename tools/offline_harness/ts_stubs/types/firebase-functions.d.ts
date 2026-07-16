// Offline structural stub for firebase-functions v5 (v1 API surface used by
// this repo). Purpose: allow `tsc --noEmit` to typecheck src/ without
// node_modules. NOT a runtime module. See tools/offline_harness/README.md.
declare module "firebase-functions" {
  export namespace logger {
    function info(...args: unknown[]): void;
    function warn(...args: unknown[]): void;
    function error(...args: unknown[]): void;
  }

  export namespace https {
    class HttpsError extends Error {
      constructor(code: string, message?: string, details?: unknown);
      readonly code: string;
    }
    interface CallableContext {
      auth?: { uid: string; token: Record<string, any> } | null;
    }
  }

  export interface EventContext {
    params: Record<string, string>;
    eventId: string;
    timestamp: string;
  }

  export interface Change<T> { before: T; after: T; }

  export interface DocumentSnapshot {
    id: string;
    exists: boolean;
    ref: any;
    data(): Record<string, any> | undefined;
    get(field: string): any;
  }
  export interface QueryDocumentSnapshot
      extends Omit<DocumentSnapshot, "data"> {
    data(): Record<string, any>;
  }

  interface DocumentBuilder {
    onCreate(handler: (snap: QueryDocumentSnapshot, ctx: EventContext) => unknown): CloudFunction;
    onUpdate(handler: (change: Change<QueryDocumentSnapshot>, ctx: EventContext) => unknown): CloudFunction;
    onDelete(handler: (snap: QueryDocumentSnapshot, ctx: EventContext) => unknown): CloudFunction;
    onWrite(handler: (change: Change<DocumentSnapshot>, ctx: EventContext) => unknown): CloudFunction;
  }
  interface FirestoreNamespace { document(path: string): DocumentBuilder; }

  interface ScheduleBuilder {
    timeZone(tz: string): ScheduleBuilder;
    onRun(handler: (ctx: EventContext) => unknown): CloudFunction;
  }
  interface PubsubNamespace { schedule(expr: string): ScheduleBuilder; }

  interface UserRecordLite {
    uid: string;
    email?: string;
    displayName?: string;
    customClaims?: Record<string, any>;
  }
  interface UserBuilder {
    onCreate(handler: (user: UserRecordLite, ctx: EventContext) => unknown): CloudFunction;
    onDelete(handler: (user: UserRecordLite, ctx: EventContext) => unknown): CloudFunction;
  }
  interface AuthNamespace { user(): UserBuilder; }

  export interface ObjectMetadata {
    name?: string;
    bucket: string;
    contentType?: string;
    size: string;
    timeCreated: string;
    metadata?: Record<string, string>;
  }
  interface ObjectBuilder {
    onFinalize(handler: (object: ObjectMetadata, ctx: EventContext) => unknown): CloudFunction;
    onDelete(handler: (object: ObjectMetadata, ctx: EventContext) => unknown): CloudFunction;
  }
  interface StorageNamespace { object(): ObjectBuilder; }

  interface HttpsNamespaceBuilder {
    onCall(handler: (data: any, context: https.CallableContext) => unknown): CloudFunction;
    onRequest(handler: (req: any, res: any) => unknown): CloudFunction;
  }

  export interface RuntimeOptions {
    timeoutSeconds?: number;
    memory?: "128MB" | "256MB" | "512MB" | "1GB" | "2GB" | "4GB" | "8GB";
    minInstances?: number;
    maxInstances?: number;
  }

  interface FunctionBuilder {
    region(...regions: string[]): FunctionBuilder;
    runWith(options: RuntimeOptions): FunctionBuilder;
    firestore: FirestoreNamespace;
    pubsub: PubsubNamespace;
    auth: AuthNamespace;
    storage: StorageNamespace;
    https: HttpsNamespaceBuilder;
  }

  export type CloudFunction = object;

  export function region(...regions: string[]): FunctionBuilder;
  export function runWith(options: RuntimeOptions): FunctionBuilder;
  export const firestore: FirestoreNamespace;
  export const pubsub: PubsubNamespace;
  export const auth: AuthNamespace;
  export const storage: StorageNamespace;
  export namespace https {
    function onCall(handler: (data: any, context: https.CallableContext) => unknown): CloudFunction;
  }
}

// v5 package layout: the 1st-gen API lives at the /v1 entrypoint.
declare module "firebase-functions/v1" {
  export * from "firebase-functions";
  export { https } from "firebase-functions";
}
