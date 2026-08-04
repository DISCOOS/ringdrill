---
layout: ../../../layouts/DocsLayout.astro
lang: en
title: 'RingDrill: Documentation'
description: 'How to write a RingDrill exercise plan: in the app, with an AI assistant, or on the command line.'
canonicalPath: /en/docs
---

# Documentation

RingDrill runs exercises where teams rotate between stations. The app handles the running: round times, who is where, briefs to each role. These pages cover the part before that, which is writing the plan.

For most exercises the app is enough. These pages are for the ones where it is not.

Some plans get big. Seven exercises across a weekend, forty stations, a scenario of locations and missing persons, briefs that have to say different things to participants, markers and instructors. That is a lot to keep straight in an app, and it is material you will want back next year.

## A plan can be a file

Under the app's editor is a plain text format. One YAML file describes a whole plan, and the compiler turns it into the `.drill` archive the app opens.

That buys the things text buys. You can keep a plan in version control and see exactly what changed since last year's exercise. You can copy the useful half of an old plan without rebuilding it. You can hand it to someone for review before anyone commits to it. And you can generate a brief for every role, from one source, without maintaining four documents that drift apart.

Three ways in, all producing the same archive from the same format:

- **[The plan format](/en/docs/plan-format)** covers what the document looks like and the rules that catch people out. Read it first even if you never write one by hand.
- **[The command line](/en/docs/cli)** compiles, checks and renders a plan offline. For anyone comfortable in a terminal, and for anything scripted.
- **[MCP for AI assistants](/en/docs/mcp)** lets you connect an assistant and draft the plan by talking to it. Nothing to install. It also sends your plan to a server, so read what that means before you use it on anything sensitive.

## Also here

- **[The catalogue](/en/catalog)** holds published plans you can read and reuse. Start there: adapting a plan that already works beats writing from an empty file.
- **[The HTTP API](https://ringdrill.app/api/docs)** is the backend the app talks to, if you are integrating something.
- **[The source on GitHub](https://github.com/DISCOOS/ringdrill)**. RingDrill is open source, and the architecture notes and decision log live under `docs/`.
