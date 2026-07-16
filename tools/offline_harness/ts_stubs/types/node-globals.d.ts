// Minimal Node globals for offline typechecking (replaces @types/node for
// the tiny surface this codebase touches).
declare const process: {
  env: Record<string, string | undefined>;
};
declare function setTimeout(cb: (...args: unknown[]) => void, ms?: number): unknown;
declare function parseInt(s: string, radix?: number): number;
