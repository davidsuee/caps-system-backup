import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/models/facility_model.dart';
import 'package:gym_management_system/data/repositories/facility_repository_impl.dart';
import 'package:gym_management_system/presentation/admin/providers/facility_provider.dart';
import 'package:gym_management_system/presentation/admin/screens/admin_facilities_screen.dart';

void main() {
  group('Facility & Equipment Inventory Management (ERD Tables 10.0 & 11.0)', () {
    late LocalCacheService localCache;
    late FacilityRepositoryImpl facilityRepo;

    setUp(() {
      localCache = LocalCacheService();
      facilityRepo = FacilityRepositoryImpl(localCache: localCache);
    });

    test('Initial Seeded Facilities: zones have defined capacities and crowd occupancy', () async {
      final facilities = await facilityRepo.getAllFacilities();
      expect(facilities.isNotEmpty, isTrue);
      expect(facilities.length, greaterThanOrEqualTo(4));

      final cardioZone = facilities.firstWhere((f) => f.name.contains('Cardio'));
      expect(cardioZone.capacity, greaterThan(0));
      expect(cardioZone.currentOccupancy, greaterThanOrEqualTo(0));
      expect(cardioZone.occupancyRate, inInclusiveRange(0.0, 1.0));
      expect(cardioZone.status, equals('open'));

      final freeWeights = facilities.firstWhere((f) => f.name.contains('Free Weights'));
      expect(freeWeights.capacity, greaterThanOrEqualTo(30));
    });

    test('Facility Zone Status Update updates local cache state correctly', () async {
      final facilities = await facilityRepo.getAllFacilities();
      final targetZone = facilities.first;

      await facilityRepo.updateFacilityStatus(targetZone.id, 'cleaning');

      final updatedFacilities = await facilityRepo.getAllFacilities();
      final updatedZone = updatedFacilities.firstWhere((f) => f.id == targetZone.id);
      expect(updatedZone.status, equals('cleaning'));

      // Revert back to open
      await facilityRepo.updateFacilityStatus(targetZone.id, 'open');
      final reverted = (await facilityRepo.getAllFacilities()).firstWhere((f) => f.id == targetZone.id);
      expect(reverted.status, equals('open'));
    });

    test('Initial Seeded Equipment: items have serial numbers, categories, and maintenance status', () async {
      final equipment = await facilityRepo.getAllEquipment();
      expect(equipment.isNotEmpty, isTrue);
      expect(equipment.length, greaterThanOrEqualTo(14));

      final treadmill = equipment.firstWhere((e) => e.name.contains('Treadmill'));
      expect(treadmill.name, equals('Commercial Treadmill'));
      expect(treadmill.category, equals('Cardio'));
      expect(treadmill.serialNumber, isNotEmpty);
      expect(treadmill.status, equals('operational'));

      // Verify that removed items are not present
      expect(equipment.any((e) => e.name.contains('Commercial Treadmill Pro X2')), isFalse);
      expect(equipment.any((e) => e.name.contains('Stepmill Climber Commercial')), isFalse);

      // Verify newly added equipment
      final expectedNewItems = [
        'Machine Curl',
        'Peck Deck Fly Machine',
        'Calf Raises Machine',
        'Leg Press Machine',
        'Lat Pull Down Machine',
        'Row Machine',
        'Cable Machine',
        'Squat Rack',
        'Dumbbell Rack',
      ];
      for (final name in expectedNewItems) {
        expect(equipment.any((e) => e.name == name), isTrue,
            reason: 'Expected $name to be in equipment inventory');
      }

      final dumbbellRack = equipment.firstWhere((e) => e.name == 'Dumbbell Rack');
      expect(dumbbellRack.category, equals('Free Weights'));
      expect(dumbbellRack.serialNumber, equals('VF-FW-012'));
      expect(dumbbellRack.status, equals('operational'));
    });

    test('Equipment Maintenance Status Update updates status and maintenance timestamp', () async {
      final equipmentList = await facilityRepo.getAllEquipment();
      final target = equipmentList.first;

      await facilityRepo.updateEquipmentStatus(target.id, 'under_maintenance');
      final midList = await facilityRepo.getAllEquipment();
      expect(midList.firstWhere((e) => e.id == target.id).status, equals('under_maintenance'));

      final beforeUpdate = DateTime.now();
      await facilityRepo.updateEquipmentStatus(target.id, 'operational');

      final updatedList = await facilityRepo.getAllEquipment();
      final restoredItem = updatedList.firstWhere((e) => e.id == target.id);

      expect(restoredItem.status, equals('operational'));
      expect(restoredItem.lastMaintained.isAfter(beforeUpdate.subtract(const Duration(seconds: 2))), isTrue);
    });

    test('Deleting equipment removes it from local cache and inventory', () async {
      final tempEquipment = EquipmentModel(
        id: 'eq-temp-del-test',
        name: 'Temporary Item To Delete',
        category: 'Cardio',
        facilityId: 'fac-1',
        facilityName: 'Cardio Deck',
        serialNumber: 'TEMP-DEL-999',
        status: 'operational',
        lastMaintained: DateTime.now(),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 30)),
      );
      await facilityRepo.addEquipment(tempEquipment);

      final beforeDeleteList = await facilityRepo.getAllEquipment();
      expect(beforeDeleteList.any((e) => e.id == tempEquipment.id), isTrue);

      await facilityRepo.deleteEquipment(tempEquipment.id);

      final afterDeleteList = await facilityRepo.getAllEquipment();
      expect(afterDeleteList.any((e) => e.id == tempEquipment.id), isFalse);
    });

    test('Adding new Equipment persists and appears in inventory', () async {
      final newEquipment = EquipmentModel(
        id: 'eq-test-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Commercial Row Machine',
        category: 'Cardio',
        facilityId: 'fac-1',
        facilityName: 'Cardio Deck',
        serialNumber: 'CR-ROW-9988',
        status: 'operational',
        lastMaintained: DateTime.now(),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 90)),
      );

      await facilityRepo.addEquipment(newEquipment);

      final equipmentList = await facilityRepo.getAllEquipment();
      final found = equipmentList.where((e) => e.id == newEquipment.id).firstOrNull;
      expect(found, isNotNull);
      expect(found!.name, equals('Commercial Row Machine'));
      expect(found.serialNumber, equals('CR-ROW-9988'));
    });

    test('FacilityNotifier loads state and calculates accurate operational metrics', () async {
      final container = ProviderContainer(
        overrides: [
          facilityRepositoryProvider.overrideWithValue(facilityRepo),
        ],
      );
      addTearDown(container.dispose);

      // Trigger initial load and wait
      await container.read(facilityNotifierProvider.notifier).loadData();

      final state = container.read(facilityNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.facilities.isNotEmpty, isTrue);
      expect(state.equipment.isNotEmpty, isTrue);
      expect(state.operationalCount, greaterThan(0));
      expect(state.maintenanceCount, greaterThanOrEqualTo(0));

      // Test category filtering
      container.read(facilityNotifierProvider.notifier).filterByCategory('Cardio');
      final cardioFiltered = container.read(facilityNotifierProvider).filteredEquipment;
      expect(cardioFiltered.every((e) => e.category == 'Cardio'), isTrue);

      // Reset filter
      container.read(facilityNotifierProvider.notifier).filterByCategory('All');
      final allFiltered = container.read(facilityNotifierProvider).filteredEquipment;
      expect(allFiltered.length, equals(state.equipment.length));
    });

    testWidgets('AdminFacilitiesScreen renders without overflow and supports tab switching', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            facilityRepositoryProvider.overrideWithValue(facilityRepo),
          ],
          child: const MaterialApp(
            home: AdminFacilitiesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Tab Bar
      expect(find.text('Facilities & Inventory'), findsOneWidget);
      expect(find.textContaining('Zones'), findsWidgets);
      expect(find.textContaining('Equipment'), findsWidgets);

      // Verify Zone cards rendered
      expect(find.textContaining('Cardio Deck'), findsOneWidget);

      // Switch to Equipment Inventory tab
      await tester.tap(find.textContaining('Equipment').first);
      await tester.pumpAndSettle();

      // Verify Equipment tab KPIs & items
      expect(find.text('OPERATIONAL'), findsWidgets);
      expect(find.textContaining('Treadmill'), findsWidgets);

      // Verify Add Equipment button is present
      expect(find.byTooltip('Add Equipment'), findsOneWidget);
    });
  });
}
