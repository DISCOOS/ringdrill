/**
 * Mail templates, in `nb` and `en` (ADR-0075).
 *
 * They live here rather than in a vendor console because hosted templates are
 * the lock-in trap — invisible until you try to leave, since the content is
 * unversioned and un-reviewed on somebody else's dashboard. Here they diff,
 * they get reviewed, and they are localised like every other user-facing
 * string in the project.
 *
 * Kept deliberately plain: one column, no layout tables beyond the container,
 * and a text part always present. Rendering before the adapter means we own the
 * HTML-email quirks a hosted template would have absorbed, and the cheapest way
 * to own them is to give clients almost nothing to disagree about.
 */

const BRAND = "#1D9E75";

function shell(bodyHtml) {
    return `<!doctype html><html><body style="margin:0;padding:24px;background:#f5f5f4;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:#2c2c2a;">
<div style="max-width:520px;margin:0 auto;background:#ffffff;border-radius:12px;padding:28px;">
${bodyHtml}
<hr style="border:0;border-top:1px solid #e9e7e0;margin:24px 0 16px;">
<p style="margin:0;font-size:12px;line-height:1.6;color:#888780;">RingDrill · <a href="https://ringdrill.app" style="color:#888780;">ringdrill.app</a></p>
</div></body></html>`;
}

function button(href, label) {
    return `<p style="margin:20px 0;"><a href="${href}" style="display:inline-block;background:${BRAND};color:#ffffff;text-decoration:none;padding:12px 22px;border-radius:8px;font-weight:500;">${label}</a></p>`;
}

function code(value) {
    return `<p style="margin:16px 0;font-size:26px;font-weight:600;letter-spacing:0.28em;color:#2c2c2a;">${value}</p>`;
}

