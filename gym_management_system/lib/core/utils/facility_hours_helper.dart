/// Central facility operating hours and gym check-in enforcement rules.
/// Operating Hours: 8:00 AM – 11:00 PM Daily (08:00 - 23:00)
class FacilityHoursHelper {
  static const int openHour = 8; // 8:00 AM
  static const int closeHour = 23; // 11:00 PM
  static const String operatingHoursString = '8:00 AM – 11:00 PM Daily';

  /// Returns whether the gym is currently open based on operating hours.
  static bool isGymOpen([DateTime? time]) {
    final t = time ?? DateTime.now();
    return t.hour >= openHour && t.hour < closeHour;
  }

  /// Detailed human-readable closed reason
  static String getClosedReason([DateTime? time]) {
    final t = time ?? DateTime.now();
    if (t.hour < openHour) {
      return 'The facility is currently closed. Operating hours start at 8:00 AM.';
    } else {
      return 'The facility is closed for the night (closed at 11:00 PM). Opens at 8:00 AM.';
    }
  }

  /// Warning message when trying to check progress while facility is closed
  static const String closedProgressWarning =
      'Facility Closed: Gym operating hours are 8:00 AM – 11:00 PM. Workout progress tracking is disabled because you are not inside the gym.';

  /// Warning message when trying to check progress while not checked in
  static const String checkInRequiredWarning =
      'Check-in Required: You must be checked in at the gym reception desk by the admin before checking off exercises or logging workout progress.';

  /// Warning message when trying to check progress again after completing current session
  static const String sessionAlreadyCompletedWarning =
      'Session Completed: You have already completed your workout progress for this gym visit. Check in again at the reception desk on your next visit to log progress again.';
}
