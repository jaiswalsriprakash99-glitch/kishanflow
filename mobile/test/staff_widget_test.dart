import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kissanflow_mobile/l10n/app_localizations.dart';
import 'package:kissanflow_mobile/staff/staff_shell.dart';
import 'package:kissanflow_mobile/staff/staff_auth_screen.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('hi')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );
  }

  testWidgets('StaffAuthScreen renders login fields and credentials hint', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(StaffAuthScreen(onLoginSuccess: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Procurement Centre Terminal'), findsOneWidget);
    expect(find.byKey(const Key('staffUsernameInput')), findsOneWidget);
    expect(find.byKey(const Key('staffPasswordInput')), findsOneWidget);
    expect(find.byKey(const Key('staffLoginBtn')), findsOneWidget);
    expect(find.text('Mandya Staff (staff1)'), findsOneWidget);
  });

  testWidgets('StaffShell defaults to StaffAuthScreen when unauthenticated', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(const StaffShell()));
    await tester.pumpAndSettle();

    expect(find.text('LOGIN TO TERMINAL'), findsOneWidget);
  });
}
