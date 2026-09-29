import '../../domain/repositories/facility_repository.dart';
import '../datasources/local/local_cache_service.dart';
import '../datasources/remote/firestore_service.dart';
import '../models/facility_model.dart';

class FacilityRepositoryImpl implements FacilityRepository {
  final LocalCacheService _localCache;

  FacilityRepositoryImpl({
    LocalCacheService? localCache,
    FirestoreService? firestore,
  })  : _localCache = localCache ?? LocalCacheService();

  @override
  Future<List<FacilityModel>> getAllFacilities() async {
    return _localCache.getAllFacilities();
  }

  @override
  Future<void> updateFacilityStatus(String facilityId, String newStatus) async {
    final existing = _localCache.getFacility(facilityId);
    if (existing != null) {
      final updated = FacilityModel.fromEntity(existing.copyWith(status: newStatus));
      _localCache.saveFacility(updated);
    }
  }

  @override
  Future<List<EquipmentModel>> getAllEquipment() async {
    return _localCache.getAllEquipment();
  }

  @override
  Future<void> updateEquipmentStatus(String equipmentId, String newStatus) async {
    final existing = _localCache.getEquipment(equipmentId);
    if (existing != null) {
      final updated = EquipmentModel.fromEntity(
        existing.copyWith(
          status: newStatus,
          lastMaintained: newStatus == 'operational' ? DateTime.now() : existing.lastMaintained,
        ),
      );
      _localCache.saveEquipment(updated);
    }
  }

  @override
  Future<void> addEquipment(EquipmentModel equipment) async {
    _localCache.saveEquipment(equipment);
  }

  @override
  Future<void> deleteEquipment(String equipmentId) async {
    _localCache.deleteEquipment(equipmentId);
  }
}
