import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final now = DateTime.now();
    final hour = now.hour;
    final isOpen = hour >= 8 && hour < 23;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context, isDark),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Full-height expanded Hero section ("sakop yung page")
                Expanded(
                  child: _buildHeroSection(context),
                ),

                // Sleek Footer with Location, Operating Hours & Live Status
                _buildFooter(context, isDark, isOpen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- APP BAR WITH NAVIGATION & SIGN IN ---
  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppColors.surface : Colors.white,
      elevation: isDark ? 2 : 1,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
      titleSpacing: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                if (_scrollController.hasClients) {
                  _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                }
              },
              child: Container(
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
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
      ),
      title: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'FITNESS',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
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
        // Desktop Navigation Links (Separate Dedicated Pages)
        if (MediaQuery.of(context).size.width >= 1150) ...[
          _buildHeaderNavLink(
            title: 'Features',
            icon: Icons.bolt_rounded,
            onTap: () => context.push(AppRoutes.publicFeatures),
            isDark: isDark,
          ),
          _buildHeaderNavLink(
            title: 'Amenities',
            icon: Icons.fitness_center_rounded,
            onTap: () => context.push(AppRoutes.publicAmenities),
            isDark: isDark,
          ),
          _buildHeaderNavLink(
            title: 'Memberships',
            icon: Icons.card_membership_rounded,
            onTap: () => context.push(AppRoutes.publicMemberships),
            isDark: isDark,
          ),
          _buildHeaderNavLink(
            title: 'Rules & Regulations',
            icon: Icons.rule_folder_rounded,
            onTap: () => context.push(AppRoutes.publicRules),
            isDark: isDark,
          ),
          _buildHeaderNavLink(
            title: 'Location & Hours',
            icon: Icons.location_on_rounded,
            onTap: () => context.push(AppRoutes.publicLocation),
            isDark: isDark,
          ),
          const SizedBox(width: 6),
        ] else ...[
          // Mobile Navigation Menu (Separate Pages)
          PopupMenuButton<String>(
            tooltip: 'Navigation Menu',
            icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            color: isDark ? AppColors.surface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (route) => context.push(route),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: AppRoutes.publicFeatures,
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Features & Tech', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AppRoutes.publicAmenities,
                child: Row(
                  children: [
                    Icon(Icons.fitness_center_rounded, size: 16, color: AppColors.accentCyan),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Gym Amenities & Zones', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AppRoutes.publicMemberships,
                child: Row(
                  children: [
                    Icon(Icons.card_membership_rounded, size: 16, color: AppColors.accent),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Membership Plans', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AppRoutes.publicRules,
                child: Row(
                  children: [
                    Icon(Icons.rule_folder_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Rules & Regulations', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: AppRoutes.publicLocation,
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Location & Hours', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        // Functional Theme Toggle Button (Light / Dark)
        const ThemeToggleButton(showLabel: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: ElevatedButton.icon(
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
        const SizedBox(width: 4),
      ],
    );
  }

  // --- HERO SECTION WITH ATHLETIC GREEN THEME & GYM BACKGROUND (FULL BLEED) ---
  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF090B0E),
      ),
      child: Stack(
        children: [
          // Dynamic Gym Atmosphere Background Image
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?q=80&w=1600&auto=format&fit=crop',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: AppColors.surface,
              ),
            ),
          ),

          // High-Contrast Green & Charcoal Dark Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF090B0E).withValues(alpha: 0.94),
                    const Color(0xFF003D1A).withValues(alpha: 0.65), // Emerald ambient gym tint
                    const Color(0xFF090B0E).withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Subtle Green Radial Ambient Glow
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.30),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Hero Main Content (Centered vertically and horizontally)
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Next-Gen Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, color: AppColors.primary, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'NEXT-GEN FITNESS PLATFORM',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Slogan / Headline
                  const Text(
                    'Unleash Your Ultimate Potential at Vicious Fitness',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Subtitle
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 750),
                    child: const Text(
                      'Smart gym management featuring custom AI workout routines, precision meal planning, live occupancy tracking, and certified personal trainers.',
                      style: TextStyle(
                        color: Color(0xFFD5DCE5),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Call To Action Buttons (Original Green Theme Colors)
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: [
                      // Primary Neon Athletic Green Button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => context.push(AppRoutes.register),
                          icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.black),
                          label: const Text(
                            'Join Vicious Now',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            elevation: 4,
                            shadowColor: AppColors.primary.withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      // Secondary Outlined Green Button
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.login),
                          icon: const Icon(Icons.login_rounded, size: 18, color: AppColors.primary),
                          label: const Text(
                            'Portal Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, width: 1.8),
                            foregroundColor: Colors.white,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                            padding: const EdgeInsets.symmetric(horizontal: 26),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HEADER NAVIGATION BUTTON HELPER ---
  Widget _buildHeaderNavLink({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 13, color: AppColors.primary),
          label: Text(
            title,
            style: TextStyle(
              color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  // --- FOOTER & CONTACT (FEATURING LOCATION, OPERATING HOURS & LIVE STATUS) ---
  Widget _buildFooter(BuildContext context, bool isDark, bool isOpen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0F14) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.border.withValues(alpha: 0.7) : const Color(0xFFCBD5E1),
            width: 1.0,
          ),
        ),
      ),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Primary Footer Utility Bar (Moved from top per user request)
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 18,
                runSpacing: 8,
                children: [
                  // Gym Location
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Caloocan City, Metro Manila',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),

                  // Operating Hours
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, color: AppColors.accentCyan, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Open Daily: 8:00 AM – 11:00 PM',
                        style: TextStyle(
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),

                  // Live Open / Closed Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isOpen ? AppColors.primary : AppColors.error).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isOpen ? AppColors.primary : AppColors.error).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOpen ? AppColors.primary : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOpen ? 'OPEN NOW' : 'CLOSED NOW • OPENS 8 AM',
                          style: TextStyle(
                            color: isOpen ? AppColors.primary : AppColors.error,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Direct link to Location & Hours page
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
                      onTap: () => context.push(AppRoutes.publicLocation),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Location & Operating Hours Details',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Subline with Capstone collaboration info & operating hours text
              Text(
                'Operating Hours: 8:00 AM – 11:00 PM Daily • In collaboration with Global Reciprocal Colleges - BSIT Capstone',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? AppColors.textMuted : const Color(0xFF64748B),
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
