import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/facility_model.dart';
import '../../../domain/repositories/facility_repository.dart';
import '../../../data/repositories/facility_repository_impl.dart';

final facilityRepositoryProvider = Provider<FacilityRepository>((ref) {
  return FacilityRepositoryImpl();
});

class FacilityState {
  final bool isLoading;
  final String? errorMessage;
  final List<FacilityModel> facilities;
  final List<EquipmentModel> equipment;
  final String selectedCategory; // 'All', 'Cardio', 'Strength', 'Free Weights', 'Functional'
  final String selectedStatus; // 'All', 'operational', 'under_maintenance', 'out_of_order'
  final String searchQuery;

  const FacilityState({
    this.isLoading = false,
    this.errorMessage,
    this.facilities = const [],
    this.equipment = const [],
    this.selectedCategory = 'All',
    this.selectedStatus = 'All',
    this.searchQuery = '',
  });

  List<EquipmentModel> get filteredEquipment {
    return equipment.where((e) {
      if (selectedCategory != 'All' && e.category != selectedCategory) {
        return false;
      }
      if (selectedStatus != 'All' && e.status != selectedStatus) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        final matchesName = e.name.toLowerCase().contains(q);
        final matchesSerial = e.serialNumber.toLowerCase().contains(q);
        final matchesFacility = e.facilityName.toLowerCase().contains(q);
        if (!matchesName && !matchesSerial && !matchesFacility) return false;
      }
      return true;
    }).toList();
  }

  int get operationalCount => equipment.where((e) => e.isOperational).length;
  int get maintenanceCount => equipment.where((e) => e.isUnderMaintenance).length;
  int get outOfOrderCount => equipment.where((e) => e.isOutOfOrder).length;

  FacilityState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<FacilityModel>? facilities,
    List<EquipmentModel>? equipment,
    String? selectedCategory,
    String? selectedStatus,
    String? searchQuery,
  }) {
    return FacilityState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      facilities: facilities ?? this.facilities,
      equipment: equipment ?? this.equipment,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class FacilityNotifier extends Notifier<FacilityState> {
  late FacilityRepository _repo;

  @override
  FacilityState build() {
    _repo = ref.read(facilityRepositoryProvider);
    Future.microtask(loadData);
    return const FacilityState(isLoading: true);
  }

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final facilities = await _repo.getAllFacilities();
      final equipment = await _repo.getAllEquipment();
      state = state.copyWith(
        isLoading: false,
        facilities: facilities,
        equipment: equipment,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> updateFacilityStatus(String facilityId, String newStatus) async {
    try {
      await _repo.updateFacilityStatus(facilityId, newStatus);
      await loadData();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> updateEquipmentStatus(String equipmentId, String newStatus) async {
    try {
      await _repo.updateEquipmentStatus(equipmentId, newStatus);
      await loadData();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> addEquipment(EquipmentModel item) async {
    try {
      await _repo.addEquipment(item);
      await loadData();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteEquipment(String equipmentId) async {
    try {
      await _repo.deleteEquipment(equipmentId);
      await loadData();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void filterByCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void filterByStatus(String status) {
    state = state.copyWith(selectedStatus: status);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final facilityNotifierProvider =
    NotifierProvider<FacilityNotifier, FacilityState>(FacilityNotifier.new);
