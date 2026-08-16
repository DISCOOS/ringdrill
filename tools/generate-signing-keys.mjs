#!/usr/bin/env node
import { mkdirSync, writeFileSync, existsSync, chmodSync } from "node:fs";
import { resolve } from "node:path";

import { generateKeypair } from "../netlify/functions/lib/auth/jwt.js";

/**
 * Generate the Ed25519 pair that signs access tokens (ADR-0025).
 *
 * Uses the app's own `generateKeypair` rather than an `openssl` line, so the
 * format is whatever `signJwt` and `verifyJwt` actually accept — PKCS#8 and
 * SPKI PEM — and cannot drift from them.
 *
 * **Writes to disk rather than stdout.** A private key echoed into a terminal
 * lands in scrollback and shell history, and the usual next step is to select
 * it with a mouse, which is where a truncated copy comes from. Files can be
 * moved into a password manager or a shared vault and then deleted.
 *
 * The directory is gitignored, and this refuses to overwrite: silently
 * replacing a key would invalidate every session signed with the old one, and
 * the person running it would have no way to get the previous value back.
 */

const OUT_DIR = resolve(import.meta.dirname, "..", ".secrets");

function main() {
    // A date in the name, so a rotation leaves the outgoing pair sitting next
    // to the incoming one — that is exactly the window where
    // AUTH_SIGNING_KEY_PUBLIC_PREVIOUS needs the old public half.
    const stamp = new Date().toISOString().slice(0, 10);
    const priv = resolve(OUT_DIR, `auth-signing-${stamp}.private.pem`);
    const pub = resolve(OUT_DIR, `auth-signing-${stamp}.public.pem`);

    for (const path of [priv, pub]) {
        if (existsSync(path)) {
            console.error(
                `Refusing to overwrite ${path}\n\n`
                + "A key generated today is already here. Move or delete it first — "
                + "replacing it would invalidate every session signed with it, and the "
                + "old value would be unrecoverable.",
            );
            process.exit(1);
        }
    }

    mkdirSync(OUT_DIR, { recursive: true });
    const { privateKey, publicKey } = generateKeypair();
    writeFileSync(priv, privateKey, { mode: 0o600 });
    writeFileSync(pub, publicKey, { mode: 0o644 });
    chmodSync(priv, 0o600);

    console.log(`
Ed25519 signing pair written to:

  private  ${priv}
  public   ${pub}

.secrets/ is gitignored. Neither file belongs in the repository.

Next:

  1. Copy the WHOLE of each file, BEGIN and END lines included, into Netlify
     environment variables on the API site:

       AUTH_SIGNING_KEY_PRIVATE   <- ${priv.split("/").pop()}
       AUTH_SIGNING_KEY_PUBLIC    <- ${pub.split("/").pop()}

     Both must come from this same run. A private key paired with a mismatched
     public one signs fine and then fails every verification, so sign-in appears
     to work and every authenticated request 401s.

  2. Redeploy. A Netlify environment change does not apply to the running
     functions until the next deploy.

  3. Store both files somewhere durable and access-controlled — a password
     manager or the project's shared vault — then delete them from here.

Rotating later: new pair into PRIVATE/PUBLIC, the OLD public into
AUTH_SIGNING_KEY_PUBLIC_PREVIOUS so tokens already issued keep working until
they expire, then drop PREVIOUS once they have.
`);
}

main();
