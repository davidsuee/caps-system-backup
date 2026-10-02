import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../widgets/public_app_bar.dart';

class LocationHoursScreen extends StatelessWidget {
  const LocationHoursScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isOpen = now.hour >= 8 && now.hour < 23;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: const PublicAppBar(
        currentRoute: AppRoutes.publicLocation,
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

                  // Operating Hours Status Banner
                  _buildOperatingHoursBanner(context, isOpen),
                  const SizedBox(height: 28),

                  // Location & Contact Info Grid
                  _buildInfoGrid(context),
                  const SizedBox(height: 36),

                  // Facility House Rules
                  _buildHouseRulesSection(context),
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
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_rounded, color: AppColors.primary, size: 14),
              SizedBox(width: 6),
              Text(
                'VISIT VICIOUS FITNESS',
                style: TextStyle(
                  color: AppColors.primary,
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
          'Location & Operating Hours',
          style: TextStyle(
            color: context.titleColor,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Plan your training sessions with confidence. Find our address, parking info, operating hours, and customer contact desk.',
          style: TextStyle(
            color: context.subtitleColor,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildOperatingHoursBanner(BuildContext context, bool isOpen) {
    final isDark = context.isDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen ? AppColors.primary.withValues(alpha: 0.5) : AppColors.warning.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOpen ? AppColors.primary : AppColors.warning).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isOpen ? AppColors.primary : AppColors.warning).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: isOpen ? AppColors.primary : AppColors.warning,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gym Operating Hours',
                        style: TextStyle(
                          color: context.titleColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '8:00 AM – 11:00 PM Daily',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: (isOpen ? AppColors.primary : AppColors.warning).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isOpen ? AppColors.primary : AppColors.warning).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isOpen ? AppColors.primary : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isOpen ? 'OPEN NOW • CLOSES 11 PM' : 'CLOSED NOW • OPENS 8 AM',
                      style: TextStyle(
                        color: isOpen ? AppColors.primary : AppColors.warning,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: isDark ? AppColors.border : const Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Operating hours are strictly enforced across all member check-ins and coach sessions. Sessions automatically check out at 11:00 PM sharp.',
                  style: TextStyle(
                    color: context.subtitleColor,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    final isDark = context.isDark;

    final cards = [
      {
        'icon': Icons.location_on_rounded,
        'color': AppColors.primary,
        'title': 'Facility Address',
        'content': '2nd Floor, Vicious Fitness Hub\nMetro Manila, Philippines',
        'detail': 'Located right along the main commercial strip. Direct elevator and stairwell access from the ground lobby.',
      },
      {
        'icon': Icons.local_parking_rounded,
        'color': AppColors.accentCyan,
        'title': 'Parking & Transport',
        'content': 'Free 2-Hour Basement Parking',
        'detail': 'Dedicated member parking bays with security surveillance. Accessible via main road public utility routes and ride-hailing services.',
      },
      {
        'icon': Icons.phone_rounded,
        'color': AppColors.accent,
        'title': 'Front Desk & Reception',
        'content': '+63 (02) 8888-GYM / +63 917 123 4567',
        'detail': 'Customer service hotline active daily between 8:00 AM and 11:00 PM for attendance, plan activations, and coach queries.',
      },
      {
        'icon': Icons.email_rounded,
        'color': Colors.purpleAccent,
        'title': 'Email & Online Support',
        'content': 'support@viciousfitness.ph',
        'detail': 'Send us inquiries anytime regarding corporate packages, membership transfers, or coach applications.',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 680;
        final cardWidth = isDesktop ? ((constraints.maxWidth - 16) / 2).floorToDouble() : constraints.maxWidth;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards.map((c) {
            final icon = c['icon'] as IconData;
            final color = c['color'] as Color;
            final title = c['title'] as String;
            final content = c['content'] as String;
            final detail = c['detail'] as String;

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
                      content,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      detail,
                      style: TextStyle(
                        color: context.subtitleColor,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildHouseRulesSection(BuildContext context) {
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
              const Icon(Icons.rule_folder_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Gym Attendance & Member Guidelines',
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
            '1. Member Check-in: Please present your Digital Member Pass at the front desk reception terminal upon entering.\n'
            '2. Time In / Time Out: All attendance is logged and verified at the front reception counter.\n'
            '3. Operating Window: Floor access is open 8:00 AM – 11:00 PM Daily. Members must conclude workouts by 11:00 PM.\n'
            '4. Attire: Clean indoor athletic shoes and workout clothes required. No slippers or denim on the gym floor.\n'
            '5. Cleanliness: Wipe down machines after use and return all free weights to their assigned racks.',
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
            'Come Visit Us Today',
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
            'Our reception desk is staffed daily from 8:00 AM to 11:00 PM to assist with membership inquiries and facility tours.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFB0BAC9),
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.push(AppRoutes.register),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Register Online Now', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
