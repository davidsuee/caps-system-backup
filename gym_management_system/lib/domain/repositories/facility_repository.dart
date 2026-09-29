import '../../data/models/facility_model.dart';

abstract class FacilityRepository {
  Future<List<FacilityModel>> getAllFacilities();
  Future<void> updateFacilityStatus(String facilityId, String newStatus);
  Future<List<EquipmentModel>> getAllEquipment();
  Future<void> updateEquipmentStatus(String equipmentId, String newStatus);
  Future<void> addEquipment(EquipmentModel equipment);
  Future<void> deleteEquipment(String equipmentId);
}
