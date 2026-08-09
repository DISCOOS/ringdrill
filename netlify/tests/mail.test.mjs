/**
 * Tests for the mail seam (ADR-0075).
 *
 * The two things that would make a provider change expensive are the two things
 * asserted hardest: templates render on our side (so no content lives in a
 * vendor console), and webhook events normalise to one vocabulary while keeping
 * the raw payload.
 */
import { test } from "node:test";
import assert from "node:assert/strict";

import {
    MAIL_EVENTS,
    MAIL_PROVIDERS,
    createMailer,
    createMockAdapter,
    namespaceMessageId,
    normalizeResendEvent,
    resolveProvider,
    sendTemplate,
} from "../functions/lib/mail/index.js";
import { LOCALES, TEMPLATES, renderTemplate } from "../functions/lib/mail/templates.js";

test("resolveProvider: unset means resend; unknown falls back loudly", () => {
    assert.equal(resolveProvider({}), MAIL_PROVIDERS.RESEND);
    const warnings = [];
    assert.equal(resolveProvider({ MAIL_PROVIDER: "sendgird" }, { warn: (m) => warnings.push(m) }), MAIL_PROVIDERS.RESEND);
    assert.equal(warnings.length, 1);
});

test("a missing API key fails when the adapter is created, not at the first send", () => {
    // A mail channel that looks healthy until the first invitation is worse
    // than one that refuses to start.
    assert.throws(() => createMailer({ env: { MAIL_PROVIDER: "resend" } }), /RESEND_API_KEY/);
});

test("message ids are namespaced, so a provider change cannot collide with history", () => {
    assert.equal(namespaceMessageId("resend", "abc"), "resend:abc");
});

// ---------- templates are ours ----------

test("every template renders subject, html and text in both locales", () => {
    const params = {
        code: "K7F2Q9", url: "https://ringdrill.app/x", minutes: 10, days: 14,
        inviterName: "Kari", organisation: "Red Cross Bergen", role: "member",
    };
    for (const name of Object.keys(TEMPLATES)) {
        for (const locale of LOCALES) {
            const out = renderTemplate(name, params, locale);
            assert.ok(out.subject, `${name}/${locale} subject`);
            assert.ok(out.html.includes("<html>"), `${name}/${locale} html`);
            // A missing text part is a deliverability problem that only shows
            // up as spam-folder reports, so it is asserted rather than assumed.
            assert.ok(out.text.length > 20, `${name}/${locale} text`);
        }
    }
});

test("an unknown locale falls back to en rather than throwing", () => {
    const out = renderTemplate("signIn", { code: "A", url: "u", minutes: 10 }, "de");
    assert.equal(out.subject, renderTemplate("signIn", { code: "A", url: "u", minutes: 10 }, "en").subject);
});

test("the invitation says accepting requires signing in, in both locales", () => {
    // The link is not a credential (DESIGN-015 §6.4). A forwarded invitation
    // must not read like a handover, and that is a copy property worth pinning.
    const params = { inviterName: "Kari", organisation: "Red Cross Bergen", role: "member", url: "https://x", days: 14 };
    assert.match(renderTemplate("invitation", params, "en").text, /requires signing in/i);
    assert.match(renderTemplate("invitation", params, "nb").text, /logge inn/i);
});

test("the sign-in template carries both the code and the link", () => {
    // DESIGN-015 §3.3: the code is what rescues a link that opens in the wrong
    // browser, so an email with only one of the two is a broken flow.
    const out = renderTemplate("signIn", { code: "K7F2Q9", url: "https://ringdrill.app/a", minutes: 10 }, "en");
    assert.match(out.text, /K7F2Q9/);
    assert.match(out.text, /https:\/\/ringdrill\.app\/a/);
});

// ---------- mock short-circuits the whole channel ----------

test("mock returns the rendered message rather than sending, for every template", async () => {
    const mailer = createMockAdapter();
    await sendTemplate(mailer, { to: "kari@example.com", template: "signIn", params: { code: "A1", url: "u", minutes: 10 } });
    await sendTemplate(mailer, {
        to: "ola@example.com", template: "invitation", locale: "nb",
        params: { inviterName: "Kari", organisation: "RK Bergen", role: "medlem", url: "u", days: 14 },
    });

    // ADR-0073: mock short-circuits the channel, not one endpoint — otherwise
    // invitations become the one flow nobody can test locally.
    assert.equal(mailer.outbox.length, 2);
    assert.equal(mailer.outbox[0].to, "kari@example.com");
    assert.match(mailer.outbox[1].subject, /RK Bergen/);
    assert.match(mailer.outbox[1].messageId, /^mock:/);
});

test("sendTemplate refuses an unknown template rather than sending an empty mail", async () => {
    await assert.rejects(() => sendTemplate(createMockAdapter(), { to: "a@b", template: "nope" }), /unknown mail template/);
});

// ---------- events normalise, raw is kept ----------

test("resend events normalise to the common vocabulary", () => {
    const cases = [
        ["email.delivered", MAIL_EVENTS.DELIVERED],
        ["email.bounced", MAIL_EVENTS.BOUNCED],
        ["email.complained", MAIL_EVENTS.COMPLAINED],
        ["email.delivery_delayed", MAIL_EVENTS.DEFERRED],
    ];
    for (const [type, expected] of cases) {
        const ev = normalizeResendEvent({ type, created_at: "2026-08-08T00:00:00Z", data: { email_id: "abc", to: ["ola@example.com"] } });
        assert.equal(ev.type, expected, type);
        assert.equal(ev.messageId, "resend:abc");
        assert.equal(ev.recipient, "ola@example.com");
    }
});

test("the raw payload is kept, because normalising loses provider detail", () => {
    // Resend distinguishes bounce sub-types this vocabulary flattens, and a
    // support question six months later is when that detail matters.
    const payload = { type: "email.bounced", data: { email_id: "abc", to: ["x@y"], bounce: { type: "Permanent", subType: "Suppressed" } } };
    const ev = normalizeResendEvent(payload);
    assert.deepEqual(ev.raw, payload);
    assert.equal(ev.raw.data.bounce.subType, "Suppressed");
});

test("an unrecognised event type is null rather than a guessed category", () => {
    assert.equal(normalizeResendEvent({ type: "email.opened" }), null);
    assert.equal(normalizeResendEvent({}), null);
});

// ---------- ses is honest about being unwritten ----------

test("ses throws with a pointer rather than silently doing nothing", async () => {
    const mailer = createMailer({ env: { MAIL_PROVIDER: "ses", AWS_REGION: "eu-north-1" } });
    await assert.rejects(() => mailer.send({ to: "a@b", subject: "s", html: "h", text: "t" }), /not implemented/);
});
