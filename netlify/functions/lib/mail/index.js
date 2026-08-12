import { renderTemplate, TEMPLATES } from "./templates.js";

/**
 * The mail seam (ADR-0075). `MAIL_PROVIDER` selects an adapter:
 *
 *   resend   (default when unset)  the production vendor
 *   ses                            the fallback if EU residency ever binds
 *   mock                           returns the message instead of sending it
 *   console                        prints it; for local work
 *
 * Two things are deliberately on our side of the seam, because they are what
 * would make a provider change expensive:
 *
 * **Templates render before the adapter is called.** Both Resend and SES offer
 * hosted templates, and using them is the one decision that makes a swap
 * costly — invisible until you try to leave, because the content is sitting
 * unversioned in a vendor console. Rendering here also makes the copy
 * diffable, reviewable and localisable like every other string in the project.
 *
 * **Events normalise to one vocabulary** (see `normalizeEvent` in the per
 * provider webhook handlers). Resend posts a signed webhook; SES publishes to
 * an SNS topic. Same meaning, different shape and authentication.
 *
 * A missing API key fails when the adapter is created, not at first send. A
 * mail channel that looks healthy until the first invitation is worse than one
 * that refuses to start.
 */

export const MAIL_PROVIDERS = Object.freeze({
    RESEND: "resend", SES: "ses", MOCK: "mock", CONSOLE: "console",
});

export const DEFAULT_FROM = "RingDrill <noreply@ringdrill.app>";

export function resolveProvider(env = process.env, { warn = console.error } = {}) {
    const raw = String(env.MAIL_PROVIDER ?? "").trim().toLowerCase();
    if (!raw) return MAIL_PROVIDERS.RESEND;
    if (Object.values(MAIL_PROVIDERS).includes(raw)) return raw;
    warn(`[mail] Unknown MAIL_PROVIDER ${JSON.stringify(raw)} — falling back to "resend".`);
    return MAIL_PROVIDERS.RESEND;
}

/**
 * Namespaced message ids (`resend:abc123`), so a provider change cannot collide
 * with historical records and an old event says which vendor produced it
 * without a lookup table.
 */
export function namespaceMessageId(provider, id) {
    return `${provider}:${id}`;
}

function requireKey(env, name, provider) {
    const value = env[name];
    if (!value) {
        throw new Error(
            `MAIL_PROVIDER=${provider} requires ${name}. Refusing to start rather than ` +
            `failing at the first send — a mail channel that looks healthy until the ` +
            `first invitation is worse than one that will not boot.`,
        );
    }
    return value;
}

function createResendAdapter({ env, fetchImpl }) {
    const apiKey = requireKey(env, "RESEND_API_KEY", "resend");
    return {
        provider: MAIL_PROVIDERS.RESEND,
        async send({ to, subject, html, text, from, idempotencyKey }) {
            const headers = {
                authorization: `Bearer ${apiKey}`,
                "content-type": "application/json",
            };
            // Resend keys idempotency off a header, so a retried invite does not
            // send twice.
            if (idempotencyKey) headers["idempotency-key"] = idempotencyKey;

            const res = await fetchImpl("https://api.resend.com/emails", {
                method: "POST",
                headers,
                body: JSON.stringify({ from: from || DEFAULT_FROM, to: [to], subject, html, text }),
            });
            if (!res.ok) {
                const body = await res.text().catch(() => "");
                throw new Error(`resend send failed: ${res.status} ${body.slice(0, 200)}`);
            }
            const json = await res.json().catch(() => ({}));
            return { messageId: namespaceMessageId(MAIL_PROVIDERS.RESEND, json.id ?? "unknown") };
        },
    };
}

