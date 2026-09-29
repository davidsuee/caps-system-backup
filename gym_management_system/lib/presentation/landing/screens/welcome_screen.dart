import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/custom_button.dart';
import '../../admin/providers/facility_provider.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityState = ref.watch(facilityNotifierProvider);
    final facilities = facilityState.facilities;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Dynamic App Bar
          SliverAppBar(
            backgroundColor: AppColors.surface,
            floating: true,
            pinned: true,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 22),
                ),
              ),
            ),
            title: const Row(
              children: [
                Text(
                  'VISCIOUS',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'FITNESS',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () => context.push(AppRoutes.login),
                icon: const Icon(Icons.login_rounded, size: 16, color: AppColors.primary),
                label: const Text(
                  'Sign In',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Main Landing Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HERO SECTION ---
                  _buildHeroSection(context),
                  const SizedBox(height: 32),

                  // --- AI & OPTIMIZATION HIGHLIGHTS ---
                  _buildSectionHeader('Smart Gym Technology', 'Powered by Machine Learning & Linear Optimization'),
                  const SizedBox(height: 14),
                  _buildTechHighlights(),
                  const SizedBox(height: 32),

                  // --- AMENITIES & LIVE ZONES ---
                  _buildSectionHeader('Gym Amenities & Zones', 'Real-time crowd occupancy & training spaces'),
                  const SizedBox(height: 14),
                  _buildAmenitiesSection(facilities),
                  const SizedBox(height: 32),

                  // --- MEMBERSHIP PLANS ---
                  _buildSectionHeader('Membership Plans', 'Flexible access tailored for every fitness milestone'),
                  const SizedBox(height: 14),
                  _buildMembershipTiers(context),
                  const SizedBox(height: 32),

                  // --- FOOTER & CONTACT ---
                  _buildFooter(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // --- HERO SECTION ---
  Widget _buildHeroSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceLight,
            AppColors.surface,
            AppColors.primary.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
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
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unleash Your Ultimate Potential at Viscious Fitness',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The first intelligent gym management platform combining Machine Learning workout recommendations, Linear Programming nutrition planning, and automated coach workload balancing.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Join Viscious Now',
                  icon: Icons.person_add_rounded,
                  onPressed: () => context.push(AppRoutes.register),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'Portal Login',
                  icon: Icons.login_rounded,
                  isOutlined: true,
                  onPressed: () => context.push(AppRoutes.login),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SMART TECH HIGHLIGHTS ---
  Widget _buildTechHighlights() {
    final highlights = [
      {
        'icon': Icons.psychology_rounded,
        'color': AppColors.primary,
        'title': 'ML Workout Recommender',
        'desc': 'Random Forest algorithm selects exercises tailored to your BMI, fitness goals, and strength level.',
      },
      {
        'icon': Icons.restaurant_menu_rounded,
        'color': AppColors.accentCyan,
        'title': 'LP Meal Plan Optimizer',
        'desc': 'Linear Programming solver constructs balanced meal combinations meeting exact calorie and macro targets.',
      },
      {
        'icon': Icons.swap_horiz_rounded,
        'color': AppColors.accent,
        'title': 'Automated Coach Balancing',
        'desc': 'Intelligent allocation matches members to certified trainers based on discipline and capacity.',
      },
      {
        'icon': Icons.qr_code_scanner_rounded,
        'color': Colors.purpleAccent,
        'title': 'Digital Attendance & Out',
        'desc': 'Complete TimeIn and TimeOut check-out lifecycle with live active member session tracking.',
      },
    ];

    return Column(
      children: highlights.map((h) {
        final color = h['color'] as Color;
        final icon = h['icon'] as IconData;
        final title = h['title'] as String;
        final desc = h['desc'] as String;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- AMENITIES & LIVE ZONES ---
  Widget _buildAmenitiesSection(dynamic facilities) {
    final defaultZones = [
      {'name': 'Cardio Deck', 'desc': 'Treadmills, Rowers, Assault Bikes', 'rate': 0.45, 'status': 'Open'},
      {'name': 'Free Weights Area', 'desc': 'Olympic Bars, Dumbbells to 50kg, Squat Cages', 'rate': 0.65, 'status': 'Open'},
      {'name': 'Functional Turf Studio', 'desc': 'Sled Tracks, Kettlebells, Battle Ropes', 'rate': 0.30, 'status': 'Open'},
      {'name': 'Group Fitness Hall', 'desc': 'HIIT, Yoga, Aerobics, and Stretching', 'rate': 0.20, 'status': 'Open'},
    ];

    return Column(
      children: defaultZones.map((z) {
        final name = z['name'] as String;
        final desc = z['desc'] as String;
        final rate = z['rate'] as double;
        final status = z['status'] as String;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Live Density', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  Text(
                    '${(rate * 100).toInt()}% Capacity',
                    style: const TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- MEMBERSHIP TIERS ---
  Widget _buildMembershipTiers(BuildContext context) {
    final tiers = [
      {
        'title': 'Day Pass',
        'price': '₱150',
        'priceVal': 150.0,
        'days': 1,
        'duration': '1 Day Access',
        'popular': false,
        'features': [
          'Full access to all facility zones',
          'Locker & shower amenities',
          'Digital attendance check-in/out',
        ],
      },
      {
        'title': 'Monthly Basic',
        'price': '₱1,200',
        'priceVal': 1200.0,
        'days': 30,
        'duration': '30 Days Access',
        'popular': true,
        'features': [
          'Unlimited gym entry all hours',
          'AI-Powered Workout Recommender',
          'Progress & weigh-in log tracking',
          'Standard equipment orientation',
        ],
      },
      {
        'title': 'Quarterly Pro',
        'price': '₱3,200',
        'priceVal': 3200.0,
        'days': 90,
        'duration': '90 Days Access',
        'popular': false,
        'features': [
          'All Monthly Basic benefits',
          'PuLP Linear Optimization Meal Plans',
          'Assigned Dedicated Fitness Coach',
          'Bi-weekly progress evaluation',
        ],
      },
      {
        'title': 'Annual VIP',
        'price': '₱10,800',
        'priceVal': 10800.0,
        'days': 365,
        'duration': '365 Days Access',
        'popular': false,
        'features': [
          'Full VIP gym privileges 365 days',
          'Priority coach session booking',
          'Personalized AI training & diet regimes',
          '2 Free Guest Day Passes / month',
        ],
      },
    ];

    return Column(
      children: tiers.map((t) {
        final title = t['title'] as String;
        final price = t['price'] as String;
        final duration = t['duration'] as String;
        final popular = t['popular'] as bool;
        final features = t['features'] as List<String>;
        final priceVal = (t['priceVal'] as num?)?.toDouble() ?? 1200.0;
        final daysVal = (t['days'] as num?)?.toInt() ?? 30;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: popular ? AppColors.primary : AppColors.border,
              width: popular ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        duration,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  if (popular)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'MOST POPULAR',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '/${duration.split(' ').first}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 14),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            f,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Select Plan & Register',
                  isOutlined: true,
                  onPressed: () {
                    context.push(
                      Uri(
                        path: AppRoutes.register,
                        queryParameters: {
                          'plan': title,
                          'price': priceVal.toString(),
                          'days': daysVal.toString(),
                        },
                      ).toString(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- FOOTER & CONTACT ---
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Viscious Fitness Gym Location',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Caloocan City, Metro Manila\n(In collaboration with Global Reciprocal Colleges - BSIT Capstone)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: AppColors.accentCyan, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Operating Hours: 6:00 AM – 10:00 PM Daily',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.login),
                  icon: const Icon(Icons.badge_rounded, size: 16, color: AppColors.accent),
                  label: const Text('Staff & Admin Portal', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
