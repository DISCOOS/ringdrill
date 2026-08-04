---
layout: ../../layouts/DocsLayout.astro
lang: nb
title: 'RingDrill: MCP for KI-assistenter'
description: 'Lag en øvelsesplan sammen med en KI-assistent. Hva serveren gjør med planen du sender inn, og hvordan du kobler til.'
canonicalPath: /docs/mcp
---

# MCP for KI-assistenter

RingDrill har et [MCP](https://modelcontextprotocol.io/)-endepunkt. Kobler du det til en KI-assistent, enten det er Claude, ChatGPT, Copilot eller noe annet som snakker MCP, kan assistenten lese den åpne plankatalogen, skrive en øvelsesplan sammen med deg, se etter feil i den, lage briefene, og gi deg tilbake `.drill`-fila du åpner i appen.

Det er tenkt til arbeidet i forkant: å gjøre et scenario du har i hodet, eller et øvelseshefte fra i fjor, om til en plan med runder, poster og briefer som hører sammen. Selve øvelsen kjører den ikke. Det er fortsatt appens jobb.

Ingen bruker, ingen innlogging. Adressen er:

```
https://api.ringdrill.app/mcp
```

## Hva skjer med planen du sender inn

Les dette før du limer inn noe. En øvelsesplan er ofte arbeidsmateriale til en reell aksjon, og dette er en server på internett, ikke et program på maskinen din.

**Som standard beholdes ingenting.** Serveren tar imot planen, bygger den, svarer, og glemmer den. Ingen database over planer, ingen logg over hva du sendte, og ingen måte å hente ut noe du sendte tidligere. Det er et krav til hvordan tjenesten er bygget, ikke en policy vi kan endre i stillhet. Det finnes ikke noe sted planen kan bli liggende.

To unntak, og begge bør du kjenne før du stoler på avsnittet over.

1. **Assistenten kan be serveren holde på et dokument, og da gjør den det.** Lange planer er tungt å sende om og om igjen, så et kall kan sette `cache: true`. Da ligger dokumentet i **30 minutter**, lagret under en sjekksum av innholdet sitt. Ellers er alt likt, men i de 30 minuttene kan hvem som helst som har sjekksummen hente dokumentet tilbake. Sjekksummen får du bare ved å ha hatt dokumentet selv, så dette er mindre et hull enn en kortvarig nøkkel du bør vite om.

2. **En plan serveren bygger for deg, ligger til du har lastet den ned.** Når assistenten bygger planen din, blir `.drill`-fila liggende i **30 minutter**, og du får en nedlastingslenke. Det er slik fila kommer fram til deg i det hele tatt, for en reell plan er for stor å sende gjennom et chatvindu. Med `inline: true` får du fila som tekst i svaret i stedet, og da beholdes ingenting.

Alt serveren leser fra katalogen er offentlig fra før, de samme planene du finner på [katalogsiden](/catalog). Upubliserte planer ser den ikke, og publisere kan den ikke. Å legge en plan i den delte katalogen er fortsatt noe et menneske gjør, bevisst, i appen.

## Er planen kun for stab

Da bruker du den lokale serveren, ikke denne.

Mange reelle planer er merket kun for stab, og at serveren er driftet av oss endrer ikke hva det betyr. Sender du en slik plan hit, forlater den maskinen din, behandles hos en leverandør og går over nett. Løftene over holder, og de er likevel ikke det samme som å aldri ha sendt den.

De samme verktøyene finnes i en server du kjører selv, lokalt, uten nett. Den krever utsjekket kode og Dart-verktøykjede, så den er mer å sette opp, og den er riktig svar når planen er sensitiv. Oppsettet står i [mcp/README.md](https://github.com/DISCOOS/ringdrill/blob/main/mcp/README.md).

Endepunktet vårt finnes for at folk uten verktøykjede skal kunne bruke dette i det hele tatt. Det er ikke anbefalt for sensitivt materiale, og med vilje ikke den eneste veien.

## Hva den kan gjøre

Sju verktøy. Assistenten velger mellom dem, det skal ikke du måtte.

- **`schema`** gir den presise formen på en planfil, så assistenten skriver noe som faktisk bygger.
- **`search_catalog`** lister publiserte planer i den åpne katalogen.
- **`get_plan`** henter en publisert plan som redigerbar fil, til å lese for omfang og tone, eller til å bygge videre på.
- **`create_plan`** setter opp et utgangspunkt som virker, i stedet for et blankt ark.
- **`analyze_plan`** går gjennom et utkast og sier hva som er feil eller mangler.
- **`render_plan`** lager briefen en deltaker, markør, veileder eller øvelsesleder får. Raskeste måten å se om planen holder.
- **`build_plan`** bygger `.drill`-fila du åpner i RingDrill.

Noe verktøy for å publisere finnes ikke, og det er med vilje.

## Grenser

Endepunktet er åpent, uten innlogging og gratis. Da trengs det noen kanter for at det skal fortsette å være det:

- **Rundt 60 verktøykall i minuttet** per bruker. Over det får du en HTTP 429 som sier hvor lenge du skal vente, og assistenten bør prøve igjen selv. Å koble til og liste verktøyene er gratis, så en klient kommer alltid fram til serveren, også midt i et utkast. Det er et omtrentlig tak, ikke en presis telling, og det er med vilje: den heller mot å slippe arbeidet ditt gjennom.
- **512 KB** per planfil, og **1 MB** per forespørsel.
- **10 sekunder** per bygging.

Grensen per minutt ligger godt over det en reell arbeidsøkt trenger: å sjekke, lage brief og bygge en plan er en håndfull kall per runde. Treffer du den mens du jobber med en vanlig plan, si fra. Da er innstillingen feil.

## Koble til

Alle klienter som tar en ekstern MCP-server, tar denne. Ingen kommando å kjøre, ingen sti å sette opp, bare adressen.

Claude Code:

```
claude mcp add --transport http ringdrill https://api.ringdrill.app/mcp
```

Claude Desktop, ChatGPT og Codex CLI tar adressen i sine egne innstillinger for tilkoblinger. I VS Code, `.vscode/mcp.json`:

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

Serveren forteller selv hvilke verktøy den har til den klienten som kobler seg til, så mer oppsett er det ikke. Be assistenten skrive en øvelsesplan, så finner den veien.

## Et forbehold om det assistenten skriver

En assistent er god på struktur og rask på tekst. Den kjenner ikke terrenget ditt, ikke lagene dine, og ikke hva som gikk skeis på forrige øvelse. Får den fritt spillerom, skriver den en postbeskrivelse som klinger godt og ikke er til å bruke.

Les gjennom det den lager, særlig det en deltaker skal handle på. `render_plan` er til nettopp dette: les briefen, ikke kildefila. Og hold virkelige folk utenfor planen. Navn på markører, kontakter og vaktpersonell hører ikke i et dokument som skrives ut og deles ut. Bruk en variabel til det som bestemmes på dagen.
