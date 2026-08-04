---
layout: ../../layouts/DocsLayout.astro
lang: nb
title: 'RingDrill: Dokumentasjon'
description: 'Slik lager du en øvelsesplan i RingDrill: i appen, sammen med en KI-assistent, eller fra kommandolinja.'
canonicalPath: /docs
---

# Dokumentasjon

RingDrill kjører øvelser der lag rullerer mellom poster. Appen styrer gjennomføringen: rundetider, hvem som er hvor, og briefer til hver rolle. Sidene her handler om det som skjer i forkant, når planen skal lages.

Til de fleste øvelser holder appen. Sidene her er for dem den ikke holder til.

Noen planer blir store. Sju øvelser over en helg, førti poster, et scenario med steder og savnede, og briefer som skal si forskjellige ting til deltakere, markører og veiledere. Da er det mye å holde orden på i en app, og det er stoff du gjerne vil ha igjen til neste år.

## Planen som tekstfil

Bak redigeringen i appen ligger et tekstformat. Én YAML-fil beskriver hele planen, og kompilatoren lager `.drill`-fila appen åpner.

Fordelen er den samme som med all annen tekst. Planen kan ligge i versjonskontroll, så du ser hva som er endret siden i fjor. Du kan hente det som var bra fra en gammel plan uten å sette den opp på nytt. Du kan sende den til gjennomlesing før noen har låst noe. Og briefene til alle rollene lages fra samme kilde, så du slipper å oppdatere fire dokumenter hver gang noe endres.

Tre veier inn. Alle ender i samme `.drill`-fil, fra samme format:

- **[Planformatet](/docs/plan-format)** forklarer hvordan fila ser ut, og hvilke feil som er lette å gjøre. Les den først, også om du aldri skriver YAML selv.
- **[Kommandolinja](/docs/cli)** bygger, sjekker og lager briefer lokalt. For deg som er vant til terminal, og for alt som skal automatiseres.
- **[MCP for KI-assistenter](/docs/mcp)** lar deg lage planen i dialog med en assistent. Ingenting å installere. Men planen sendes til en server, og hva det innebærer bør du vite før du bruker den på noe som ikke skal ut.

## Ellers

- **[Katalogen](/catalog)** har publiserte planer du kan lese og låne fra. Begynn der. Å bygge på en plan som funker er lettere enn å starte tomt.
- **[HTTP-API-et](https://ringdrill.app/api/docs)** er det appen snakker med, hvis du skal integrere noe.
- **[Kildekoden på GitHub](https://github.com/DISCOOS/ringdrill)**. RingDrill er åpen kildekode. Arkitektur og beslutninger er dokumentert under `docs/`.
