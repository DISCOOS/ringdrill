import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/l10n/app_localizations.dart';
import 'package:ringdrill/models/staff.dart';
import 'package:ringdrill/views/staff_form_screen.dart';

Widget _buildForm({Staff? actor}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: StaffFormScreen(staff: actor),
  );
}

const _existingActor = Staff(
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
    StaffFormResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await Navigator.push<StaffFormResult>(
                ctx,
                MaterialPageRoute(builder: (_) => const StaffFormScreen()),
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
      find
          .byWidgetPredicate(
            (w) => w is EditableText && w.controller.text == '',
          )
          .first,
      'Ole Hansen',
    );

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(
      result,
      isA<StaffFormSave>()
          .having((result) => result.staff.realName, 'realName', 'Ole Hansen')
          .having((result) => result.staff.uuid, 'uuid', isNotNull),
    );
  });

  testWidgets('save pops with updated actor preserving uuid', (tester) async {
    StaffFormResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await Navigator.push<StaffFormResult>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => StaffFormScreen(staff: _existingActor),
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

    expect(
      result,
      isA<StaffFormSave>()
          .having((result) => result.staff.realName, 'realName', 'Kari Hansen')
          .having((result) => result.staff.uuid, 'uuid', _existingActor.uuid),
    );
  });

  testWidgets('delete action is hidden for new actors', (tester) async {
    await tester.pumpWidget(_buildForm());
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.byTooltip(l10n.deleteStaff), findsNothing);
  });

  testWidgets('delete confirmation can be cancelled', (tester) async {
    StaffFormResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await Navigator.push<StaffFormResult>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => StaffFormScreen(staff: _existingActor),
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

    await tester.tap(find.byTooltip(l10n.deleteStaff));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.confirmDeleteActor(_existingActor.realName)),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.byType(StaffFormScreen), findsOneWidget);
  });

  testWidgets('delete confirmation pops with delete result', (tester) async {
    StaffFormResult? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              result = await Navigator.push<StaffFormResult>(
                ctx,
                MaterialPageRoute(
                  builder: (_) => StaffFormScreen(staff: _existingActor),
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

    await tester.tap(find.byTooltip(l10n.deleteStaff));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.delete));
    await tester.pumpAndSettle();

    expect(
      result,
      isA<StaffFormDelete>().having(
        (result) => result.staff.uuid,
        'uuid',
        _existingActor.uuid,
      ),
    );
  });
}
