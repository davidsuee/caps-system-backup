import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/repositories/facility_repository_impl.dart';
import 'package:gym_management_system/presentation/admin/providers/facility_provider.dart';
import 'package:gym_management_system/presentation/landing/screens/welcome_screen.dart';
import 'package:gym_management_system/presentation/admin/screens/ai_benchmark_screen.dart';

void main() {
  group('Phase 4: Welcome / Landing Page (Figure 4.1) & AI ISO 25010 Benchmark', () {
    late LocalCacheService localCache;
    late FacilityRepositoryImpl facilityRepo;

    setUp(() {
      localCache = LocalCacheService();
      facilityRepo = FacilityRepositoryImpl(localCache: localCache);
    });

    testWidgets('WelcomeScreen renders Viscious Fitness branding, amenities, and plans', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            facilityRepositoryProvider.overrideWithValue(facilityRepo),
          ],
          child: const MaterialApp(
            home: WelcomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header branding
      expect(find.text('VISCIOUS'), findsOneWidget);
      expect(find.text('FITNESS'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      // Verify Hero Section
      expect(find.textContaining('Unleash Your Ultimate Potential'), findsOneWidget);
      expect(find.text('Join Viscious Now'), findsOneWidget);
      expect(find.text('Portal Login'), findsOneWidget);

      // Verify Smart Gym Tech Highlights
      expect(find.text('ML Workout Recommender'), findsOneWidget);
      expect(find.text('LP Meal Plan Optimizer'), findsOneWidget);
      expect(find.text('Automated Coach Balancing'), findsOneWidget);
      expect(find.text('Digital Attendance & Out'), findsOneWidget);

      // Verify Amenities & Live Zones
      expect(find.text('Cardio Deck'), findsOneWidget);
      expect(find.text('Free Weights Area'), findsOneWidget);

      // Verify Membership Tiers
      expect(find.text('Monthly Basic'), findsOneWidget);
      expect(find.text('Quarterly Pro'), findsOneWidget);
      expect(find.text('Annual VIP'), findsOneWidget);

      // Verify Footer
      expect(find.textContaining('Global Reciprocal Colleges'), findsOneWidget);
    });

    testWidgets('AiBenchmarkScreen renders ISO 25010 metrics and runs live benchmark', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AiBenchmarkScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify App Bar & Tabs
      expect(find.text('AI & ISO 25010 Benchmark'), findsOneWidget);
      expect(find.text('ISO/IEC 25010 Quality'), findsOneWidget);
      expect(find.text('AI Models & Solvers'), findsOneWidget);

      // Verify ISO 25010 Criteria Scores
      expect(find.text('ISO/IEC 25010 Grand Mean'), findsOneWidget);
      expect(find.text('4.86 / 5.00'), findsOneWidget);
      expect(find.textContaining('STRONGLY ACCEPTABLE / EXCELLENT'), findsOneWidget);
      expect(find.text('1. Functional Suitability'), findsOneWidget);
      expect(find.text('2. Performance Efficiency'), findsOneWidget);
      expect(find.text('3. Usability & UX'), findsOneWidget);

      // Switch to AI Models & Solvers tab
      await tester.tap(find.text('AI Models & Solvers'));
      await tester.pumpAndSettle();

      // Verify Models Metrics
      expect(find.text('1. Workout Recommendation Engine (ML)'), findsOneWidget);
      expect(find.text('94.2% ACCURACY'), findsOneWidget);
      expect(find.text('2. Nutrition Recommendation Engine (Optimization)'), findsOneWidget);
      expect(find.text('99.1% FEASIBILITY'), findsOneWidget);
      expect(find.text('3. Trainer Assignment Balancer (Objective 4)'), findsOneWidget);

      // Trigger live benchmark test
      expect(find.text('⚡ Test Now'), findsOneWidget);
      await tester.tap(find.text('⚡ Test Now'));
      await tester.pump(); // Start simulation

      // Wait for delay to complete
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Verify Live Execution Verification results displayed
      expect(find.text('Live Execution Verification'), findsOneWidget);
      expect(find.textContaining('PASSED'), findsOneWidget);
    });
  });
}
