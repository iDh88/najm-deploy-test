/**
 * mapping.ts — pure request/response contract helpers for the Cloud
 * Functions ⇄ Python-service bridge.
 *
 * F36: extracted from index.ts trigger bodies so the exact translations that
 * broke in the audit (F16: checkLegality 422'd on every call; F17: aiAssistant
 * 422'd on every call) are pinned by unit tests. This module deliberately
 * imports NOTHING — it must stay executable by plain `node --test` with zero
 * emulators, credentials, or SDKs.
 */

/** Discriminated result so callers translate failures into their own error
 *  type (HttpsError in the trigger, assert in tests). */
export type MapResult<T> =
  | { ok: true; value: T }
  | { ok: false; error: string };

// ─── F16: checkLegality → POST /v1/legality/check ────────────────────────────

export interface LegalityPayload {
  crew_schedule: unknown[];
  proposed_duty?: unknown;
}

/**
 * Accepts both the documented keys (`crew_schedule`, `proposed_duty`) and the
 * legacy client keys (`schedule`, `proposedChange`); forwards only what the
 * pydantic schema (legality/engine.py::LegalityCheckRequest) defines.
 * `changeType` is intentionally dropped — the server has no such field.
 */
export function buildLegalityPayload(
  data: Record<string, unknown> | null | undefined,
): MapResult<LegalityPayload> {
  const d = data ?? {};
  const crewSchedule = (d.crew_schedule ?? d.schedule) as unknown;
  const proposedDuty = d.proposed_duty ?? d.proposedChange ?? null;

  if (!Array.isArray(crewSchedule)) {
    return { ok: false, error: "crew_schedule (array of DutyPeriod) is required" };
  }
  const payload: LegalityPayload = { crew_schedule: crewSchedule };
  if (proposedDuty) payload.proposed_duty = proposedDuty;
  return { ok: true, value: payload };
}

// ─── F17: aiAssistant → POST /v1/ai/chat ─────────────────────────────────────

export interface AiChatPayload {
  user_id: string;
  message: unknown;
  history: unknown[];
  context: Record<string, unknown>;
}

/**
 * ChatRequest (ai/nlp_router.py) requires snake_case `user_id` and reads
 * `userMode` from the `context` dict. Precedence for userMode:
 * explicit request context → user profile document → "balanced".
 * Locale always mirrors the profile (Arabic default per product spec).
 */
export function buildAiChatPayload(
  userId: string,
  data: Record<string, unknown> | null | undefined,
  userDocData: Record<string, unknown> | null | undefined,
): AiChatPayload {
  const d = data ?? {};
  const profile = userDocData ?? {};
  const requestContext = (d.context ?? {}) as Record<string, unknown>;
  return {
    user_id: userId,
    message: d.message,
    history: Array.isArray(d.history) ? d.history : [],
    context: {
      ...requestContext,
      userMode: requestContext.userMode ?? profile.userMode ?? "balanced",
      locale: (profile.locale as string) || "ar",
    },
  };
}

// ─── F19/F20: shared runtime-config precedence ───────────────────────────────

/** Firestore value wins when it is a usable boolean; env string otherwise. */
export function resolveSubscriptionsEnabled(
  cfgValue: unknown,
  envValue: string | undefined,
): boolean {
  if (typeof cfgValue === "boolean") return cfgValue;
  return envValue === "true";
}

/** Firestore value wins when it is a finite positive number; env/default 50
 *  otherwise. Fractional admin input is floored, never rounded up. */
export function resolveAiDailyLimit(
  cfgValue: unknown,
  envValue: string | undefined,
): number {
  if (typeof cfgValue === "number" && Number.isFinite(cfgValue) && cfgValue > 0) {
    return Math.floor(cfgValue);
  }
  const parsed = parseInt(envValue || "50", 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 50;
}
