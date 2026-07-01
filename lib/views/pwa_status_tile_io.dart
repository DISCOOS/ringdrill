import 'package:flutter/material.dart';

/// Native stub: PWA install status does not apply off the web, so render
/// nothing. Keeps the conditional import in `about_page.dart` compiling.
class PwaStatusTile extends StatelessWidget {
  const PwaStatusTile({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
