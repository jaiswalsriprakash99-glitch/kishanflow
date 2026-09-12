import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kissanflow_mobile/pacs/pacs_shell.dart';
import 'package:kissanflow_mobile/pacs/pacs_auth_screen.dart';
import 'package:kissanflow_mobile/l10n/app_localizations.dart';

void main() {
  testWidgets('PACS Shell renders Auth screen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PacsShell(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PacsAuthScreen), findsOneWidget);
    expect(find.text('PACS Operator Login'), findsOneWidget);
    expect(find.byKey(const Key('pacsUsernameField')), findsOneWidget);
    expect(find.byKey(const Key('pacsPasswordField')), findsOneWidget);
    expect(find.byKey(const Key('pacsLoginBtn')), findsOneWidget);
  });
}
