import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/core/theme/theme_provider.dart';
import 'package:gym_management_system/core/widgets/theme_toggle_button.dart';

void main() {
  group('ThemeToggleButton & ThemeProvider Test', () {
    testWidgets('Toggles theme mode from dark to light and vice versa', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ThemeToggleButton(showLabel: true),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // By default it starts in dark mode (Icons.light_mode_rounded is shown to prompt switching to light)
      expect(find.byType(ThemeToggleButton), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);

      // Tap toggle button to switch to Light mode
      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();

      // In Light mode, Icons.dark_mode_rounded is shown to prompt switching to dark
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

      // Tap again to switch back to Dark mode
      await tester.tap(find.byType(ThemeToggleButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    });
  });
}
