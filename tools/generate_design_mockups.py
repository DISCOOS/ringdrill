#!/usr/bin/env python3
"""Generate the DESIGN-015 account mockups under `docs/design/mockups/`.

Standalone HTML, one file per group of screens, openable in a browser with no
build step — the convention `docs/design/README.md` sets for mockups. Copy is
English throughout (`AGENTS.md` rule 12); DESIGN-015 quotes the `nb` wording in
the few places where the Norwegian word choice is itself the decision.

Why this is a generator and not six hand-written files: the six pages share a
CSS harness and a role vocabulary that has already changed twice
(`editor`/`viewer` -> `member`/`guest`, then "guests publish too"). Each change
touched the same strings in four files, and editing them by hand is how they
drift apart. Change `ROLES`, or a copy string, in one place here and regenerate.

Run:
    python3 tools/generate_design_mockups.py

Outputs (committed, overwritten in place):
    docs/design/mockups/auth-signin.html
    docs/design/mockups/auth-recovery.html
    docs/design/mockups/account-personal.html
    docs/design/mockups/account-organisation.html
    docs/design/mockups/account-wide.html
    docs/design/mockups/library-tabs.html

The mockups predating DESIGN-015 are hand-written and still `nb`. They belong
to their own design docs and are not touched here. `HEAD`, `page()` and the
element classes are the reusable part if another design doc wants them.
"""

import os
import pathlib

REPO = pathlib.Path(os.path.dirname(os.path.abspath(__file__))).parent
OUT = REPO / "docs" / "design" / "mockups"


