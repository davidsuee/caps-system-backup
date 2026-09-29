import 'package:go_router/go_router.dart';
import '../core/constants/app_routes.dart';
import '../presentation/auth/screens/login_screen.dart';
import '../presentation/auth/screens/register_screen.dart';
import '../presentation/dashboard/screens/home_dashboard_screen.dart';
import '../presentation/workout/screens/workout_plan_screen.dart';
import '../presentation/meal/screens/meal_plan_screen.dart';
import '../presentation/progress/screens/progress_tracking_screen.dart';
import '../presentation/membership/screens/membership_plans_screen.dart';
import '../presentation/membership/screens/attendance_screen.dart';
import '../presentation/profile/screens/profile_screen.dart';
import '../presentation/coach/screens/coach_dashboard_screen.dart';
import '../presentation/admin/screens/admin_dashboard_screen.dart';
import '../presentation/admin/screens/admin_members_directory_screen.dart';
import '../presentation/admin/screens/admin_coaches_directory_screen.dart';
import '../presentation/admin/screens/admin_facilities_screen.dart';
import '../presentation/admin/screens/admin_attendance_screen.dart';
import '../presentation/admin/screens/ai_benchmark_screen.dart';
import '../presentation/landing/screens/welcome_screen.dart';

bool _initialLaunchHandled = false;

void resetInitialLaunchForTest() {
  _initialLaunchHandled = false;
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.welcome,
  redirect: (context, state) {
    if (!_initialLaunchHandled) {
      _initialLaunchHandled = true;
      if (state.uri.path == AppRoutes.login ||
          state.uri.path == AppRoutes.root ||
          state.uri.path.isEmpty) {
        return AppRoutes.welcome;
      }
    }
    return null;
  },
  errorBuilder: (context, state) => const WelcomeScreen(),
  routes: [
    GoRoute(
      path: AppRoutes.root,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/role-selection',
      redirect: (context, state) => AppRoutes.welcome,
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) {
        final plan = state.uri.queryParameters['plan'];
        final priceStr = state.uri.queryParameters['price'];
        final daysStr = state.uri.queryParameters['days'];
        final price = priceStr != null ? double.tryParse(priceStr) : null;
        final days = daysStr != null ? int.tryParse(daysStr) : null;
        return RegisterScreen(
          selectedPlanName: plan,
          selectedPlanPrice: price,
          selectedPlanDays: days,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.memberDashboard,
      builder: (context, state) => const HomeDashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.workoutPlan,
      builder: (context, state) => const WorkoutPlanScreen(),
    ),
    GoRoute(
      path: AppRoutes.mealPlan,
      builder: (context, state) => const MealPlanScreen(),
    ),
    GoRoute(
      path: AppRoutes.progress,
      builder: (context, state) => const ProgressTrackingScreen(),
    ),
    GoRoute(
      path: AppRoutes.membership,
      builder: (context, state) => const MembershipPlansScreen(),
    ),
    GoRoute(
      path: AppRoutes.attendance,
      builder: (context, state) => const AttendanceScreen(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.coachDashboard,
      builder: (context, state) => const CoachDashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminDashboard,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminMembersDirectory,
      builder: (context, state) => const AdminMembersDirectoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminCoachesDirectory,
      builder: (context, state) => const AdminCoachesDirectoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.welcome,
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminFacilities,
      builder: (context, state) {
        final tabStr = state.uri.queryParameters['tab'];
        final initialTab = tabStr != null ? (int.tryParse(tabStr) ?? 0) : 0;
        return AdminFacilitiesScreen(initialTab: initialTab);
      },
    ),
    GoRoute(
      path: AppRoutes.aiBenchmark,
      builder: (context, state) => const AiBenchmarkScreen(),
    ),
    GoRoute(
      path: AppRoutes.adminAttendance,
      builder: (context, state) => const AdminAttendanceScreen(),
    ),
  ],
);
