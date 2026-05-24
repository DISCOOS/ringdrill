import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/actor.dart';
import 'package:ringdrill/views/actor_form_screen.dart';

Widget _buildForm({Actor? actor}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ActorFormScreen(actor: actor),
  );
}

const _existingActor = Actor(
  uuid: 'actor-1',
  realName: 'Kari Nordmann',
  phone: '12345678',
);

void main() {
  testWidgets('real name is required', (tester) async {
    await tester.pumpWidget(_buildForm());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text(l10n.save));
    await tester.pump();

    expect(find.text(l10n.pleaseEnterAName), findsOneWidget);
  });

  testWidgets('existing actor values are pre-filled', (tester) async {
    await tester.pumpWidget(_buildForm(actor: _existingActor));
    await tester.pump();

    expect(find.text('Kari Nordmann'), findsWidgets);
    expect(find.text('12345678'), findsWidgets);
  });

  testWidgets('save pops with new actor containing entered name', (
    tester,
  ) async {
    Actor? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await Navigator.push<Actor>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => const ActorFormScreen(),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byWidgetPredicate(
        (w) => w is EditableText && w.controller.text == '',
      ).first,
      'Ole Hansen',
    );

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(result?.realName, 'Ole Hansen');
    expect(result?.uuid, isNotNull);
  });

  testWidgets('save pops with updated actor preserving uuid', (tester) async {
    Actor? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await Navigator.push<Actor>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => ActorFormScreen(actor: _existingActor),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final nameField = find.widgetWithText(TextFormField, 'Kari Nordmann');
    await tester.enterText(nameField, 'Kari Hansen');

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(result?.realName, 'Kari Hansen');
    expect(result?.uuid, _existingActor.uuid);
  });
}
