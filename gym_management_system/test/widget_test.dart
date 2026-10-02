import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/app.dart';
import 'package:gym_management_system/routing/app_router.dart';

void main() {
  setUp(() {
    resetInitialLaunchForTest();
  });

  testWidgets('Vicious Login Screen - Typing, clear icon, and no demo chips test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: ViciousApp(),
      ),
    );

    await tester.pumpAndSettle();

    // If initial location is WelcomeScreen, tap Portal Login to enter LoginScreen
    final portalLoginBtn = find.text('Portal Login');
    if (portalLoginBtn.evaluate().isNotEmpty) {
      await tester.tap(portalLoginBtn);
      await tester.pumpAndSettle();
    }

    // 1. Verify header renders and demo role chips are REMOVED
    expect(find.text('VICIOUS'), findsOneWidget);
    expect(find.text('Sign In'), findsNWidgets(2)); // Title and Button
    expect(find.text('Demo Accounts (Auto-fill by Role):'), findsNothing);
    expect(find.text('Member'), findsNothing);
    expect(find.text('Coach'), findsNothing);
    expect(find.text('Admin'), findsNothing);

    // 2. Verify textfields start empty and accept typing
    final textFields = find.byType(TextFormField);
    expect(textFields, findsNWidgets(2));

    // Type email
    await tester.enterText(textFields.first, 'user@test.com');
    await tester.pumpAndSettle();
    expect(find.text('user@test.com'), findsOneWidget);

    // Clear icon appears and clears field
    final clearIcon = find.byIcon(Icons.clear);
    expect(clearIcon, findsOneWidget);
    await tester.tap(clearIcon);
    await tester.pumpAndSettle();
    expect(find.text('user@test.com'), findsNothing);

    // Type again in email & password
    await tester.enterText(textFields.first, 'realmember@test.com');
    await tester.enterText(textFields.last, 'password123');
    await tester.pumpAndSettle();

    expect(find.text('realmember@test.com'), findsOneWidget);
    expect(find.text('password123'), findsOneWidget);

    // Toggle password visibility
    final visibilityBtn = find.byIcon(Icons.visibility_off_outlined);
    expect(visibilityBtn, findsOneWidget);
    await tester.tap(visibilityBtn);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });
}
