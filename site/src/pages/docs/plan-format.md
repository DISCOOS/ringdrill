---
layout: ../../layouts/DocsLayout.astro
lang: nb
title: 'RingDrill: Planformatet'
description: 'En øvelsesplan kan skrives som én YAML-fil og bygges til en .drill-fil. Hva fila inneholder, og hvilke feil som er lette å gjøre.'
canonicalPath: /docs/plan-format
---

# Planformatet

En plan kan skrives som én YAML-fil og bygges til `.drill`-fila appen åpner. Fila er **kildedokumentet**, altså den du redigerer, tar vare på og sender til gjennomlesing. `.drill`-fila er resultatet.

Her står formen og reglene, ikke feltlista. Feltlista lages automatisk fra den samme tabellen kompilatoren selv bruker, så en kopi på denne siden ville vært utdatert etter første endring. Hent den gjeldende med `ringdrill schema`, eller be assistenten om `schema`-verktøyet. Du får JSON Schema tilbake, og de fleste editorer bruker den til autofullføring og feilmarkering mens du skriver.

## Slik henger det sammen

Omtrent som øvelsen selv.

Planen har navn, språk og en liste med øvelser. Hver øvelse har rundelengde, poster og antall lag. Resten regner kompilatoren ut: hvilket lag som står på hvilken post i hvilken runde, og når rundene starter. Tidsplanen skriver du ikke selv.

Oppå dette ligger scenarioet, det som skiller en øvelse fra en timeplan. Steder plasserer postene i terrenget, med UTM. Personer er de oppdiktede folkene i scenarioet, for eksempel en savnet turgåer. Rollespill sier hvordan markøren skal spille en av dem. Variabler holder det som bestemmes på dagen: vaktnummer, talegruppe, KO.

Briefene lages fra samme kilde til hver mottaker, fra deltaker til øvelsesleder. Deltakerbriefen får ikke med seg de stabsinterne feltene.

## Feil som er lette å gjøre

Disse gir en plan som bygger uten feilmelding, men som likevel ikke stemmer.

**Nummereringen kommer av rekkefølgen.** Appen setter post- og øvelsesnummer selv. Skriver du `2a)` eller `#3` i navnet, kommer det to ganger: `2a) 2a) Husundersøkelse`. Navnet skal si hva posten er, ikke hvor den står i rekka.

**Utregnede felter skal ikke inn i fila.** Tidsplan, sluttider, indekser, uuid-er og innholdssum regnes ut. Skjemaet har dem ikke, og skriver du dem inn blir de ignorert.

**Tokens er tekst, ikke noe du skal fylle ut.** Skriv `{{var.vaktnummer}}` og `{{station.loc.lkp.utm}}` som de står. De erstattes når briefen lages, og det er poenget: endre variabelen én gang, så er alle briefene oppdatert.

**Tre felter blir etterspurt ved navn.** `method` på øvelsen, `description` på posten og `description` på rollespillet. Disse glemmes lettest, for et øvelseshefte har ingen overskrift som svarer til dem. Heftet gir deg scenarioet og rekkefølgen, og de hører i `situation` og `mission`. En post uten beskrivelse viser *Mangler: Postbeskrivelse* i kortet sitt til noen fyller den ut.

Og `description` er ikke `situation` om igjen. Beskrivelsen er posten slik staben snakker om den: «husundersøkelse etter savnet kvinne med demens». Situasjonen er det laget møter når de kommer fram. Blir de like, kutt beskrivelsen ned til den ene setningen som skiller posten fra den forrige.

**Ingen virkelige navn.** `persons` er oppdiktede. Markørlister og navngitte kontakter hører ikke i planen, så skriv rollen i stedet for navnet. Operative *verdier* er en annen sak og hører absolutt hjemme: vaktnummer, KO-nummer, talegruppe. Legg dem inn som variabel og skriv tokenet, aldri verdien rett i teksten. Slike verdier bestemmes sent og endres på dagen, og det er nettopp derfor variabler finnes.

Husk også at ingenting i markdown-feltene fjernes ved publisering. Veiledernotater, markørinstrukser og stabsinterne beskrivelser blir med i fila.

## Lær formatet fra en plan som virker

Raskeste vei er ikke å lese denne siden. Hent en publisert plan fra [katalogen](/catalog) og pakk den ut:

```
ringdrill download <slug>
ringdrill decompile <slug>.drill
```

Da får du kildedokumentet til en plan som er i bruk, i det samme formatet du selv ville skrevet, uten de utregnede feltene. Les det for omfang og tone: hvor mye en post faktisk rommer, og hvor lang en brief blir.

Vær litt mer varsom med å lese det som mønster. Katalogen er felles, og en publisert plan kan være eldre enn formatet. Den kan godt ha flate beskrivelser, verdier som burde vært variabler, eller nummer skrevet inn i navnet. `ringdrill analyze` sier hvilke.

Rundturen er til å stole på der det gjelder: bygger du opp igjen en plan du har pakket ut, får du samme innholdssum. Å pakke ut en plan for å se på den endrer den ikke.
