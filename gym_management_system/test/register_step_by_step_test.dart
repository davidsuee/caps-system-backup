import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/presentation/auth/screens/register_screen.dart';

void main() {
  group('RegisterScreen Multi-Step Wizard Flow', () {
    testWidgets('Step 1 -> Step 2 -> Step 3 navigation and validation flow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Step indicator and initial Step 1 render
      expect(find.text('STEP 1'), findsOneWidget);
      expect(find.text('STEP 2'), findsOneWidget);
      expect(find.text('STEP 3'), findsOneWidget);
      expect(find.text('Account Credentials'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Continue to Step 2: Biometrics & Goals'), findsOneWidget);

      // Try proceeding without entering details - should fail validation
      await tester.tap(find.text('Continue to Step 2: Biometrics & Goals'));
      await tester.pumpAndSettle();
      expect(find.text('Account Credentials'), findsOneWidget); // Still on Step 1

      // Enter valid account credentials
      await tester.enterText(find.widgetWithText(TextField, '').first, 'Juan Dela Cruz');
      // The text fields are: Full Name, Email, Password
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3));

      await tester.enterText(textFields.at(0), 'Juan Dela Cruz');
      await tester.enterText(textFields.at(1), 'juan@example.com');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.pumpAndSettle();

      // Click Continue to Step 2
      await tester.tap(find.text('Continue to Step 2: Biometrics & Goals'));
      await tester.pumpAndSettle();

      // Now we should be on Step 2
      expect(find.text('Biometrics & AI Training Profile'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Height (cm)'), findsOneWidget);
      expect(find.text('Weight (kg)'), findsOneWidget);
      expect(find.text('Continue to Membership'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);

      // Test Back button from Step 2 to Step 1 using ensureVisible
      await tester.ensureVisible(find.text('Back'));
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Account Credentials'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget); // Preserved

      // Go forward to Step 2 again
      await tester.ensureVisible(find.text('Continue to Step 2: Biometrics & Goals'));
      await tester.tap(find.text('Continue to Step 2: Biometrics & Goals'));
      await tester.pumpAndSettle();
      expect(find.text('Biometrics & AI Training Profile'), findsOneWidget);

      // Select Male gender
      await tester.ensureVisible(find.text('Male'));
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();

      // Fill Age, Height, Weight
      final biometricsFields = find.byType(TextField);
      await tester.ensureVisible(biometricsFields.at(0));
      await tester.enterText(biometricsFields.at(0), '25'); // Age
      await tester.ensureVisible(biometricsFields.at(1));
      await tester.enterText(biometricsFields.at(1), '175'); // Height
      await tester.ensureVisible(biometricsFields.at(2));
      await tester.enterText(biometricsFields.at(2), '70'); // Weight
      await tester.pumpAndSettle();

      // Verify Live BMI preview calculated
      expect(find.textContaining('Live Biometrics:'), findsOneWidget);
      expect(find.textContaining('BMI 22.9'), findsOneWidget);

      // Continue to Step 3
      await tester.ensureVisible(find.text('Continue to Membership'));
      await tester.tap(find.text('Continue to Membership'));
      await tester.pumpAndSettle();

      // Now we should be on Step 3
      // 'Register Account Only (No Plan)' is strictly removed; membership plan selection is required
      expect(find.text('Register Account Only (No Plan)'), findsNothing);
      expect(find.text('Monthly Basic'), findsOneWidget);
      // Walk-in day pass is strictly removed from registration (counter-only)
      expect(find.text('Day Pass'), findsNothing);
      expect(find.textContaining('1-Day Walk-In Pass'), findsOneWidget);

      // Select Monthly Basic plan
      await tester.ensureVisible(find.text('Monthly Basic'));
      await tester.tap(find.text('Monthly Basic'));
      await tester.pumpAndSettle();
      expect(find.text('SELECTED'), findsOneWidget);

      // Check summary card info
      await tester.ensureVisible(find.text('Registration Summary'));
      expect(find.text('Registration Summary'), findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsOneWidget); // In Summary card
      expect(find.text('juan@example.com'), findsOneWidget); // In Summary card

      // Verify the submit button reflects the plan selection
      await tester.ensureVisible(find.textContaining('Register & Request Monthly Basic'));
      expect(find.textContaining('Register & Request Monthly Basic'), findsOneWidget);
    });

    testWidgets('RegisterScreen pre-selects plan passed from welcome screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterScreen(
              selectedPlanName: 'Monthly Basic',
              selectedPlanPrice: 1200.0,
              selectedPlanDays: 30,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify pre-selected plan banner is displayed
      expect(find.textContaining('Selected Plan:'), findsOneWidget);
      expect(find.textContaining('Monthly Basic (₱1200)'), findsOneWidget);
    });
  });
}
