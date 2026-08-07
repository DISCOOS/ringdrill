import { ANONYMOUS } from "./principal.js";

/**
 * The pre-accounts adapter (ADR-0073): every request is anonymous and the
 * ADR-0025 matrix is not applied, so the catalog behaves exactly as it did
 * before accounts existed.
 *
 * Two uses, and they are not the same:
 *
 * * **Emergency rollback.** Reverting a mobile release takes days; setting
 *   `AUTH_MODE=off` takes seconds, and with no phases to fall back through it
 *   is the whole recovery path (the account rollout ships as one release).
 * * **Pre-account regression tests.** The suite that asserts today's wiki
 *   behaviour runs under `off` and keeps passing for as long as that behaviour
 *   is supported.
 *
 * **The trap, recorded in ADR-0073 because it bites silently:** under `off`,
 * refusal assertions fail loudly — good — but *permission* assertions pass
 * vacuously. A test asserting "a member may publish" passes here for the wrong
 * reason. Any suite asserting that somebody MAY do something has to pin the
 * mode rather than inherit it from the environment.
 *
 * A token that is present is ignored rather than rejected: `off` means
 * authorisation is not being evaluated, and 401-ing a client that is behaving
 * correctly would make the rollback switch itself an outage.
 */
export function createOffAdapter() {
    return {
        mode: "off",
        async authenticate() {
            return ANONYMOUS;
        },
    };
}
