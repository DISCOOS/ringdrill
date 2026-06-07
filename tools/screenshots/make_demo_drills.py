#!/usr/bin/env python3
"""Generate two demo `.drill` plans for store screenshots.

One plan has Norwegian content, the other English. The plan only carries
the *content* language (station, team and exercise names). The app's UI
chrome follows the device locale, so capture the Norwegian plan on a
simulator set to `nb` and the English plan on one set to `en` (see
tools/screenshots.sh and the README in this folder).

Run:
    python3 tools/screenshots/make_demo_drills.py

Outputs (next to this script):
    demo-no.drill
    demo-en.drill

The `.drill` format is a zip: metadata.json, program.json,
exercises/<uuid>.json, teams/<uuid>.json. Schedule rows are
[start, start+execution, start+execution+evaluation] per round, and
endTime = start + rounds * (execution + evaluation + rotation).
"""

import json
import os
import random
import string
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
CREATED = "2026-01-15T09:00:00+00:00"
META = {"created": CREATED, "updated": CREATED, "version": "1.0"}

# RingDrill ids are nanoid(10) over the URL-safe alphabet (see program_repository.dart).
# Use a fixed seed so regenerating the demo files is deterministic (no git churn)
# while the ids still look like real RingDrill ids.
_NANOID_ALPHABET = string.ascii_letters + string.digits + "_-"
_rng = random.Random(20260115)


def nid():
    return "".join(_rng.choice(_NANOID_ALPHABET) for _ in range(10))


