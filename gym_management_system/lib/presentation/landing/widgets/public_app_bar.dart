import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class PublicAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String currentRoute;
  final bool showBackButton;

  const PublicAppBar({
    super.key,
    required this.currentRoute,
    this.showBackButton = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1280;

    return AppBar(
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      elevation: isDark ? 2 : 1,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
      titleSpacing: 0,
      leadingWidth: (showBackButton && Navigator.of(context).canPop()) ? 96 : 56,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBackButton && Navigator.of(context).canPop())
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  size: 20,
                ),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(left: (showBackButton && Navigator.of(context).canPop()) ? 0 : 12),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {
                  if (currentRoute != AppRoutes.welcome) {
                    context.go(AppRoutes.welcome);
                  }
                },
                child: Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/vicious_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center_rounded, color: Colors.black, size: 18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      title: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (currentRoute != AppRoutes.welcome) {
              context.go(AppRoutes.welcome);
            }
          },
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'VICIOUS',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'FITNESS',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        // Desktop Navigation Links
        if (isDesktop) ...[
          _buildNavLink(
            context: context,
            title: 'Home',
            icon: Icons.home_rounded,
            route: AppRoutes.welcome,
            isActive: currentRoute == AppRoutes.welcome,
          ),
          _buildNavLink(
            context: context,
            title: 'Features',
            icon: Icons.bolt_rounded,
            route: AppRoutes.publicFeatures,
            isActive: currentRoute == AppRoutes.publicFeatures,
          ),
          _buildNavLink(
            context: context,
            title: 'Amenities',
            icon: Icons.fitness_center_rounded,
            route: AppRoutes.publicAmenities,
            isActive: currentRoute == AppRoutes.publicAmenities,
          ),
          _buildNavLink(
            context: context,
            title: 'Memberships',
            icon: Icons.card_membership_rounded,
            route: AppRoutes.publicMemberships,
            isActive: currentRoute == AppRoutes.publicMemberships,
          ),
          _buildNavLink(
            context: context,
            title: screenWidth >= 1350 ? 'Rules & Regulations' : 'Rules',
            icon: Icons.rule_folder_rounded,
            route: AppRoutes.publicRules,
            isActive: currentRoute == AppRoutes.publicRules,
          ),
          _buildNavLink(
            context: context,
            title: screenWidth >= 1350 ? 'Location & Hours' : 'Location',
            icon: Icons.location_on_rounded,
            route: AppRoutes.publicLocation,
            isActive: currentRoute == AppRoutes.publicLocation,
          ),
          const SizedBox(width: 8),
        ] else ...[
          // Mobile / Tablet Navigation Menu
          PopupMenuButton<String>(
            tooltip: 'Navigation Menu',
            icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            color: isDark ? AppColors.surface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (route) {
              if (route != currentRoute) {
                context.push(route);
              }
            },
            itemBuilder: (context) => [
              _buildPopupItem(
                title: 'Home',
                icon: Icons.home_rounded,
                route: AppRoutes.welcome,
                isActive: currentRoute == AppRoutes.welcome,
              ),
              _buildPopupItem(
                title: 'Features & Technology',
                icon: Icons.bolt_rounded,
                route: AppRoutes.publicFeatures,
                isActive: currentRoute == AppRoutes.publicFeatures,
              ),
              _buildPopupItem(
                title: 'Gym Amenities & Zones',
                icon: Icons.fitness_center_rounded,
                route: AppRoutes.publicAmenities,
                isActive: currentRoute == AppRoutes.publicAmenities,
              ),
              _buildPopupItem(
                title: 'Membership Plans',
                icon: Icons.card_membership_rounded,
                route: AppRoutes.publicMemberships,
                isActive: currentRoute == AppRoutes.publicMemberships,
              ),
              _buildPopupItem(
                title: 'Rules & Regulations',
                icon: Icons.rule_folder_rounded,
                route: AppRoutes.publicRules,
                isActive: currentRoute == AppRoutes.publicRules,
              ),
              _buildPopupItem(
                title: 'Location & Operating Hours',
                icon: Icons.location_on_rounded,
                route: AppRoutes.publicLocation,
                isActive: currentRoute == AppRoutes.publicLocation,
              ),
            ],
          ),
        ],

        // Functional Theme Toggle Button
        const ThemeToggleButton(showLabel: false),
        SizedBox(width: screenWidth < 500 ? 2 : 6),

        // Sign In Action Button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: screenWidth < 500
                ? IconButton(
                    onPressed: () => context.push(AppRoutes.login),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    tooltip: 'Sign In',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(34, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.login),
                    icon: const Icon(Icons.login_rounded, size: 14, color: Colors.black),
                    label: const Text(
                      'Sign In',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                  ),
          ),
        ),
        SizedBox(width: screenWidth < 500 ? 6 : 12),
      ],
    );
  }

  Widget _buildNavLink({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String route,
    required bool isActive,
  }) {
    final isDark = context.isDark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: TextButton.icon(
          onPressed: () {
            if (isActive) return;
            context.push(route);
          },
          icon: Icon(
            icon,
            size: 13,
            color: isActive ? AppColors.primary : (isDark ? const Color(0xFF9EABB8) : const Color(0xFF64748B)),
          ),
          label: Text(
            title,
            style: TextStyle(
              color: isActive
                  ? AppColors.primary
                  : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
              fontSize: 12.5,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
              decoration: isActive ? TextDecoration.underline : TextDecoration.none,
              decorationColor: AppColors.primary,
              decorationThickness: 2,
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: isActive
                  ? BorderSide(color: AppColors.primary.withValues(alpha: 0.35))
                  : BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem({
    required String title,
    required IconData icon,
    required String route,
    required bool isActive,
  }) {
    return PopupMenuItem<String>(
      value: route,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? AppColors.primary : const Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isActive ? AppColors.primary : null,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