function createSesAdapter({ env }) {
    requireKey(env, "AWS_REGION", "ses");
    return {
        provider: MAIL_PROVIDERS.SES,
        async send() {
            // Deliberately unimplemented rather than silently absent: ADR-0075
            // names SES as the residency fallback, and a stub that throws is
            // honest about the work being unwritten. Whoever needs it will
            // implement it here, behind the same interface, with no caller
            // change.
            throw new Error("MAIL_PROVIDER=ses is not implemented yet (ADR-0075 names it as the EU-residency fallback)");
        },
    };
}

/**
 * `mock` returns the rendered message instead of sending, and — per ADR-0073 —
 * short-circuits the *whole* channel rather than one endpoint. Mail is a
 * dependency of several flows, so mocking only `start-email` would leave
 * invitations as the one thing nobody can test locally.
 */
export function createMockAdapter() {
    const outbox = [];
    return {
        provider: MAIL_PROVIDERS.MOCK,
        outbox,
        async send(message) {
            const messageId = namespaceMessageId(MAIL_PROVIDERS.MOCK, String(outbox.length + 1));
            outbox.push({ ...message, messageId });
            return { messageId, mock: true, message };
        },
    };
}

function createConsoleAdapter({ log = console.log } = {}) {
    let n = 0;
    return {
        provider: MAIL_PROVIDERS.CONSOLE,
        async send({ to, subject, text }) {
            log(`\n--- mail → ${to} ---\n${subject}\n\n${text}\n---\n`);
            return { messageId: namespaceMessageId(MAIL_PROVIDERS.CONSOLE, String(++n)) };
        },
    };
}

export function createMailer({ env = process.env, fetchImpl = globalThis.fetch, warn, log } = {}) {
    const provider = resolveProvider(env, warn ? { warn } : undefined);
    switch (provider) {
        case MAIL_PROVIDERS.MOCK: return createMockAdapter();
        case MAIL_PROVIDERS.CONSOLE: return createConsoleAdapter({ log });
        case MAIL_PROVIDERS.SES: return createSesAdapter({ env });
        default: return createResendAdapter({ env, fetchImpl });
    }
}

/**
 * Send a template.
 *
 * `locale` follows DESIGN-015 §3.6's two rules, and the caller picks which:
 * a message caused by a request uses the *requesting client's* locale, while an
 * invitation uses the *inviting user's* — the only signal available for
 * somebody who has no account yet.
 */
export async function sendTemplate(mailer, { to, template, params = {}, locale = "en", from, idempotencyKey }) {
    if (!TEMPLATES[template]) throw new Error(`unknown mail template "${template}"`);
    const { subject, html, text } = renderTemplate(template, params, locale);
    return mailer.send({ to, subject, html, text, from, idempotencyKey });
}

/** The common event vocabulary every provider webhook normalises into. */
export const MAIL_EVENTS = Object.freeze({
    DELIVERED: "delivered", BOUNCED: "bounced", COMPLAINED: "complained", DEFERRED: "deferred",
});

/**
 * Normalise a Resend webhook payload.
 *
 * `raw` is kept alongside the normalised shape on purpose: flattening loses
 * provider detail — Resend distinguishes bounce sub-types this vocabulary does
 * not — and a support question six months later is when that detail matters.
 * Downstream (DESIGN-015 §6.2's member row) reads `type` only.
 */
export function normalizeResendEvent(payload) {
    const type = String(payload?.type ?? "");
    const map = {
        "email.delivered": MAIL_EVENTS.DELIVERED,
        "email.bounced": MAIL_EVENTS.BOUNCED,
        "email.complained": MAIL_EVENTS.COMPLAINED,
        "email.delivery_delayed": MAIL_EVENTS.DEFERRED,
    };
    const normalized = map[type];
    if (!normalized) return null;
    const data = payload.data ?? {};
    return {
        type: normalized,
        messageId: namespaceMessageId(MAIL_PROVIDERS.RESEND, data.email_id ?? data.id ?? "unknown"),
        recipient: Array.isArray(data.to) ? data.to[0] : (data.to ?? null),
        at: payload.created_at ?? new Date().toISOString(),
        raw: payload,
    };
}
