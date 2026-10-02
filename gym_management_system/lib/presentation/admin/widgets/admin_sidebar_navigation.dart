import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../providers/facility_provider.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../../core/utils/facility_hours_helper.dart';

class AdminSidebarNavigation extends ConsumerWidget {
  final String currentRoute;
  final bool isDrawer;
  final VoidCallback? onAvailableEquipmentsTap;

  const AdminSidebarNavigation({
    super.key,
    this.currentRoute = AppRoutes.adminDashboard,
    this.isDrawer = false,
    this.onAvailableEquipmentsTap,
  });

  void _navigate(BuildContext context, String route) {
    if (isDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (route == currentRoute) return;
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final adminState = ref.watch(adminNotifierProvider);
    final facilityState = ref.watch(facilityNotifierProvider);

    final allEquipment = facilityState.equipment.isNotEmpty
        ? facilityState.equipment
        : LocalCacheService().getAllEquipment();
    final operationalCount = allEquipment.where((e) => e.isOperational).length;

    final isFacilityOpen = FacilityHoursHelper.isGymOpen();
    final now = DateTime.now();
    final activeInsideCount = isFacilityOpen
        ? adminState.attendance.where((a) {
            if (a.checkOutTime != null) return false;
            final closing = DateTime(a.checkInTime.year, a.checkInTime.month, a.checkInTime.day, 23, 0);
            return now.isBefore(closing);
          }).length
        : 0;
    final todayCheckInsCount = LocalCacheService().getTodayAttendance().length;

    return Container(
      width: 275,
      height: double.infinity,
      decoration: BoxDecoration(
        color: context.surfaceBg,
        border: Border(
          right: BorderSide(
            color: context.borderLine,
            width: 1.2,
          ),
        ),
        boxShadow: isDrawer
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(4, 0),
                ),
              ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Brand Logo & System Status Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.borderLine, width: 1.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'VICIOUS',
                                    style: TextStyle(
                                      color: context.titleColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'FITNESS',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'ADMIN CONSOLE',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isDrawer)
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: context.mutedColor, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Live status pill
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'SYSTEM LIVE & ONLINE',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Navigation List Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                children: [
                  // --- SECTION: CORE ---
                  _buildSectionLabel(context, 'DASHBOARD'),
                  _buildNavItem(
                    context: context,
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard Overview',
                    isActive: currentRoute == AppRoutes.adminDashboard,
                    onTap: () => _navigate(context, AppRoutes.adminDashboard),
                  ),

                  const SizedBox(height: 14),
                  // --- SECTION: OPERATIONS & FRONT DESK ---
                  _buildSectionLabel(context, 'FRONT DESK & ACTIONS'),
                  _buildNavItem(
                    context: context,
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Register Member',
                    isHighlight: true,
                    highlightColor: AppColors.primary,
                    onTap: () => _navigate(context, AppRoutes.register),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.payments_rounded,
                    title: 'Record Payment',
                    isActive: currentRoute == AppRoutes.adminPayment,
                    badgeText: adminState.pendingMemberships.isNotEmpty
                        ? '${adminState.pendingMemberships.length}'
                        : null,
                    badgeColor: AppColors.accent,
                    onTap: () => _navigate(context, AppRoutes.adminPayment),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.how_to_reg_rounded,
                    title: 'Client Check-In',
                    isActive: currentRoute == AppRoutes.adminAttendance,
                    isHighlight: true,
                    highlightColor: AppColors.primary,
                    badgeText: activeInsideCount > 0 ? '$activeInsideCount Inside' : (todayCheckInsCount > 0 ? '$todayCheckInsCount Today' : null),
                    badgeColor: activeInsideCount > 0 ? AppColors.primary : AppColors.accentCyan,
                    onTap: () => _navigate(context, AppRoutes.adminAttendance),
                  ),

                  const SizedBox(height: 14),
                  // --- SECTION: DIRECTORIES & ROSTERS ---
                  _buildSectionLabel(context, 'RECORDS & ROSTERS'),
                  _buildNavItem(
                    context: context,
                    icon: Icons.groups_rounded,
                    title: 'Member Records',
                    isActive: currentRoute == AppRoutes.adminMembersDirectory,
                    badgeText: '${adminState.members.length}',
                    onTap: () => _navigate(context, AppRoutes.adminMembersDirectory),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.sports_rounded,
                    title: 'Coach Records',
                    isActive: currentRoute == AppRoutes.adminCoachesDirectory,
                    badgeText: '${adminState.coaches.length}',
                    onTap: () => _navigate(context, AppRoutes.adminCoachesDirectory),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.receipt_long_rounded,
                    title: 'Attendance Logs',
                    onTap: () => _navigate(context, '${AppRoutes.adminAttendance}?tab=2'),
                  ),

                  const SizedBox(height: 14),
                  // --- SECTION: FACILITIES & EQUIPMENT ---
                  _buildSectionLabel(context, 'FACILITIES & EQUIPMENT'),
                  _buildNavItem(
                    context: context,
                    icon: Icons.domain_rounded,
                    title: 'Facilities',
                    isActive: currentRoute == AppRoutes.adminFacilities,
                    onTap: () => _navigate(context, AppRoutes.adminFacilities),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.fitness_center_rounded,
                    title: 'Available Equipments',
                    badgeText: '$operationalCount READY',
                    badgeColor: AppColors.primary,
                    iconColor: AppColors.primary,
                    onTap: onAvailableEquipmentsTap ??
                        () => _navigate(context, '${AppRoutes.adminFacilities}?tab=1'),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.tune_rounded,
                    title: 'Manage Equipments',
                    iconColor: AppColors.accentCyan,
                    onTap: () => _navigate(context, '${AppRoutes.adminFacilities}?tab=1'),
                  ),

                  const SizedBox(height: 14),
                  // --- SECTION: PORTAL & PUBLIC ---
                  _buildSectionLabel(context, 'PUBLIC PORTAL'),
                  _buildNavItem(
                    context: context,
                    icon: Icons.public_rounded,
                    title: 'Public Landing',
                    trailingIcon: Icons.open_in_new_rounded,
                    onTap: () => _navigate(context, AppRoutes.welcome),
                  ),
                  _buildNavItem(
                    context: context,
                    icon: Icons.rule_folder_rounded,
                    title: 'Rules & Regulations',
                    trailingIcon: Icons.open_in_new_rounded,
                    onTap: () => _navigate(context, AppRoutes.publicRules),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Sidebar Footer: Admin Profile & Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: context.cardColor,
                border: Border(
                  top: BorderSide(color: context.borderLine, width: 1.0),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: Text(
                          (user?.name.isNotEmpty == true ? user!.name[0] : 'A').toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Admin Sarah',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.titleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'SUPER ADMINISTRATOR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const ThemeToggleButton(),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (isDrawer && Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                        context.go(AppRoutes.welcome);
                        await ref.read(authNotifierProvider.notifier).logout();
                      },
                      icon: const Icon(Icons.logout_rounded, size: 15, color: AppColors.error),
                      label: const Text(
                        'Sign Out of Console',
                        style: TextStyle(color: AppColors.error, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          color: context.mutedColor,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isActive = false,
    bool isHighlight = false,
    Color? highlightColor,
    Color? iconColor,
    String? badgeText,
    Color? badgeColor,
    IconData? trailingIcon,
  }) {
    final effectiveColor = isActive
        ? AppColors.primary
        : (iconColor ?? (isHighlight ? (highlightColor ?? AppColors.primary) : context.titleColor));

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.12)
            : (isHighlight ? AppColors.primary.withValues(alpha: 0.06) : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        border: isActive
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.2)
            : (isHighlight ? Border.all(color: AppColors.primary.withValues(alpha: 0.25)) : null),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: effectiveColor,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isActive
                          ? AppColors.primary
                          : (isHighlight ? context.titleColor : context.titleColor.withValues(alpha: 0.9)),
                      fontSize: 13,
                      fontWeight: isActive || isHighlight ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (badgeText != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (badgeColor ?? AppColors.primary).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: badgeColor ?? AppColors.primary,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
                if (trailingIcon != null) ...[
                  const SizedBox(width: 6),
                  Icon(trailingIcon, size: 14, color: context.mutedColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
