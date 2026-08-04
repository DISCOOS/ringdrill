---
layout: ../../../layouts/DocsLayout.astro
lang: en
title: 'RingDrill: Command line'
description: 'The ringdrill CLI compiles, checks and renders a plan document offline, and talks to the catalogue.'
canonicalPath: /en/docs/cli
---

# Command line

`ringdrill` compiles a [plan document](/en/docs/plan-format) into the `.drill` archive the app opens, and does the reverse. The compiler runs entirely on your machine: no account, no network, nothing sent anywhere. Only the catalogue commands at the bottom of this page use the network at all.

## Getting it

There is no download yet. Build it from a checkout, which needs the Dart SDK:

```
git clone https://github.com/DISCOOS/ringdrill.git
cd ringdrill
make cli-build
```

The binary lands in `build/cli/`. If that is more setup than you want, [an AI assistant over MCP](/en/docs/mcp) runs the same commands with nothing installed.

## Writing a plan

**`create`** scaffolds a document that builds as-is, which is a better starting point than an empty file. It demonstrates the scenario layer, so you can see how a station-owned location and a person referenced by slug are meant to fit together.

```
ringdrill create --name="Winter exercise 2027" --exercises=3 --teams=6
```

`--stations=N`, `--rounds=N`, `--lang=<code>` and `--out=<file>` all apply. `--bare` skips the scenario example if you want the skeleton only.

**`analyze`** checks a document without building it. Run it constantly. It is fast, and it catches the things that compile but read wrong.

```
ringdrill analyze plan.yaml
```

`--strict` turns warnings into failures, which is what you want in a script.

**`render`** produces the markdown brief someone actually reads. This is the real check on whether a plan makes sense: an unresolved token or a station with nothing in it is obvious in the brief and invisible in the source.

```
ringdrill render plan.yaml --audience=instructor
```

`--audience` takes `participant` (the default, and the printed handout, which withholds every staff-facing field), `actor`, `instructor`, `director` or `other`. Narrow with `--exercise=N` and `--station=N`. `--format=summary` gives you the headings and which sections each scope carries, without the prose. Use it while iterating, because a real plan's brief runs to tens of kilobytes.

**`build`** compiles to an archive.

```
ringdrill build plan.yaml --out=plan.drill
```

`--strict` refuses to build if there are warnings.

**`decompile`** goes the other way, printing the source document for an existing archive. It is the best way to learn the format, and the way to pick up a plan you only have as a `.drill`.

```
ringdrill decompile plan.drill
```

**`schema`** prints the format's JSON Schema. Point your editor at it for completion and inline validation:

```
ringdrill schema > ringdrill.schema.json
```

## The catalogue

These three reach the network.

```
ringdrill feed
ringdrill download <slug>
ringdrill upload plan.drill
```

`feed` lists published plans, `download` fetches one as a `.drill` (`--version=N` for an older one), and `upload` sends yours. An upload does not publish it. Putting a plan into the shared catalogue stays a deliberate step, and there are admin commands behind a token for that.

## A note on names

Never write numbering into a name. The app renders station and exercise codes itself, so a station called `2a) House search` renders as `2a) 2a) House search`. Numbering comes from position in the list. See [the plan format](/en/docs/plan-format) for the rest of the rules to know before you write much.
