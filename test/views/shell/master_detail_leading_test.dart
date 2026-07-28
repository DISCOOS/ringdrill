import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/views/shell/master_detail_leading.dart';
import 'package:ringdrill/views/shell/master_detail_scope.dart';
import 'package:ringdrill/views/widgets/context_sheet.dart';

Widget _harness({
  VoidCallback? onToggleMaster,
  required VoidCallback onClose,
  bool withScope = true,
}) {
  final leading = Scaffold(body: MasterDetailLeading(onClose: onClose));
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: withScope
        ? MasterDetailScope(
            target: ValueNotifier<ContextSheetTarget?>(null),
            emptyPaneBuilder: (_) => const SizedBox.shrink(),
            onToggleMaster: onToggleMaster,
            child: leading,
          )
        : leading,
  );
}

void main() {
  testWidgets(
    'renders the sidebar toggle under a MasterDetailScope with onToggleMaster',
    (tester) async {
      var toggled = false;
      var closed = false;
      await tester.pumpWidget(
        _harness(
          onToggleMaster: () => toggled = true,
          onClose: () => closed = true,
        ),
      );

      expect(find.byIcon(CupertinoIcons.sidebar_left), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.byIcon(CupertinoIcons.sidebar_left));
      expect(toggled, isTrue);
      expect(closed, isFalse);
    },
  );

  testWidgets('renders the close-X with no MasterDetailScope in context', (
    tester,
  ) async {
    var closed = false;
    await tester.pumpWidget(
      _harness(withScope: false, onClose: () => closed = true),
    );

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.sidebar_left), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    expect(closed, isTrue);
  });

  testWidgets(
    'renders the close-X under a MasterDetailScope with no onToggleMaster',
    (tester) async {
      var closed = false;
      await tester.pumpWidget(_harness(onClose: () => closed = true));

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.sidebar_left), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, isTrue);
    },
  );
}
