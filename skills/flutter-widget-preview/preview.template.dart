// TEMPLATE — copy to test/preview/_preview.dart, fill in, then run:
//   flutter test test/preview/_preview.dart --update-goldens
// PNGs land in test/preview/output/<name>.png — open them to review.
//
// test/preview/ is gitignored: the copy is throwaway. Delete it when done.
// The `../../test/support/...` import resolves both here
// (skills/flutter-widget-preview/) and after copying (test/preview/), so no
// edit is needed after `cp`. See skills/flutter-widget-preview/SKILL.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/widget_preview_harness.dart';

// Import the widget(s) under review, e.g.:
// import 'package:ringdrill/views/shell/wide_shell.dart';

void main() {
  testWidgets('preview: my_widget (light)', (tester) async {
    await renderPreview(
      tester,
      name: 'my_widget_light',
      size: const Size(400, 800),
      brightness: Brightness.light,
      locale: const Locale('nb'),
      child: const Placeholder(), // <-- replace with the widget to preview
    );
  });

  testWidgets('preview: my_widget (dark)', (tester) async {
    await renderPreview(
      tester,
      name: 'my_widget_dark',
      size: const Size(400, 800),
      brightness: Brightness.dark,
      locale: const Locale('nb'),
      child: const Placeholder(), // <-- same widget, dark theme
    );
  });
}
