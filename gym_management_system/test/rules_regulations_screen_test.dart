import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/presentation/landing/screens/rules_regulations_screen.dart';

void main() {
  testWidgets('RulesRegulationsScreen renders all 10 rules and branding on desktop and mobile', (tester) async {
    // 1. Desktop Test (1200x900)
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RulesRegulationsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Verify Title & Subtitles
    expect(find.text('GYM RULES AND REGULATIONS'), findsOneWidget);
    expect(find.text('VICIOUS GAINS HYBRID GYM'), findsOneWidget);

    // Verify all 10 Rules titles
    expect(find.text('1. GENERAL CONDUCT'), findsOneWidget);
    expect(find.text('2. ATTIRE & HYGIENE'), findsOneWidget);
    expect(find.text('3. EQUIPMENT USE & SAFETY'), findsOneWidget);
    expect(find.text('4. RESTRICTIONS'), findsOneWidget);
    expect(find.text('5. BAGS & PERSONAL BELONGINGS'), findsOneWidget);
    expect(find.text('6. TIME & SPACE ETIQUETTE'), findsOneWidget);
    expect(find.text('7. COMBAT SPORTS AREA'), findsOneWidget);
    expect(find.text('8. CLEANLINESS'), findsOneWidget);
    expect(find.text('9. MEMBERSHIP & ACCESS'), findsOneWidget);
    expect(find.text('10. RESPECT THE SPACE'), findsOneWidget);

    // Verify specific bullet points
    expect(find.text('RESPECT EVERYONE. NO HARASSMENT, DISCRIMINATION, OR AGGRESSIVE BEHAVIOR.'), findsOneWidget);
    expect(find.text('TRAIN HARD—BUT TRAIN RESPONSIBLY.'), findsOneWidget);

    // 2. Mobile Test (400x800)
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RulesRegulationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