const t = {
    signIn: {
        en: ({ code: c, url, minutes }) => ({
            subject: "Your RingDrill sign-in link",
            html: shell(
                `<h1 style="margin:0 0 12px;font-size:20px;font-weight:500;">Sign in to RingDrill</h1>` +
                `<p style="margin:0;font-size:15px;line-height:1.6;">Open the link below, or type this code where you started:</p>` +
                code(c) + button(url, "Sign in") +
                `<p style="margin:0;font-size:13px;line-height:1.6;color:#5f5e5a;">The link and the code both expire in ${minutes} minutes and can be used once. If you did not ask to sign in, you can ignore this — nothing happens until someone uses it.</p>`,
            ),
            text: `Sign in to RingDrill\n\nCode: ${c}\nLink: ${url}\n\nBoth expire in ${minutes} minutes and can be used once.\nIf you did not ask to sign in, ignore this email.`,
        }),
        nb: ({ code: c, url, minutes }) => ({
            subject: "Innloggingslenken din til RingDrill",
            html: shell(
                `<h1 style="margin:0 0 12px;font-size:20px;font-weight:500;">Logg inn i RingDrill</h1>` +
                `<p style="margin:0;font-size:15px;line-height:1.6;">Åpne lenken under, eller skriv inn koden der du startet:</p>` +
                code(c) + button(url, "Logg inn") +
                `<p style="margin:0;font-size:13px;line-height:1.6;color:#5f5e5a;">Lenken og koden utløper om ${minutes} minutter og kan brukes én gang. Har du ikke bedt om å logge inn, kan du se bort fra denne — ingenting skjer før noen bruker den.</p>`,
            ),
            text: `Logg inn i RingDrill\n\nKode: ${c}\nLenke: ${url}\n\nBegge utløper om ${minutes} minutter og kan brukes én gang.\nHar du ikke bedt om å logge inn, kan du se bort fra denne e-posten.`,
        }),
    },

    // DESIGN-015 §6.4: the only unsolicited mail RingDrill sends, so it says why
    // it arrived and how to stop it. The link is not a credential — accepting
    // still requires signing in — and the copy says so, because a forwarded
    // invitation should not look like a handover.
    invitation: {
        en: ({ inviterName, organisation, role, url, days }) => ({
            subject: `${inviterName} invited you to ${organisation}`,
            html: shell(
                `<h1 style="margin:0 0 12px;font-size:20px;font-weight:500;">${inviterName} invited you to ${organisation}</h1>` +
                `<p style="margin:0;font-size:15px;line-height:1.6;">You have been invited to join <b>${organisation}</b> on RingDrill as a <b>${role}</b>. You will be able to read and publish the organisation's exercise plans.</p>` +
                button(url, "Open the invitation") +
                `<p style="margin:0;font-size:13px;line-height:1.6;color:#5f5e5a;">Expires in ${days} days. Accepting requires signing in, so nothing happens until you do. If you were not expecting this, you can ignore it.</p>`,
            ),
            text: `${inviterName} invited you to ${organisation}\n\nYou can join as ${role}, and read and publish the organisation's exercise plans.\n\n${url}\n\nExpires in ${days} days. Accepting requires signing in, so nothing happens until you do.\nIf you were not expecting this, ignore this email.`,
        }),
        nb: ({ inviterName, organisation, role, url, days }) => ({
            subject: `${inviterName} har invitert deg til ${organisation}`,
            html: shell(
                `<h1 style="margin:0 0 12px;font-size:20px;font-weight:500;">${inviterName} har invitert deg til ${organisation}</h1>` +
                `<p style="margin:0;font-size:15px;line-height:1.6;">Du er invitert til å bli med i <b>${organisation}</b> i RingDrill som <b>${role}</b>. Du vil kunne lese og publisere øvelsesplanene til organisasjonen.</p>` +
                button(url, "Åpne invitasjonen") +
                `<p style="margin:0;font-size:13px;line-height:1.6;color:#5f5e5a;">Utløper om ${days} dager. Du må logge inn for å takke ja, så ingenting skjer før du gjør det. Har du ikke ventet denne, kan du se bort fra den.</p>`,
            ),
            text: `${inviterName} har invitert deg til ${organisation}\n\nDu kan bli med som ${role}, og lese og publisere øvelsesplanene til organisasjonen.\n\n${url}\n\nUtløper om ${days} dager. Du må logge inn for å takke ja.\nHar du ikke ventet denne, kan du se bort fra denne e-posten.`,
        }),
    },

    // DESIGN-015 §3.5 / §4.2: verifying a reachable address is what turns an
    // Apple-relay sign-in from a duplicate account into a link.
    verifyAddress: {
        en: ({ code: c, minutes }) => ({
            subject: "Confirm your RingDrill email address",
            html: shell(
                `<h1 style="margin:0 0 12px;font-size:20px;font-weight:500;">Confirm this address</h1>` +
                `<p style="margin:0;font-size:15px;line-height:1.6;">Enter this code in RingDrill to confirm you can receive mail here. It lets you sign in with this address, and get back in if you lose your other sign-in method.</p>` +
                code(c) +
                `<p style="margin:0;font-size:13px;line-height:1.6;color:#5f5e5a;">Expires in ${minutes} minutes.</p>`,
            ),
            text: `Confirm this address\n\nCode: ${c}\n\nExpires in ${minutes} minutes.`,
        }),
        nb: ({ code: c, minutes }) => ({
            subject: "Bekreft e-postadressen din i RingDrill",
            html: shell(
                `<h1 style="margin:0 0 12px;font-size:20px;font-weight:500;">Bekreft denne adressen</h1>` +
                `<p style="margin:0;font-size:15px;line-height:1.6;">Skriv inn koden i RingDrill for å bekrefte at du mottar e-post her. Da kan du logge inn med denne adressen, og komme inn igjen hvis du mister den andre innloggingsmåten din.</p>` +
                code(c) +
                `<p style="margin:0;font-size:13px;line-height:1.6;color:#5f5e5a;">Utløper om ${minutes} minutter.</p>`,
            ),
            text: `Bekreft denne adressen\n\nKode: ${c}\n\nUtløper om ${minutes} minutter.`,
        }),
    },
};

export const TEMPLATES = t;
export const LOCALES = Object.freeze(["en", "nb"]);

/** Render `name` in `locale`, falling back to `en` for an unknown locale. */
export function renderTemplate(name, params, locale = "en") {
    const tpl = t[name];
    if (!tpl) throw new Error(`unknown mail template "${name}"`);
    const lang = tpl[locale] ? locale : "en";
    const out = tpl[lang](params);
    if (!out.subject || !out.html || !out.text) {
        // A text part is not optional: a missing one is a deliverability
        // problem that only shows up as spam-folder reports.
        throw new Error(`template "${name}" (${lang}) must render subject, html and text`);
    }
    return out;
}
