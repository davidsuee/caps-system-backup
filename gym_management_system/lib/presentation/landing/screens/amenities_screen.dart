import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../widgets/public_app_bar.dart';

class AmenitiesScreen extends StatelessWidget {
  const AmenitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: const PublicAppBar(
        currentRoute: AppRoutes.publicAmenities,
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  _buildHeader(context),
                  const SizedBox(height: 28),

                  // Operating Hours Info Strip
                  _buildHoursInfoStrip(context),
                  const SizedBox(height: 28),

                  // Amenities Grid
                  _buildAmenitiesGrid(context),
                  const SizedBox(height: 36),

                  // Hygiene & Facility Standards
                  _buildStandardsSection(context),
                  const SizedBox(height: 36),

                  // CTA Banner
                  _buildCtaBanner(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.accentCyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center_rounded, color: AppColors.accentCyan, size: 14),
              SizedBox(width: 6),
              Text(
                'PREMIUM TRAINING SPACES',
                style: TextStyle(
                  color: AppColors.accentCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Gym Amenities & Zones',
          style: TextStyle(
            color: context.titleColor,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Explore our high-performance zones, heavy iron stations, conditioning tracks, and recovery suites designed to bring out your maximum strength.',
          style: TextStyle(
            color: context.subtitleColor,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHoursInfoStrip(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.access_time_filled_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Facility Operating Hours',
                  style: TextStyle(
                    color: context.titleColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '8:00 AM – 11:00 PM Daily (Monday to Sunday) • All amenities active during operating hours',
                  style: TextStyle(
                    color: context.subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: const Text(
              '8 AM - 11 PM',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesGrid(BuildContext context) {
    final isDark = context.isDark;

    final zones = [
      {
        'title': 'Cardio Deck',
        'icon': Icons.directions_run_rounded,
        'color': AppColors.primary,
        'desc': 'High-end cardiovascular conditioning gear featuring interactive fitness tracking and real-time biometric monitors.',
        'equipment': [
          'High-end Treadmills with speed/incline variation',
          'Stationary Exercise Bikes (Upright & Recumbent)',
          'Elliptical Cross-Trainers',
          'Commercial Rowing Machines',
        ],
      },
      {
        'title': 'Free Weights Area',
        'icon': Icons.fitness_center_rounded,
        'color': AppColors.accent,
        'desc': 'Extensive free weight space built for strength athletics, powerlifting, bodybuilding, and calibrated progressive overload.',
        'equipment': [
          'Dumbbell rack paired up to 50kg pairs',
          'Olympic power cages with pull-up grips',
          'Calibrated steel plates & bumper sets',
          'Adjustable incline, flat, & decline benches',
        ],
      },
      {
        'title': 'Functional Turf Studio',
        'icon': Icons.sports_mma_rounded,
        'color': AppColors.accentCyan,
        'desc': '30-meter high-density athletic turf zone dedicated to functional conditioning, agility work, and explosive power drills.',
        'equipment': [
          'Weighted push/pull sled tracks',
          'Cast-iron kettlebell range (8kg to 32kg)',
          'Heavy-duty battle ropes & anchors',
          'Plyo jump boxes & medicine balls',
        ],
      },
      {
        'title': 'Group Fitness Hall',
        'icon': Icons.groups_rounded,
        'color': Colors.purpleAccent,
        'desc': 'Spacious sprung-wood studio for bodyweight conditioning, group stretching, mobility sessions, and trainer demonstrations.',
        'equipment': [
          'Shock-absorbing sprung wood flooring',
          'Surround sound acoustics & studio mirrors',
          'Suspension trainers (TRX-style)',
          'High-density yoga mats & blocks',
        ],
      },
      {
        'title': 'Locker Rooms & Showers',
        'icon': Icons.shower_rounded,
        'color': const Color(0xFF38BDF8),
        'desc': 'Secure, spotless changing suites with secure padlock locker systems, high-pressure hot & cold showers, and full grooming stations.',
        'equipment': [
          'Heavy-Duty Padlock Security Lockers',
          'High-pressure rain showers with heated water',
          'Blow-dryers & grooming vanities',
          'Sanitized day-use storage',
        ],
      },
      {
        'title': 'Recovery & Stretching Lounge',
        'icon': Icons.self_improvement_rounded,
        'color': const Color(0xFF34D399),
        'desc': 'Dedicated cool-down space engineered to accelerate muscle recuperation, improve joint mobility, and reduce DOMS.',
        'equipment': [
          'Trigger-point foam rollers & lacrosse balls',
          'Deep-tissue percussive massage tools',
          'Resistance & mobility stretching bands',
          'Cold filtered water hydration bar',
        ],
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;
        final cardWidth = isDesktop ? ((constraints.maxWidth - 16) / 2).floorToDouble() : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: zones.map((z) {
            final title = z['title'] as String;
            final icon = z['icon'] as IconData;
            final color = z['color'] as Color;
            final desc = z['desc'] as String;
            final equipment = z['equipment'] as List<String>;

            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: context.titleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      desc,
                      style: TextStyle(
                        color: context.subtitleColor,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'FEATURED EQUIPMENT',
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...equipment.map((eq) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_rounded, color: color, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  eq,
                                  style: TextStyle(
                                    color: context.titleColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStandardsSection(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Facility Standards & Etiquette',
                style: TextStyle(
                  color: context.titleColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Proper athletic footwear and gym clothing required on all workout floors.\n'
            '• Sanitizing wipe stations available across every zone—re-rack weights after each set.\n'
            '• Operating strictly between 8:00 AM and 11:00 PM Daily. All check-ins managed at the front reception counter.\n'
            '• Dedicated personal trainers available for scheduled 1-on-1 coaching sessions.',
            style: TextStyle(
              color: context.subtitleColor,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF003D1A),
            AppColors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          const Text(
            'Ready to Tour the Facility?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Visit our gym reception counter during operating hours (8:00 AM – 11:00 PM) for a walkthrough or sign up online now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB0BAC9),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => context.push(AppRoutes.register),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Join Vicious Fitness', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
              ),
              OutlinedButton(
                onPressed: () => context.push(AppRoutes.publicMemberships),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('View Membership Plans', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
