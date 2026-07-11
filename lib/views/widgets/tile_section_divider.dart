import 'package:flutter/material.dart';

/// The one section-divider spacing every expandable browser tile (Poster,
/// Spill) uses between its own sections (DESIGN-010 follow-up "browser tile
/// polish"), so the divider above a section and the one below it always
/// carry identical padding — previously each call site mixed its own
/// `SizedBox` gap with the divider's own reserved height, so the two edges
/// of the same divider ended up with different effective spacing.
const double kTileSectionSpacing = 12;

/// A section divider for an expandable tile's body. Owns all of its own
/// spacing — callers place it directly between two sections with no
/// additional `SizedBox`, so every divider in every tile reads with the same
/// rhythm.
class TileSectionDivider extends StatelessWidget {
  const TileSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: kTileSectionSpacing),
      child: Divider(height: 1),
    );
  }
}
