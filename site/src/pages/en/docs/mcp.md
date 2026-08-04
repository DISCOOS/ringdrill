---
layout: ../../../layouts/DocsLayout.astro
lang: en
title: 'RingDrill: MCP for AI assistants'
description: 'Draft a RingDrill exercise plan with an AI assistant. What the hosted endpoint does with the plan you send it, and how to connect a client.'
canonicalPath: /en/docs/mcp
---

# MCP for AI assistants

RingDrill has an [MCP](https://modelcontextprotocol.io/) endpoint. Connect it to an AI assistant, whether that is Claude, ChatGPT, Copilot or anything else that speaks MCP, and the assistant can read the public plan catalogue, draft an exercise plan with you, check it for mistakes, render the briefs, and hand you back a `.drill` file to open in the app.

It is meant for the part of the work that happens before the exercise: turning a scenario in your head, or a booklet from last year, into a plan with rounds, stations and briefs that hold together. It does not run the exercise. That is still the app's job.

There is no account and no sign-in. The endpoint is:

```
https://api.ringdrill.app/mcp
```

## What happens to a plan you send it

Read this part before you paste anything in. A drill plan is often working material for a real operation, and this endpoint is a server on the internet rather than a program on your machine.

**By default it keeps nothing.** It receives a plan, compiles it, answers, and forgets it. There is no database of plans, no log of what you sent, and no way to ask it later for something you sent earlier. That is a design requirement, not a policy we could quietly change: there is nowhere for it to go.

Two things narrow that, and you should understand both before you rely on the sentence above.

1. **Your assistant may ask the server to hold a document, and it will.** Long plans are expensive to resend on every step, so a call can set `cache: true`. The server then holds that document for **30 minutes**, keyed by a checksum of its own contents. Nothing else changes, but for those 30 minutes anyone who has that checksum can ask for the document back. The checksum is only obtainable by having already had the document, so this is not a hole so much as a short-lived key you should know exists.

2. **A plan it builds for you is held so you can download it.** When the assistant compiles your plan, the resulting `.drill` file is kept for **30 minutes** and you get a download link. This is how the file reaches you at all, since a real plan is far too large to pass back through a chat window. Passing `inline: true` returns the file as text in the reply instead, and keeps nothing.

Everything the endpoint reads from the catalogue is already public: the same plans you can browse on [the catalogue page](/en/catalog). It cannot see unpublished plans, and it has no way to publish anything. Putting a plan into the shared catalogue stays a human step, done deliberately in the app.

## If a plan is staff-only

Then use the local server instead, not this one.

Plenty of real plans are marked for staff eyes only, and nothing about a hosted endpoint changes what that means. Sending such a plan here means it leaves your machine, is processed by a third-party host, and travels over the network. The retention promises above hold, and they are still not the same thing as never having sent it.

RingDrill ships the same tools as a server you run yourself, on your own machine, with no network involved. It needs a checkout and a Dart toolchain, so it is more work to set up, and it is the right answer when the plan is sensitive. The setup is documented in [mcp/README.md](https://github.com/DISCOOS/ringdrill/blob/main/mcp/README.md).

The hosted endpoint exists so people without a toolchain can use this at all. It is not the recommended path for sensitive material, and it is deliberately not the only path.

## What it can do

Seven tools. Your assistant picks between them; you should not have to.

- **`schema`** gives the exact shape of a plan document, so the assistant writes something that will actually compile.
- **`search_catalog`** lists published plans in the open catalogue.
- **`get_plan`** fetches a published plan as an editable document, to read for scope and tone or to adapt.
- **`create_plan`** scaffolds a working starting point rather than a blank page.
- **`analyze_plan`** checks a draft and reports what is wrong or missing.
- **`render_plan`** renders the brief a participant, marker, instructor or exercise director would read. The fastest way to see whether a plan makes sense.
- **`build_plan`** compiles the plan into a `.drill` file you can open in RingDrill.

There is deliberately no publish tool.

## Limits

The endpoint is open, unauthenticated and free, which means it needs a few edges to stay that way:

- **60 requests per minute** per caller. Wide of any real drafting session, and narrow enough that a runaway script does not become a bill.
- **512 KB** per plan document, and **1 MB** per request.
- **10 seconds** per compile.

If you hit the request limit while drafting an ordinary plan, tell us. It means the setting is wrong.

## Connect a client

Any client that accepts a remote MCP server accepts this one. There is no command to run and no path to configure, just the URL.

Claude Code:

```
claude mcp add --transport http ringdrill https://api.ringdrill.app/mcp
```

Claude Desktop, ChatGPT and Codex CLI take the URL in their own connector settings. In VS Code, `.vscode/mcp.json`:

```
{
  "servers": {
    "ringdrill": {
      "type": "http",
      "url": "https://api.ringdrill.app/mcp"
    }
  }
}
```

The endpoint describes its own tools to whichever client connects, so there is nothing further to configure. Ask the assistant to draft an exercise and it will find its way.

## A note on what the assistant writes

An assistant is good at structure and fast at prose. It does not know your terrain, your teams, or what went wrong at the last exercise, and it will produce a confident-sounding station description that is subtly useless if you let it.

Read what it drafts, especially the parts a participant will act on. `render_plan` exists for exactly this: read the brief, not the source. And keep real people out of the plan. Names of markers, contacts and duty personnel do not belong in a document that gets rendered and handed out. Use a variable for the values that change on the day.
