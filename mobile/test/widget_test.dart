import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kissanflow_mobile/app.dart';
import 'package:kissanflow_mobile/screens/role_selection_screen.dart';

void main() {
  testWidgets('App boots and language can be switched', (WidgetTester tester) async {
    // Build app with Hindi as initial locale
    await tester.pumpWidget(const KisanFlowApp(initialLocale: Locale('hi')));
    await tester.pump();

    // Verify initial splash screen renders KisanFlow
    expect(find.text('किसानफ़्लो'), findsOneWidget);

    // Fast-forward splash screen timer (2 seconds)
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Verify RoleSelectionScreen shows Hindi welcome message
    expect(find.text('किसानफ़्लो में आपका स्वागत है'), findsOneWidget);

    // Tap language switcher popup menu
    final langButton = find.byIcon(Icons.language);
    expect(langButton, findsOneWidget);
    await tester.tap(langButton);
    await tester.pumpAndSettle();

    // Select English from menu
    final englishOption = find.text('English');
    expect(englishOption, findsOneWidget);
    await tester.tap(englishOption);
    await tester.pumpAndSettle();

    // Verify language switched to English welcome text
    expect(find.text('Welcome to KisanFlow'), findsOneWidget);
  });
}
