---
layout: ../../layouts/DocsLayout.astro
lang: nb
title: 'RingDrill: Kommandolinje'
description: 'ringdrill bygger, sjekker og lager briefer fra en planfil lokalt, og snakker med katalogen.'
canonicalPath: /docs/cli
---

# Kommandolinje

`ringdrill` bygger et [plandokument](/docs/plan-format) til `.drill`-fila appen åpner, og pakker den ut igjen. Alt skjer lokalt: ingen innlogging, ingen nettverkstrafikk, ingenting sendt ut av maskinen. Bare katalogkommandoene nederst bruker nett.

## Slik får du den

Det finnes ingen ferdig nedlasting ennå. Du bygger den fra kildekoden, og trenger Dart SDK:

```
git clone https://github.com/DISCOOS/ringdrill.git
cd ringdrill
make cli-build
```

Binæren havner i `build/cli/`. Vil du ikke sette opp dette, gjør [en KI-assistent over MCP](/docs/mcp) de samme jobbene uten at du installerer noe.

## Lage og sjekke en plan

**`create`** lager et dokument som bygger med én gang. Bedre utgangspunkt enn en tom fil, for det viser scenariolaget: en post som eier et sted, en person som refereres med slug, og et rollespill som spiller personen.

```
ringdrill create --name="Vinterøvelse 2027" --exercises=3 --teams=6
```

`--stations=N`, `--rounds=N`, `--lang=<kode>` og `--out=<fil>` virker alle. Vil du bare ha skjelettet, uten scenarioeksempelet, bruk `--bare`.

**`analyze`** sjekker fila uten å bygge. Kjør den ofte. Den er rask, og den finner det som bygger fint men leses feil.

```
ringdrill analyze plan.yaml
```

`--strict` gjør advarsler til feil. Det vil du ha i skript.

**`render`** lager briefen folk faktisk leser. Dette er den egentlige prøven på om planen holder: et token som ikke er erstattet, eller en post uten innhold, ser du med én gang i briefen og aldri i kildefila.

```
ringdrill render plan.yaml --audience=instructor
```

`--audience` tar `participant` (standard, og den som skrives ut til deltakerne, uten stabsinterne felter), `actor`, `instructor`, `director` eller `other`. Avgrens med `--exercise=N` og `--station=N`. `--format=summary` gir bare overskriftene og hvilke deler hvert nivå har. Bruk den mens du jobber, for briefen til en reell plan blir fort titalls kilobyte.

**`build`** lager `.drill`-fila.

```
ringdrill build plan.yaml --out=plan.drill
```

`--strict` nekter å bygge hvis det er advarsler.

**`decompile`** går andre veien og skriver ut kildedokumentet fra en ferdig `.drill`. Beste måten å lære formatet, og måten å ta opp igjen en plan du bare har som fil.

```
ringdrill decompile plan.drill
```

**`schema`** skriver ut JSON Schema for formatet. Pek editoren dit, så får du autofullføring og feilmarkering:

```
ringdrill schema > ringdrill.schema.json
```

## Katalogen

Disse tre bruker nett.

```
ringdrill feed
ringdrill download <slug>
ringdrill upload plan.drill
```

`feed` lister publiserte planer, `download` henter en som `.drill` (`--version=N` for eldre utgaver), og `upload` sender din. Opplasting publiserer ikke. Å legge en plan i den delte katalogen er et eget, bevisst steg, og det krever admin-token.

## Om navn

Aldri nummer i navnet. Appen setter nummer selv, så en post som heter `2a) Husundersøkelse` blir `2a) 2a) Husundersøkelse`. Nummeret kommer av rekkefølgen. [Planformatet](/docs/plan-format) har resten av reglene du bør kjenne før du skriver mye.
