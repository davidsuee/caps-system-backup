class AppRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';

  // Member Routes
  static const String memberDashboard = '/member/dashboard';
  static const String workoutPlan = '/member/workout-plan';
  static const String mealPlan = '/member/meal-plan';
  static const String progress = '/member/progress';
  static const String membership = '/member/membership';
  static const String membershipPlans = '/member/membership';
  static const String attendance = '/member/attendance';
  static const String profile = '/member/profile';

  // Coach & Staff/Admin Routes
  static const String coachDashboard = '/coach/dashboard';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminMembersDirectory = '/admin/members-directory';
  static const String adminCoachesDirectory = '/admin/coaches-directory';
  static const String welcome = '/welcome';
  static const String adminFacilities = '/admin/facilities';
  static const String aiBenchmark = '/admin/ai-benchmark';
  static const String adminAttendance = '/admin/attendance';
  static const String adminPayment = '/admin/record-payment';

  // Public Information Routes (Dedicated Separate Pages)
  static const String publicFeatures = '/features';
  static const String publicAmenities = '/amenities';
  static const String publicMemberships = '/membership-tiers';
  static const String publicLocation = '/location-hours';
  static const String publicRules = '/rules-regulations';
}
