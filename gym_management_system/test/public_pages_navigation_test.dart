import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/core/constants/app_routes.dart';
import 'package:gym_management_system/presentation/landing/screens/features_screen.dart';
import 'package:gym_management_system/presentation/landing/screens/amenities_screen.dart';
import 'package:gym_management_system/presentation/landing/screens/membership_tiers_screen.dart';
import 'package:gym_management_system/presentation/landing/screens/location_hours_screen.dart';
import 'package:gym_management_system/routing/app_router.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Public Separate Pages & Navigation Tests', () {
    testWidgets('FeaturesScreen renders dedicated Smart Gym Technology page', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: FeaturesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Smart Gym Technology'), findsOneWidget);
      expect(find.text('Personalized Exercise Routines'), findsOneWidget);
      expect(find.text('Smart Daily Diet & Macros'), findsOneWidget);
      expect(find.text('1-on-1 Certified Coach Pairing'), findsOneWidget);
      // Ensure no QR pass is present
      expect(find.textContaining('Contactless QR Pass'), findsNothing);
    });

    testWidgets('AmenitiesScreen renders dedicated Gym Amenities & Zones page with 8AM-11PM', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AmenitiesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gym Amenities & Zones'), findsOneWidget);
      expect(find.text('Cardio Deck'), findsOneWidget);
      expect(find.text('Free Weights Area'), findsOneWidget);
      expect(find.text('Functional Turf Studio'), findsOneWidget);
      expect(find.textContaining('8:00 AM – 11:00 PM Daily'), findsOneWidget);
    });

    testWidgets('MembershipTiersScreen renders dedicated Membership Plans page', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MembershipTiersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Membership Plans'), findsOneWidget);
      expect(find.text('Daily Drop-In'), findsNothing);
      expect(find.textContaining('1-Day Walk-In Pass • ₱150'), findsOneWidget);
      expect(find.textContaining('NO ACCOUNT REQUIRED'), findsOneWidget);
      expect(find.text('Monthly Standard'), findsOneWidget);
      expect(find.text('Quarterly Pro'), findsOneWidget);
      expect(find.text('Annual VIP'), findsOneWidget);
      expect(find.text('Counter Payment Process'), findsOneWidget);
    });

    testWidgets('LocationHoursScreen renders dedicated Location & Operating Hours page with 8AM-11PM', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LocationHoursScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Location & Operating Hours'), findsOneWidget);
      expect(find.text('8:00 AM – 11:00 PM Daily'), findsOneWidget);
      expect(find.text('Facility Address'), findsOneWidget);
      expect(find.text('Front Desk & Reception'), findsOneWidget);
    });

    test('AppRoutes definitions for separate public pages exist', () {
      expect(AppRoutes.publicFeatures, '/features');
      expect(AppRoutes.publicAmenities, '/amenities');
      expect(AppRoutes.publicMemberships, '/membership-tiers');
      expect(AppRoutes.publicLocation, '/location-hours');
    });

    test('appRouter contains routes for all 4 public separate pages', () {
      final routePaths = appRouter.configuration.routes
          .whereType<GoRoute>()
          .map((r) => r.path)
          .toList();

      expect(routePaths.contains(AppRoutes.publicFeatures), isTrue);
      expect(routePaths.contains(AppRoutes.publicAmenities), isTrue);
      expect(routePaths.contains(AppRoutes.publicMemberships), isTrue);
      expect(routePaths.contains(AppRoutes.publicLocation), isTrue);
    });
  });
}