def tod(total_min):
    """Minutes-since-midnight -> {hour, minute} (wraps past midnight)."""
    return {"hour": (total_min // 60) % 24, "minute": total_min % 60}


def station(index, name, lng, lat, description):
    pos = {"coordinates": [lng, lat]} if lng is not None else None
    return {"index": index, "name": name, "position": pos, "description": description}


def exercise(uuid, name, start_h, start_m, teams, rounds, execm, evalm, rotm, stations):
    start = start_h * 60 + start_m
    cycle = execm + evalm + rotm
    schedule = []
    for i in range(rounds):
        rs = start + i * cycle
        schedule.append([tod(rs), tod(rs + execm), tod(rs + execm + evalm)])
    return {
        "uuid": uuid,
        "name": name,
        "startTime": tod(start),
        "numberOfTeams": teams,
        "numberOfRounds": rounds,
        "executionTime": execm,
        "evaluationTime": evalm,
        "rotationTime": rotm,
        "stations": stations,
        "schedule": schedule,
        "endTime": tod(start + rounds * cycle),
        "metadata": None,
    }


def build(filename, prog_uuid, prog_name, prog_desc, team_names, exercises):
    teams = [
        {"uuid": uuid, "index": i, "name": nm, "numberOfMembers": None, "position": None}
        for i, (uuid, nm) in enumerate(team_names)
    ]
    program = {
        "uuid": prog_uuid,
        "name": prog_name,
        "description": prog_desc,
        "metadata": META,
        "source": {"runtimeType": "local"},
        "contentHash": None,
        "teams": [],
        "sessions": [],
        "exercises": [],
    }
    path = os.path.join(HERE, filename)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("metadata.json", json.dumps(META))
        z.writestr("program.json", json.dumps(program))
        for ex in exercises:
            z.writestr("exercises/%s.json" % ex["uuid"], json.dumps(ex))
        for t in teams:
            z.writestr("teams/%s.json" % t["uuid"], json.dumps(t))
    print("wrote", path)


# Stations cluster around Tjøme/Eidene (with a couple further out toward
# Verdens Ende and Kikut) so the map view looks populated and varied.
# Modeled on test/fixtures/test-7x.drill, with search methods and terminology
# from the Hovedredningssentralen guide "Søk etter savnet på land" (2022):
# grovsøk/finsøk, sannsynlighetsringer (R25/R50/R75) rundt IPP, sykkelhjul-
# modellen, ledelinjesøk, søkekjede, sperrepost, areal and ILKO.

# --- Norwegian content ---
NO_E1 = [  # ring, førsteinnsats etter sykkelhjulmodellen, 4 stations
    station(0, "Sporutgang fra IPP", 10.4019, 59.0999, "Hundeekvipasje tar sporutgang fra IPP. Grovsøk langs ferskeste spor."),
    station(1, "Nærområdesøk", 10.4043, 59.0981, "Raskt nærområdesøk rundt IPP innenfor R25. Grovsøk, prioriter hurtighet."),
    station(2, "Søk langs ledelinje", 10.4043, 59.0988, "1–3 personer langs sti mot R50. Høy POD. Meld funn og POI på samband."),
    station(3, "Sperrepost ved knutepunkt", 10.4038, 59.0998, "Områdebegrensning: hindre at savnede passerer veikrysset."),
]
NO_E2 = [  # ringøvelse: søk langs linjer, 6 stations
    station(0, "Ledelinjesøk langs sti", 10.4012, 59.0995, "1–2 personer langs sti mot R50. Svært høy POD. Meld funn på samband."),
    station(1, "Ledelinjesøk langs vei", 10.4031, 59.0972, "Følg skogsbilvei ut fra IPP. Jevn fart, dekk begge sider."),
    station(2, "Punktsøk POI", 10.4156, 59.0724, "Sjekk POI langs ledelinjene – refleksene i sykkelhjulmodellen."),
    station(3, "Ledelinjesøk med flanke", 10.3963, 59.1226, "Følg bekkeløpet og dekk flanken der savnede kan ligge i tilknytning."),
    station(4, "Søk langs naturlige veivalg", 10.4044, 59.0992, "Følg der savnede naturlig ville beveget seg fra IPP."),
    station(5, "Sporsøk langs ledelinje", 10.4007, 59.0985, "Hundeekvipasje følger spor langs ledelinje. Grovsøk."),
]
NO_E3 = [  # fullskala: søk i areal (høy funnsannsynlighet), 3 stations
    station(0, "Søkekjede i areal", 10.3941, 59.1288, "Manngard med jevn avstand. Grovsøk hele arealet, godta små hull."),
    station(1, "Finsøk i areal", 10.3944, 59.1290, "Strengt systematisk finsøk der R25 < 300 m. Dekk alle deler av arealet."),
    station(2, "Hussøk", 10.3970, 59.1270, "Finsøk i bygning: strengt systematisk, ovenfra-og-ned, innenfra-og-ut."),
]
NO_E4 = [  # full-scale, henteoppdrag, 2 stations
    station(0, "Skadet turgåer", 10.4158, 59.0722, "Stabiliser og uttransport med hjulbåre til ILKO."),
    station(1, "Nedkjølt padler", 10.3967, 59.0665, "Varmebevarende tiltak. Klargjør for ambulanse ved oppmøteplass."),
]
NO_E5 = [  # final exercise, sporsøk til funn, 3 stations
    station(0, "Sporutgang og funn", 10.4004, 59.1363, "Hundeekvipasje finner spor og leder laget mot funnsted."),
    station(1, "Båretransport", 10.4002, 59.1360, "Uttransport av savnet til oppmøteplass for ambulanse."),
    station(2, "ILKO / Søksplanlegger", 10.4046, 59.0989, "Arealinndeling, oppdrag og søksrapport. Ressursstyrer fører logg."),
]

# --- English content (mirrors the Norwegian stations) ---
EN_E1 = [
    station(0, "Track start from IPP", 10.4019, 59.0999, "Dog team takes the track start from the IPP. Hasty search along the freshest track."),
    station(1, "Hasty area search", 10.4043, 59.0981, "Quick hasty search around the IPP within the 25% ring. Prioritize speed."),
    station(2, "Linear feature search", 10.4043, 59.0988, "1–3 searchers along the trail toward the 50% ring. High detection probability; report finds and POIs by radio."),
    station(3, "Containment point", 10.4038, 59.0998, "Area containment: stop the missing person from passing the road junction."),
]
EN_E2 = [
    station(0, "Leading-line search (trail)", 10.4012, 59.0995, "1–2 searchers along the trail toward the 50% ring. Very high detection probability."),
    station(1, "Leading-line search (road)", 10.4031, 59.0972, "Follow the forest road out from the IPP, covering both sides."),
    station(2, "Point search (POI)", 10.4156, 59.0724, "Check the POIs along the leading lines – the spokes-and-hub model's points of interest."),
    station(3, "Linear search with flank", 10.3963, 59.1226, "Follow the stream and cover the flank where the person may lie nearby."),
    station(4, "Natural travel routes", 10.4044, 59.0992, "Search where the missing person would naturally have moved from the IPP."),
    station(5, "Dog track along leading line", 10.4007, 59.0985, "Dog team follows the track along the leading line. Hasty search."),
]
EN_E3 = [
    station(0, "Line-abreast area sweep", 10.3941, 59.1288, "Line abreast at even spacing. Hasty sweep of the whole area; small gaps acceptable."),
    station(1, "Fine area search", 10.3944, 59.1290, "Strictly systematic fine search where the 25% ring is under 300 m. Cover every part of the area."),
    station(2, "Building search", 10.3970, 59.1270, "Fine search of a building: strictly systematic, top-down, inside-out."),
]
EN_E4 = [
    station(0, "Injured hiker", 10.4158, 59.0722, "Stabilize and evacuate by wheeled stretcher to the command post."),
    station(1, "Hypothermic paddler", 10.3967, 59.0665, "Apply warming measures. Prepare for ambulance handover at the rendezvous."),
]
EN_E5 = [
    station(0, "Track start to find", 10.4004, 59.1363, "Dog team picks up the track and leads the team to the find site."),
    station(1, "Stretcher carry-out", 10.4002, 59.1360, "Evacuate the casualty to the ambulance rendezvous."),
    station(2, "Command post / planner", 10.4046, 59.0989, "Area division, tasking and search report. The resource manager keeps the log."),
]


def main():
    build(
        "demo-no.drill",
        nid(),
        "Søk og redning – Øvingshelg",
        "Øvingshelg for søk etter savnet på land med fire lag. Progresjonen går fra førsteinnsats og søksmetoder i ringøvelser til fullskala oppdrag og en avsluttende, integrert øvelse. Bygger på Hovedredningssentralens veileder «Søk etter savnet på land».",
        [(nid(), "Lag 1"), (nid(), "Lag 2"), (nid(), "Lag 3"), (nid(), "Lag 4")],
        [
            # Ordered so competence builds up: ring drills teach methods, the
            # full-scale tasks apply them, and the final exercise integrates all.
            exercise(nid(), "Førsteinnsats søk (ringøvelse)", 9, 0, 4, 4, 20, 10, 5, NO_E1),
            exercise(nid(), "Søk langs linjer (ringøvelse)", 11, 30, 4, 6, 15, 10, 5, NO_E2),
            exercise(nid(), "Søk i areal (fullskala)", 15, 0, 1, 1, 90, 0, 0, NO_E3),
            exercise(nid(), "Henteoppdrag (fullskala)", 17, 0, 2, 2, 60, 15, 5, NO_E4),
            exercise(nid(), "Avsluttende øvelse (fullskala)", 20, 0, 1, 3, 45, 10, 5, NO_E5),
        ],
    )
    build(
        "demo-en.drill",
        nid(),
        "SAR – Training Weekend",
        "A weekend of land search-and-rescue training for four teams. The plan builds from initial response and search methods in ring drills to full-scale tasks and a final, integrated exercise. Based on the Norwegian HRS guide for searching for missing persons on land.",
        [(nid(), "Team 1"), (nid(), "Team 2"), (nid(), "Team 3"), (nid(), "Team 4")],
        [
            # Ordered so competence builds up: ring drills teach methods, the
            # full-scale tasks apply them, and the final exercise integrates all.
            exercise(nid(), "Initial search response (ring drill)", 9, 0, 4, 4, 20, 10, 5, EN_E1),
            exercise(nid(), "Linear search (ring drill)", 11, 30, 4, 6, 15, 10, 5, EN_E2),
            exercise(nid(), "Area search (full-scale)", 15, 0, 1, 1, 90, 0, 0, EN_E3),
            exercise(nid(), "Casualty pickup (full-scale)", 17, 0, 2, 2, 60, 15, 5, EN_E4),
            exercise(nid(), "Final exercise (full-scale)", 20, 0, 1, 3, 45, 10, 5, EN_E5),
        ],
    )


if __name__ == "__main__":
    main()
