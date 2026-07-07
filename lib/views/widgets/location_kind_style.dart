import 'package:flutter/material.dart';
import 'package:ringdrill/models/location.dart';

/// Minimal per-[LocationKind] map-marker styling (ADR-0020, DESIGN-009): a
/// distinct glyph and tone so a location marker reads differently, at a
/// glance, from the administrative `Station.position` marker (always
/// `Icons.place` in green) and from other kinds. Deliberately coarse — a
/// fuller, kind-specific icon set can follow.
extension LocationKindStyleX on LocationKind {
  IconData get icon => switch (this) {
    LocationKind.lkp => Icons.person_pin_circle,
    LocationKind.ipp => Icons.flag,
    LocationKind.pp => Icons.outlined_flag,
    LocationKind.rendezvous => Icons.groups,
    LocationKind.commandPost => Icons.local_police,
    LocationKind.home => Icons.home,
    LocationKind.trackFound => Icons.directions_walk,
    LocationKind.dogInterest => Icons.pets,
    LocationKind.obstacle => Icons.report_problem,
    LocationKind.notSearchable => Icons.block,
    LocationKind.phoneTrace => Icons.smartphone,
    LocationKind.observation => Icons.visibility,
    LocationKind.vantagePoint => Icons.terrain,
    LocationKind.containmentPost => Icons.security,
    LocationKind.personFound => Icons.emoji_people,
    LocationKind.other => Icons.place_outlined,
  };

  Color get color => switch (this) {
    LocationKind.lkp => Colors.red,
    LocationKind.ipp => Colors.blue,
    LocationKind.pp => Colors.lightBlue,
    LocationKind.rendezvous => Colors.teal,
    LocationKind.commandPost => Colors.indigo,
    LocationKind.home => Colors.brown,
    LocationKind.trackFound => Colors.orange,
    LocationKind.dogInterest => Colors.deepOrange,
    LocationKind.obstacle => Colors.amber,
    LocationKind.notSearchable => Colors.grey,
    LocationKind.phoneTrace => Colors.purple,
    LocationKind.observation => Colors.cyan,
    LocationKind.vantagePoint => Colors.lightGreen,
    LocationKind.containmentPost => Colors.deepPurple,
    LocationKind.personFound => Colors.pink,
    LocationKind.other => Colors.blueGrey,
  };
}
