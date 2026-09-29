import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';
import 'package:gym_management_system/presentation/coach/providers/coach_provider.dart';
import 'package:gym_management_system/presentation/coach/screens/coach_dashboard_screen.dart';

class MockCoachNotifier extends CoachNotifier {
  final List<UserModel> mockClients;

  MockCoachNotifier(this.mockClients);

  @override
  CoachState build() {
    return CoachState(
      isLoading: false,
      clients: mockClients,
      clientWorkouts: const {},
      clientMeals: const {},
      sessions: const [],
    );
  }
}

void main() {
  testWidgets('Coach Dashboard search bar filters Assigned Client Roster dynamically', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final client1 = UserModel(
      id: 'c1',
      name: 'Maria Santos',
      email: 'maria@test.com',
      role: UserRole.member,
      fitnessGoal: 'Weight Loss',
      heightCm: 160,
      weightKg: 62,
      experienceLevel: 'Beginner',
      createdAt: DateTime.now(),
    );

    final client2 = UserModel(
      id: 'c2',
      name: 'John Lifter',
      email: 'john@test.com',
      role: UserRole.member,
      fitnessGoal: 'Muscle Gain',
      heightCm: 175,
      weightKg: 78,
      experienceLevel: 'Advanced',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coachNotifierProvider.overrideWith(() => MockCoachNotifier([client1, client2])),
        ],
        child: const MaterialApp(
          home: CoachDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Assigned Client Roster and Search Bar are present
    expect(find.textContaining('Assigned Client Roster (2)'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('John Lifter'), findsOneWidget);

    // 2. Type 'Maria' into the search bar
    final searchInput = find.byType(TextField);
    await tester.enterText(searchInput, 'Maria');
    await tester.pumpAndSettle();

    // Maria is shown, John is filtered out
    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('John Lifter'), findsNothing);
    expect(find.textContaining('Assigned Client Roster (1 of 2)'), findsOneWidget);

    // 3. Search by Goal 'Muscle'
    await tester.enterText(searchInput, 'Muscle');
    await tester.pumpAndSettle();

    expect(find.text('John Lifter'), findsOneWidget);
    expect(find.text('Maria Santos'), findsNothing);

    // 4. Search query with no match
    await tester.enterText(searchInput, 'NonExistentMember');
    await tester.pumpAndSettle();

    expect(find.text('No clients match "NonExistentMember"'), findsOneWidget);
    expect(find.text('Clear search filter'), findsOneWidget);

    // 5. Tap 'Clear search filter'
    await tester.tap(find.text('Clear search filter'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Santos'), findsOneWidget);
    expect(find.text('John Lifter'), findsOneWidget);
    expect(find.textContaining('Assigned Client Roster (2)'), findsOneWidget);
  });
}