HEAD = '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>RingDrill — {title}</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@tabler/icons-webfont@3.0.0/tabler-icons.min.css">
<style>
  :root {{
    color-scheme: light dark;
    --color-background-page: #f5f5f4;
    --color-background-primary: #ffffff;
    --color-background-secondary: #f1efe8;
    --color-background-tertiary: #e9e7e0;
    --color-text-primary: #2c2c2a;
    --color-text-secondary: #5f5e5a;
    --color-text-tertiary: #888780;
    --color-border-secondary: rgba(0, 0, 0, 0.3);
    --color-border-tertiary: rgba(0, 0, 0, 0.12);
    --accent: #1D9E75;
    --accent-fill: #E1F5EE;
    --accent-text: #0F6E56;
    --warn-fill: #FDF1DC;
    --warn-text: #8A5A12;
    --danger-text: #B3261E;
    --border-radius-md: 8px;
    --border-radius-lg: 12px;
    --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  }}
  @media (prefers-color-scheme: dark) {{
    :root {{
      --color-background-page: #1a1a1a;
      --color-background-primary: #242322;
      --color-background-secondary: #2e2d2b;
      --color-background-tertiary: #3a3a37;
      --color-text-primary: #f1efe8;
      --color-text-secondary: #b4b2a9;
      --color-text-tertiary: #888780;
      --color-border-secondary: rgba(255, 255, 255, 0.3);
      --color-border-tertiary: rgba(255, 255, 255, 0.12);
      --accent-fill: #16362E;
      --accent-text: #6FD3B0;
      --warn-fill: #3A2E17;
      --warn-text: #E8C07A;
      --danger-text: #F2B8B5;
    }}
  }}
  html, body {{ margin: 0; padding: 0; }}
  body {{
    font-family: var(--font-sans);
    background: var(--color-background-page);
    color: var(--color-text-primary);
    padding: 24px 16px;
    box-sizing: border-box;
  }}
  .caption {{
    max-width: 1120px;
    margin: 0 auto 20px;
    font-size: 13px;
    line-height: 1.6;
    color: var(--color-text-secondary);
    text-align: center;
  }}
  .row {{
    display: flex;
    flex-wrap: wrap;
    gap: 20px;
    justify-content: center;
    align-items: flex-start;
    max-width: 1400px;
    margin: 0 auto;
  }}
  .panel {{ width: 320px; }}
  .panel-wide {{ width: 100%; max-width: 1060px; }}
  .panel > h4 {{
    font-size: 12px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    color: var(--color-text-tertiary);
    margin: 0 0 8px 2px;
  }}
  .frame {{
    background: var(--color-background-secondary);
    border-radius: var(--border-radius-lg);
    padding: 10px;
  }}
  .screen {{
    background: var(--color-background-primary);
    border: 0.5px solid var(--color-border-tertiary);
    border-radius: var(--border-radius-lg);
    overflow: hidden;
    display: flex;
    flex-direction: column;
    min-height: 560px;
    position: relative;
  }}
  .bar {{
    display: flex; align-items: center; gap: 10px;
    padding: 12px 14px;
    border-bottom: 0.5px solid var(--color-border-tertiary);
    font-size: 15px; font-weight: 500;
    color: var(--color-text-primary);
  }}
  .bar i {{ font-size: 18px; color: var(--color-text-secondary); }}
  .body {{ padding: 16px 14px; display: flex; flex-direction: column; gap: 12px; flex: 1; }}
  .h {{ font-size: 18px; font-weight: 500; margin: 0; }}
  .p {{ font-size: 13px; line-height: 1.6; color: var(--color-text-secondary); margin: 0; }}
  .btn {{
    display: flex; align-items: center; justify-content: center; gap: 8px;
    height: 44px; border-radius: var(--border-radius-md);
    font-size: 14px; font-weight: 500;
    border: 0.5px solid var(--color-border-secondary);
    flex: none;
  }}
  .btn i {{ font-size: 18px; }}
  .btn-primary {{ background: var(--accent); color: #fff; border-color: transparent; }}
  .btn-dark {{ background: #000; color: #fff; border-color: transparent; }}
  .btn-danger {{ color: var(--danger-text); }}
  .sect {{
    font-size: 11px; font-weight: 500; text-transform: uppercase; letter-spacing: 0.06em;
    color: var(--color-text-tertiary); margin: 6px 0 -4px 2px;
  }}
  .card {{
    border: 0.5px solid var(--color-border-tertiary);
    border-radius: var(--border-radius-md);
    overflow: hidden;
    flex: none;
  }}
  .item {{
    display: flex; align-items: center; gap: 12px;
    padding: 11px 12px;
    border-bottom: 0.5px solid var(--color-border-tertiary);
  }}
  .item:last-child {{ border-bottom: 0; }}
  .item i {{ font-size: 18px; color: var(--color-text-secondary); flex: none; }}
  .t {{ font-size: 14px; }}
  .s {{ font-size: 12px; color: var(--color-text-secondary); margin-top: 2px; line-height: 1.45; }}
  .grow {{ flex: 1; min-width: 0; }}
  .av {{
    width: 32px; height: 32px; border-radius: 50%;
    background: var(--color-background-tertiary);
    display: flex; align-items: center; justify-content: center;
    font-size: 12px; font-weight: 500; color: var(--color-text-secondary);
    flex: none;
  }}
  .pill {{
    font-size: 11px; font-weight: 500; padding: 3px 8px; border-radius: 999px;
    background: var(--color-background-tertiary); color: var(--color-text-secondary);
    white-space: nowrap; flex: none;
  }}
  .pill-accent {{ background: var(--accent-fill); color: var(--accent-text); }}
  .pill-warn {{ background: var(--warn-fill); color: var(--warn-text); }}
  .note {{
    display: flex; gap: 10px; padding: 11px 12px;
    border-radius: var(--border-radius-md);
    font-size: 12px; line-height: 1.55;
    flex: none;
  }}
  .note i {{ font-size: 16px; flex: none; margin-top: 1px; }}
  .note-accent {{ background: var(--accent-fill); color: var(--accent-text); }}
  .note-warn {{ background: var(--warn-fill); color: var(--warn-text); }}
  .note-plain {{ background: var(--color-background-secondary); color: var(--color-text-secondary); }}
  .field {{
    border: 0.5px solid var(--color-border-secondary);
    border-radius: var(--border-radius-md);
    padding: 11px 12px; font-size: 14px;
    color: var(--color-text-tertiary);
    flex: none;
  }}
  .code {{
    letter-spacing: 0.38em; font-size: 19px; text-align: center;
    color: var(--color-text-primary); font-weight: 500;
  }}
  .link {{ font-size: 13px; color: var(--accent-text); text-align: center; flex: none; }}
  .sheet {{
    margin-top: auto;
    background: var(--color-background-primary);
    border-top: 0.5px solid var(--color-border-tertiary);
    border-radius: var(--border-radius-lg) var(--border-radius-lg) 0 0;
    box-shadow: 0 -10px 28px rgba(0,0,0,0.13);
    padding: 14px;
    display: flex; flex-direction: column; gap: 10px;
  }}
  .scrim {{ flex: 1; background: rgba(0,0,0,0.28); }}
  .grab {{ width: 34px; height: 4px; border-radius: 2px; background: var(--color-border-tertiary); margin: 0 auto 4px; flex: none; }}
  .radio {{ width: 18px; height: 18px; border-radius: 50%; border: 1.5px solid var(--color-border-secondary); flex: none; }}
  .radio-on {{ border-color: var(--accent); border-width: 5.5px; }}
  .dim {{ opacity: 0.42; }}
  .split {{ display: flex; flex: 1; min-height: 0; }}
  .master {{ width: 260px; border-right: 0.5px solid var(--color-border-tertiary); display: flex; flex-direction: column; }}
  .detail {{ flex: 1; display: flex; flex-direction: column; }}
  .detail-inner {{ padding: 18px 20px; display: flex; flex-direction: column; gap: 14px; }}
</style>
</head>
<body>
'''

NOTE = ('\n<p class="caption" style="max-width: 760px; font-size: 12px; opacity: .8;">'
        'Copy is shown in <b>en</b>. The app ships <b>nb</b> as well; where the exact '
        'Norwegian wording is part of the decision, DESIGN-015 quotes it inline.</p>\n')


def page(fn, title, caption, panels, wide=False):
    out = [HEAD.format(title=title)]
    out.append('\n<p class="caption">%s</p>\n' % caption)
    out.append(NOTE)
    out.append('\n<div class="row">\n')
    cls = "panel panel-wide" if wide else "panel"
    for label, inner in panels:
        out.append(
            '  <div class="%s">\n    <h4>%s</h4>\n    <div class="frame"><div class="screen">%s\n    </div></div>\n  </div>\n'
            % (cls, label, inner)
        )
    out.append('</div>\n\n</body>\n</html>\n')
    (OUT / fn).write_text("".join(out), encoding="utf-8")
    print("wrote", (OUT / fn).relative_to(REPO))


ROLES = '''<div class="item"><div class="radio"></div><div class="grow"><div class="t">Owner</div><div class="s">Manages members and access, plus everything a member can do</div></div></div>
          <div class="item"><div class="radio radio-on"></div><div class="grow"><div class="t">Member</div><div class="s">Reads and publishes the plans, and sees the staff roster</div></div></div>
          <div class="item"><div class="radio"></div><div class="grow"><div class="t">Guest</div><div class="s">Reads and publishes the plans, but does not see the roster</div></div></div>'''

# ---------------------------------------------------------------- sign-in
signin_a = '''
      <div class="bar"><i class="ti ti-arrow-left"></i><span>Sign in</span></div>
      <div class="body">
        <h2 class="h">Protect your plans</h2>
        <p class="p">Signing in protects the plans you publish, so nobody else can change them. <b>You can use RingDrill without signing in.</b></p>
        <div style="height: 2px;"></div>
        <div class="btn btn-dark"><i class="ti ti-brand-apple"></i> Continue with Apple</div>
        <div class="btn"><i class="ti ti-brand-google"></i> Continue with Google</div>
        <div class="btn"><i class="ti ti-mail"></i> Continue with email</div>
        <div class="note note-plain"><i class="ti ti-user-plus"></i><span>We create a personal account for you. It owns the plans you publish. There is no password to choose or forget.</span></div>
        <div style="flex: 1;"></div>
        <div class="link">What is stored about me?</div>
      </div>'''

signin_b = '''
      <div class="bar"><i class="ti ti-arrow-left"></i><span>Sign in with email</span></div>
      <div class="body">
        <h2 class="h">Check your email</h2>
        <p class="p">We sent a link to <b>kari@example.com</b>. Open it on this device.</p>
        <div class="note note-plain"><i class="ti ti-arrow-ramp-right"></i><span>Link opening in a different browser? Type the code from the email here instead — it does the same thing.</span></div>
        <div class="sect">Code from the email</div>
        <div class="field code">K7F2Q9</div>
        <div class="btn btn-primary">Sign in</div>
        <div style="flex: 1;"></div>
        <div class="link dim">Send again (0:42)</div>
        <div class="link">Trouble signing in?</div>
      </div>'''

signin_c = '''
      <div class="bar"><i class="ti ti-menu-2"></i><span class="grow">Library</span><i class="ti ti-search"></i></div>
      <div class="body">
        <div class="note note-accent"><i class="ti ti-link"></i><span><b>Your Google sign-in was linked to the account you already have.</b><br>You are signed in as kari@example.com, not as a new user.</span></div>
        <div class="sect">My plans</div>
        <div class="card">
          <div class="item"><i class="ti ti-file-description"></i><div class="grow"><div class="t">LSOR Eidene 2026</div><div class="s">6 exercises &middot; published</div></div><span class="pill pill-accent">My account</span></div>
          <div class="item"><i class="ti ti-file-description"></i><div class="grow"><div class="t">Winter camp Voss</div><div class="s">3 exercises &middot; local</div></div></div>
          <div class="item"><i class="ti ti-file-description"></i><div class="grow"><div class="t">Avalanche course 2</div><div class="s">4 exercises &middot; published before sign-in</div></div><span class="pill"><i class="ti ti-world" style="font-size: 11px;"></i> Public</span></div>
        </div>
        <div class="note note-plain"><i class="ti ti-info-circle"></i><span>&ldquo;Avalanche course 2&rdquo; was published before you signed in and is still open to everyone. You can fork your own copy under your account.</span></div>
      </div>'''


# ---------------------------------------------------------------- recovery
rec_a = '''
      <div class="bar"><i class="ti ti-arrow-left"></i><span>Trouble signing in?</span></div>
      <div class="body">
        <p class="p">RingDrill has no passwords, so there is nothing to reset. Pick what fits:</p>
        <div class="card">
          <div class="item"><i class="ti ti-mail-off"></i><div class="grow"><div class="t">I am not getting the email</div><div class="s">The link never arrives</div></div><i class="ti ti-chevron-right"></i></div>
          <div class="item"><i class="ti ti-brand-apple"></i><div class="grow"><div class="t">My Apple address stopped working</div><div class="s">&ldquo;Hide My Email&rdquo; no longer forwards</div></div><i class="ti ti-chevron-right"></i></div>
          <div class="item"><i class="ti ti-device-mobile-off"></i><div class="grow"><div class="t">I lost the device I was signed in on</div><div class="s">Sign that device out, then sign in here</div></div><i class="ti ti-chevron-right"></i></div>
          <div class="item"><i class="ti ti-users-group"></i><div class="grow"><div class="t">I am the only owner and cannot get in</div><div class="s">Needs manual help</div></div><i class="ti ti-chevron-right"></i></div>
        </div>
        <div style="flex: 1;"></div>
        <div class="note note-plain"><i class="ti ti-shield-lock"></i><span>We do not verify identity automatically. The best protection is therefore to have more than one way in.</span></div>
      </div>'''

rec_b = '''
      <div class="bar"><i class="ti ti-arrow-left"></i><span>Not getting the email</span></div>
      <div class="body">
        <div class="note note-plain"><i class="ti ti-eye-off"></i><span>Deliberately generic. This screen never reveals whether an address has an account.</span></div>
        <h2 class="h">Try another sign-in</h2>
        <p class="p">If <b>kari@example.com</b> has an account, it may also have Apple or Google sign-in. Both lead to the same account.</p>
        <div class="btn btn-dark"><i class="ti ti-brand-apple"></i> Continue with Apple</div>
        <div class="btn"><i class="ti ti-brand-google"></i> Continue with Google</div>
        <div class="sect">Otherwise</div>
        <div class="card">
          <div class="item"><i class="ti ti-refresh"></i><div class="grow"><div class="t">Send the link again</div><div class="s">Check your spam folder too</div></div></div>
          <div class="item"><i class="ti ti-pencil"></i><div class="grow"><div class="t">Use a different address</div><div class="s">Creates a new account</div></div></div>
        </div>
        <div style="flex: 1;"></div>
        <div class="note note-warn"><i class="ti ti-alert-triangle"></i><span>If email is your only sign-in and the address is gone, we cannot open the account for you.</span></div>
      </div>'''

rec_c = '''
      <div class="bar"><i class="ti ti-arrow-left"></i><span class="grow">Members</span><i class="ti ti-user-plus"></i></div>
      <div class="body">
        <div class="note note-warn"><i class="ti ti-alert-triangle"></i><span><b>This organisation has one owner.</b> Add another, so access is not lost if someone becomes unavailable.<br><span style="opacity: .85;">Not blocking. Dismissible, but returns when the member list changes.</span></span></div>
        <div class="sect">Red Cross Bergen</div>
        <div class="card">
          <div class="item"><div class="av">KG</div><div class="grow"><div class="t">Kari Gulbrandsen <span class="s" style="display: inline;">(you)</span></div><div class="s">kari@example.com</div></div><span class="pill pill-accent">Owner</span></div>
          <div class="item"><div class="av">OH</div><div class="grow"><div class="t">Ola Hansen</div><div class="s">ola@example.com</div></div><span class="pill">Member</span></div>
          <div class="item"><div class="av">MS</div><div class="grow"><div class="t">Mari Sund</div><div class="s">mari@example.com</div></div><span class="pill">Guest</span></div>
        </div>
        <div class="btn"><i class="ti ti-crown"></i> Make someone an owner</div>
        <div style="flex: 1;"></div>
        <div class="note note-plain"><i class="ti ti-info-circle"></i><span>There is no self-service ownership transfer for whoever is locked out — that would be a takeover mechanism.</span></div>
      </div>'''


# ---------------------------------------------------------------- personal
pers_a = '''
      <div class="bar"><i class="ti ti-x"></i><span>RingDrill</span></div>
      <div class="body" style="gap: 10px;">
        <div class="item" style="border: 0; padding: 4px 2px 10px;"><div class="av">KG</div><div class="grow"><div class="t">Kari Gulbrandsen</div><div class="s">kari@example.com</div></div><i class="ti ti-chevron-right"></i></div>
        <div class="note note-plain"><i class="ti ti-user"></i><span>Personal account. No account switcher — it appears only once you belong to more than one.</span></div>
        <div class="card">
          <div class="item"><i class="ti ti-books"></i><div class="grow"><div class="t">Library</div></div></div>
          <div class="item"><i class="ti ti-badge"></i><div class="grow"><div class="t">My role</div><div class="s">Exercise director</div></div><i class="ti ti-chevron-right"></i></div>
          <div class="item"><i class="ti ti-settings"></i><div class="grow"><div class="t">Settings</div></div></div>
          <div class="item"><i class="ti ti-help"></i><div class="grow"><div class="t">Help</div></div></div>
        </div>
        <div class="note note-warn"><i class="ti ti-alert-circle"></i><span><b>Two different roles.</b> &ldquo;My role&rdquo; here is your role during an exercise (ADR-0057). Access to an organisation&rsquo;s plans is set on the account page. They must never be merged.</span></div>
      </div>'''

pers_b = '''
      <div class="bar"><i class="ti ti-arrow-left"></i><span>Account</span></div>
      <div class="body">
        <div class="item" style="border: 0; padding: 2px;"><div class="av">KG</div><div class="grow"><div class="t">Kari Gulbrandsen</div><div class="s">kari@example.com &middot; Personal account</div></div></div>
        <div class="sect">Sign-in methods</div>
        <div class="card">
          <div class="item"><i class="ti ti-mail"></i><div class="grow"><div class="t">Email</div><div class="s">kari@example.com</div></div><span class="pill pill-accent">Active</span></div>
          <div class="item"><i class="ti ti-brand-google"></i><div class="grow"><div class="t">Google</div><div class="s">kari@example.com</div></div></div>
          <div class="item"><i class="ti ti-plus"></i><div class="grow"><div class="t">Link Apple</div><div class="s">Recommended: gives you a second way in</div></div></div>
        </div>
        <div class="sect">Devices</div>
        <div class="card">
          <div class="item"><i class="ti ti-device-mobile"></i><div class="grow"><div class="t">iPhone 15 &middot; this one</div><div class="s">Active now</div></div></div>
          <div class="item"><i class="ti ti-device-laptop"></i><div class="grow"><div class="t">MacBook Pro</div><div class="s">Last used 2 August</div></div><span class="pill">Sign out</span></div>
        </div>
        <div class="sect">Organisation</div>
        <div class="card"><div class="item"><i class="ti ti-users-group"></i><div class="grow"><div class="t">Create organisation</div><div class="s">To share plans with others</div></div><i class="ti ti-chevron-right"></i></div></div>
        <div class="card"><div class="item"><i class="ti ti-database"></i><div class="grow"><div class="t">What is stored about the account?</div></div><i class="ti ti-chevron-right"></i></div></div>
        <div class="btn">Sign out</div>
        <div class="btn btn-danger">Delete account</div>
      </div>'''

pers_c = '''
      <div class="scrim"></div>
      <div class="sheet">
        <div class="grab"></div>
        <h2 class="h">Invite Ola — and turn this into an organisation</h2>
        <p class="p">To share plans with someone else, your personal account has to become an organisation. Here is what changes:</p>
        <div class="card">
          <div class="item"><i class="ti ti-tag"></i><div class="grow"><div class="s" style="margin: 0;">The account gets a name of its own. Suggested: <b>Kari Gulbrandsen</b></div></div></div>
          <div class="item"><i class="ti ti-file-check"></i><div class="grow"><div class="s" style="margin: 0;">Your plans stay where they are. Nothing moves and nothing is republished.</div></div></div>
          <div class="item"><i class="ti ti-pencil"></i><div class="grow"><div class="s" style="margin: 0;">Ola joins as <b>Member</b>, and can read and publish them.</div></div></div>
          <div class="item"><i class="ti ti-lock"></i><div class="grow"><div class="s" style="margin: 0;"><b>This cannot be undone.</b> The account stays an organisation even if you remove Ola again.</div></div></div>
        </div>
        <div class="btn btn-primary">Convert and invite</div>
        <div class="btn">Create a new organisation instead</div>
        <div class="link">Cancel</div>
      </div>'''


# ---------------------------------------------------------------- organisation
org_a = '''
      <div class="bar"><i class="ti ti-arrow-left"></i><span class="grow">Red Cross Bergen</span><i class="ti ti-user-plus"></i></div>
      <div class="body">
        <div class="sect">Members &middot; 4</div>
        <div class="card">
          <div class="item"><div class="av">KG</div><div class="grow"><div class="t">Kari Gulbrandsen <span class="s" style="display: inline;">(you)</span></div><div class="s">Only owner</div></div><span class="pill pill-accent">Owner</span></div>
          <div class="item"><div class="av">OH</div><div class="grow"><div class="t">Ola Hansen</div><div class="s">ola@example.com</div></div><span class="pill">Member</span><i class="ti ti-chevron-right"></i></div>
          <div class="item"><div class="av">MS</div><div class="grow"><div class="t">Mari Sund</div><div class="s">mari@example.com &middot; another corps</div></div><span class="pill">Guest</span><i class="ti ti-chevron-right"></i></div>
          <div class="item"><div class="av"><i class="ti ti-mail" style="font-size: 15px;"></i></div><div class="grow"><div class="t">per@example.com</div><div class="s">Invited 3 August &middot; no reply yet</div></div><span class="pill pill-warn">Invited</span></div>
          <div class="item dim"><div class="av"><i class="ti ti-mail-x" style="font-size: 15px;"></i></div><div class="grow"><div class="t">lise@exampel.com</div><div class="s" style="color: var(--danger-text);">Email bounced &middot; check the address</div></div><span class="pill">Failed</span></div>
        </div>
        <div class="note note-plain"><i class="ti ti-info-circle"></i><span><b>Everyone you add can work on the plans.</b> The difference is whether they see the staff roster. Access also says nothing about your role during an exercise — a guest can be the exercise director.</span></div>
        <div style="flex: 1;"></div>
        <div class="btn"><i class="ti ti-user-plus"></i> Invite someone to collaborate</div>
      </div>'''

org_b = '''
      <div class="scrim"></div>
      <div class="sheet">
        <div class="grab"></div>
        <div class="item" style="border: 0; padding: 0 0 4px;"><div class="av">OH</div><div class="grow"><div class="t">Ola Hansen</div><div class="s">ola@example.com</div></div></div>
        <div class="sect" style="margin-top: 2px;">Access in the organisation</div>
        <div class="card">
          ''' + ROLES + '''
        </div>
        <div class="note note-plain"><i class="ti ti-bolt"></i><span>Takes effect the next time Ola does something; no need to sign in again. <b>Demotion does not withdraw trust</b> — a guest publishes too. If he should not work on the plans at all, Remove is the only action.</span></div>
        <div class="btn btn-danger"><i class="ti ti-user-minus"></i> Remove from the organisation</div>
      </div>'''

org_c = '''
      <div class="scrim"></div>
      <div class="sheet">
        <div class="grab"></div>
        <h2 class="h">Remove Ola Hansen?</h2>
        <div class="card">
          <div class="item"><i class="ti ti-lock"></i><div class="grow"><div class="s" style="margin: 0;">Ola loses access to the organisation&rsquo;s plans and can no longer publish updates. This is the only action that actually withdraws trust.</div></div></div>
          <div class="item"><i class="ti ti-device-mobile"></i><div class="grow"><div class="s" style="margin: 0;"><b>Plans he has already downloaded stay on his own device.</b> We cannot remove them from there.</div></div></div>
        </div>
        <div class="btn btn-danger">Remove Ola</div>
        <div class="link">Cancel</div>
      </div>'''

org_d = '''
      <div class="bar"><i class="ti ti-arrow-left"></i><span>Invite</span></div>
      <div class="body">
        <div class="sect">Email address</div>
        <div class="field">per@example.com</div>
        <p class="p">They do not need RingDrill already. The invitation binds when they sign in for the first time — and a guest is a signed-in person too, with their own personal account.</p>
        <div class="sect">Access</div>
        <div class="card">
          ''' + ROLES + '''
        </div>
        <div class="note note-plain"><i class="ti ti-user-check"></i><span>The question is not how much this person should be allowed to do, but whether they should have your people&rsquo;s phone numbers. Access is chosen now — &ldquo;Invited&rdquo; is a state, not a role.</span></div>
        <div style="flex: 1;"></div>
        <div class="btn btn-primary">Send invitation</div>
      </div>'''


# ---------------------------------------------------------------- wide / web
wide = '''
      <div class="bar"><i class="ti ti-menu-2"></i><span class="grow">Settings</span><div class="pill pill-accent"><i class="ti ti-users-group" style="font-size: 11px;"></i> Red Cross Bergen</div><i class="ti ti-selector"></i></div>
      <div class="split">
        <div class="master">
          <div class="body" style="padding: 12px 10px; gap: 8px;">
            <div class="card">
              <div class="item"><i class="ti ti-user"></i><div class="grow"><div class="t">Account</div></div><i class="ti ti-chevron-right"></i></div>
              <div class="item" style="background: var(--accent-fill);"><i class="ti ti-users-group" style="color: var(--accent-text);"></i><div class="grow"><div class="t" style="color: var(--accent-text); font-weight: 500;">Members</div><div class="s" style="color: var(--accent-text); opacity: .85;">4 members &middot; 1 invited</div></div></div>
              <div class="item"><i class="ti ti-badge"></i><div class="grow"><div class="t">My role</div><div class="s">Exercise director</div></div></div>
              <div class="item"><i class="ti ti-map"></i><div class="grow"><div class="t">Map</div></div></div>
              <div class="item"><i class="ti ti-bell"></i><div class="grow"><div class="t">Notifications</div></div></div>
              <div class="item"><i class="ti ti-chart-dots"></i><div class="grow"><div class="t">Privacy</div></div></div>
            </div>
            <div class="note note-plain"><i class="ti ti-info-circle"></i><span>&ldquo;My role&rdquo; and &ldquo;Members&rdquo; are different axes, so they sit as siblings — never as one setting.</span></div>
          </div>
        </div>
        <div class="detail">
          <div class="detail-inner">
            <div style="display: flex; align-items: center; gap: 12px;">
              <div class="av" style="width: 40px; height: 40px; font-size: 14px;">RC</div>
              <div class="grow"><div style="font-size: 17px; font-weight: 500;">Red Cross Mountain Rescue Bergen</div><div class="s">Organisation &middot; created 12 June 2026</div></div>
              <div class="btn" style="height: 36px; padding: 0 14px;"><i class="ti ti-user-plus"></i> Invite</div>
            </div>
            <div class="note note-warn"><i class="ti ti-alert-triangle"></i><span><b>This organisation has one owner.</b> Add another, so access is not lost if someone becomes unavailable.</span></div>
            <div style="display: flex; gap: 16px; align-items: flex-start;">
              <div class="card" style="flex: 1;">
                <div class="item"><div class="av">KG</div><div class="grow"><div class="t">Kari Gulbrandsen (you)</div><div class="s">kari@example.com</div></div><span class="pill pill-accent">Owner</span></div>
                <div class="item" style="background: var(--color-background-secondary);"><div class="av">OH</div><div class="grow"><div class="t">Ola Hansen</div><div class="s">ola@example.com</div></div><span class="pill">Member</span></div>
                <div class="item"><div class="av">MS</div><div class="grow"><div class="t">Mari Sund</div><div class="s">mari@example.com</div></div><span class="pill">Guest</span></div>
                <div class="item"><div class="av"><i class="ti ti-mail" style="font-size: 15px;"></i></div><div class="grow"><div class="t">per@example.com</div><div class="s">Invited 3 August</div></div><span class="pill pill-warn">Invited</span></div>
              </div>
              <div class="card" style="width: 300px;">
                <div class="item" style="gap: 10px;"><div class="av">OH</div><div class="grow"><div class="t">Ola Hansen</div><div class="s">ola@example.com &middot; member since 14 June</div></div></div>
                <div class="item" style="display: block; padding: 12px;">
                  <div class="sect" style="margin: 0 0 8px 0;">Access in the organisation</div>
                  <div style="display: flex; gap: 10px; align-items: flex-start; margin-bottom: 10px;"><div class="radio"></div><div><div class="t">Owner</div><div class="s">Manages members and access, plus everything a member can do</div></div></div>
                  <div style="display: flex; gap: 10px; align-items: flex-start; margin-bottom: 10px;"><div class="radio radio-on"></div><div><div class="t">Member</div><div class="s">Reads and publishes the plans, and sees the staff roster</div></div></div>
                  <div style="display: flex; gap: 10px; align-items: flex-start;"><div class="radio"></div><div><div class="t">Guest</div><div class="s">Reads and publishes the plans, but does not see the roster</div></div></div>
                </div>
                <div class="item"><i class="ti ti-user-minus" style="color: var(--danger-text);"></i><div class="grow"><div class="t" style="color: var(--danger-text);">Remove from the organisation</div></div></div>
              </div>
            </div>
            <div class="note note-plain"><i class="ti ti-database"></i><span><b>What is stored about the account?</b> Plans, and — once plan sync ships — the staff roster entered for them. Everyone in the organisation can publish; only owners and members <b>see the roster</b>, not guests, and not other accounts the plan is shared with. A plan published to the catalog never carries it (ADR-0072).</span></div>
          </div>
        </div>
      </div>'''


# ---------------------------------------------------------------- library tabs
def tab(label, active=False):
    st = "flex: 1; text-align: center; padding: 11px 2px; white-space: nowrap;"
    st += (" color: var(--accent); font-weight: 500; box-shadow: inset 0 -2px 0 var(--accent);"
           if active else " color: var(--color-text-secondary);")
    return '<div style="%s">%s</div>' % (st, label)

TABS = '\n        <div style="display: flex; border-bottom: 0.5px solid var(--color-border-tertiary); font-size: 12.5px;">%s</div>'

lib_a = '''
      <div class="bar"><i class="ti ti-x"></i><span class="grow">Open plan</span></div>''' + TABS % (
    tab("My plans", True) + tab("Public") + tab("New from file")) + '''
      <div class="body">
        <div class="card">
          <div class="item"><i class="ti ti-file-description"></i><div class="grow"><div class="t">Winter camp Voss</div><div class="s">3 exercises &middot; edited yesterday</div></div></div>
          <div class="item"><i class="ti ti-file-description"></i><div class="grow"><div class="t">Avalanche course 2</div><div class="s">4 exercises &middot; edited 28 July</div></div></div>
        </div>
        <div class="note note-accent"><i class="ti ti-check"></i><span><b>Three tabs, exactly as today.</b> With no account there is no Account tab. No badge, no &ldquo;finish setting up&rdquo; — this is a finished state, not a step on the way to one.</span></div>
        <div class="note note-plain"><i class="ti ti-pencil"></i><span>The only change for a signed-out user: <b>&ldquo;Online&rdquo; is now &ldquo;Public&rdquo;</b> — it answers who can read the plan, not where it is stored.</span></div>
      </div>'''

lib_b = '''
      <div class="bar"><i class="ti ti-x"></i><span class="grow">Open plan</span><div class="pill pill-accent">Red Cross Bergen</div></div>''' + TABS % (
    tab("My plans") + tab("Account", True) + tab("Public") + tab("New from file")) + '''
      <div class="body">
        <div class="card">
          <div class="item"><i class="ti ti-file-description"></i><div class="grow"><div class="t">LSOR Eidene 2026</div><div class="s">6 exercises &middot; published &middot; v5</div></div><span class="pill pill-accent"><i class="ti ti-users-group" style="font-size: 11px;"></i></span></div>
          <div class="item"><i class="ti ti-file-description"></i><div class="grow"><div class="t">Autumn camp 2026</div><div class="s">2 exercises &middot; not published</div></div><span class="pill">Draft</span></div>
        </div>
        <div class="note note-plain"><i class="ti ti-eye-off"></i><span>&ldquo;Autumn camp 2026&rdquo; is not published and is not in the catalog. It is still here, because the account owns it — which is exactly what separates this tab from &ldquo;Public&rdquo;.</span></div>
        <div class="note note-plain"><i class="ti ti-switch-horizontal"></i><span>The tab follows the active account in the top bar. Belong to several and you switch there; the tabs do not multiply.</span></div>
      </div>'''


def main():
    page("auth-signin.html", "Sign-in",
         "DESIGN-015 &sect;3. Signing in is optional and never blocks planning. Provider order follows the platform (iOS here). The code field in the middle solves the hardest problem with magic links — that the link opens somewhere other than where you started. On the right, provider linking is announced once: someone who signs in with a different button and lands in the same account should be told why.",
         [("1 &middot; Choose a sign-in", signin_a),
          ("2 &middot; Waiting for the link — with a code", signin_b),
          ("3 &middot; Provider linked (once)", signin_c)])

    page("auth-recovery.html", "Account recovery",
         "DESIGN-015 &sect;4. Without passwords there is no &ldquo;forgot password&rdquo;. These four situations replace it, and only the last one loses data. Its answer is prevention rather than recovery, which is why the advice lives on the members screen (panel 3) and not in the recovery flow.",
         [("1 &middot; The four situations", rec_a),
          ("2 &middot; Generic answer, no disclosure", rec_b),
          ("3 &middot; Prevention: a single owner", rec_c)])

    page("account-personal.html", "Personal account",
         "DESIGN-015 &sect;5.2–5.3. For a single planner the account is bookkeeping, so the page is short and the account switcher is hidden. The upgrade to an organisation states what changes <i>before</i> the action — especially that it cannot be undone, which is the part users get wrong. The alternative, &ldquo;create a new organisation instead&rdquo;, sits on the same sheet.",
         [("1 &middot; Drawer, signed in", pers_a),
          ("2 &middot; Personal account page", pers_b),
          ("3 &middot; Upgrade to an organisation", pers_c)])

    page("account-organisation.html", "Organisation and members",
         "DESIGN-015 &sect;6. Every role publishes, so the picker is not a permission ladder — the difference between Member and Guest is the staff roster, and the copy says so. Note &ldquo;Invited&rdquo; and &ldquo;Failed&rdquo; as <i>states</i> on the row rather than roles, and that removal is the only action that withdraws trust.",
         [("1 &middot; Members, with invitations", org_a),
          ("2 &middot; Change access", org_b),
          ("3 &middot; Remove a member", org_c),
          ("4 &middot; Invite", org_d)])

    page("account-wide.html", "Account on wide screen and web",
         "DESIGN-015 &sect;5.6. On wide screens and on the web the account page follows the master/detail model from ADR-0030: the member list is master and the selected member is detail, not a bottom sheet. The account switcher sits in the top bar, and must also appear in the publish dialog so nobody publishes to the wrong account without seeing it.",
         [("Settings &rarr; Members &middot; 1280&times;800", wide)], wide=True)

    page("library-tabs.html", "Plan selector with an account",
         "DESIGN-015 &sect;5.7. Accounts add a source that is neither local nor public, so the selector goes from three tabs to four — but only for someone who actually has an account. &ldquo;Online&rdquo; becomes &ldquo;Public&rdquo;, because the word stops distinguishing anything the moment the Account tab is also on the network.",
         [("No account — as today", lib_a), ("With an organisation — fourth tab", lib_b)])


if __name__ == "__main__":
    main()
