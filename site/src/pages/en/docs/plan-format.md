---
layout: ../../../layouts/DocsLayout.astro
lang: en
title: 'RingDrill: The plan format'
description: 'A RingDrill plan can be one YAML document that compiles to a .drill archive. What the document contains, and the rules that catch people out.'
canonicalPath: /en/docs/plan-format
---

# The plan format

A plan can be written as a single YAML file and compiled into the `.drill` archive the app opens. The file is the **source document**: the thing you edit, keep and review. The archive is the build output.

This page describes the shape and the rules. It does not list every field, on purpose. The field list is generated from the compiler's own table, so any copy here would be wrong within a release. Get the current one from `ringdrill schema`, or ask an assistant for the `schema` tool. Both emit JSON Schema, which most editors will use for completion and inline errors.

## What a document holds

Roughly, it nests like the exercise does.

A plan carries a name, a language, and its exercises. Each exercise carries its round length, its stations, and how many teams rotate through them. The compiler derives the rotation from that: who is at which station in which round, and when each round starts. You do not write the schedule.

Over that sits the part that makes a plan an exercise rather than a timetable. Locations put a station somewhere real, including UTM coordinates. Persons are the fictional people in the scenario, a missing hiker or a casualty. Roleplays say how a marker portrays one of those persons. Variables hold the values that get decided on the day: a duty phone number, a talkgroup, a command post.

Briefs come out of the same source for each audience, participant through exercise director, with staff-facing fields withheld from the participant's copy.

## Rules that catch people out

These are the ones that produce a plan which compiles cleanly and is still wrong.

**Numbering comes from position in the list.** The app renders station and exercise codes itself. Write `2a)` or `#3` into a name and it renders twice, as `2a) 2a) House search`. Name the thing, not its place in the order.

**Derived fields do not belong in the document.** The schedule, end times, indices, uuids and the content hash are all computed. The schema leaves them out, and writing one in is at best ignored.

**Tokens are content, not something to resolve as you write.** Write `{{var.duty_phone}}` or `{{station.loc.lkp.utm}}` literally. They resolve when the brief renders, which is the point: change the variable once and every brief follows.

**Three fields get asked for by name.** An exercise's `method`, a station's `description`, and a roleplay's `description`. These are the easiest to skip, because a source booklet has no heading that maps to them. It gives you the scenario and the running order, which belong in `situation` and `mission`. A station with no description shows *Missing: Station description* in its own card until someone fills it.

A station's `description` is not its `situation` restated. The first is the station as staff refer to it, "house search for a missing woman with dementia". The second is the scenario as the team meets it. If one repeats the other, cut the description to the line that tells this station apart from the one before it.

**Keep real people out.** `persons` are fictional. A marker roster or a named contact belongs nowhere in a plan, so drop the name and keep the role. An operational *value* is different and does belong: a duty number, a command post number, a talkgroup. Declare it as a variable and reference the token, never the literal, because those change on the day and a variable is exactly the thing that survives that.

Nothing in a markdown field is stripped when a plan is published. Instructor notes, marker behaviour and staff-only descriptions all travel with the archive.

## Learn it from a plan that works

The fastest way in is not this page. Take a published plan from the [catalogue](/en/catalog) and decompile it:

```
ringdrill download <slug>
ringdrill decompile <slug>.drill
```

That prints the source document for a working plan, in the same format you would write, with the derived fields stripped back out. Read it for scope and tone: how much a station actually carries, how long a brief runs.

Read it for structure with more care. The catalogue is a shared corpus, so a published plan can predate the current format. It may well carry flat descriptions, values that should be variables, or numbering written into a name. `ringdrill analyze` will tell you which.

The round trip is exact in the direction that matters. Compiling a decompiled plan reproduces the same content hash, so decompiling a plan to look at it cannot quietly change it.
