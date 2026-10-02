import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../widgets/public_app_bar.dart';

class FeaturesScreen extends StatelessWidget {
  const FeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: const PublicAppBar(
        currentRoute: AppRoutes.publicFeatures,
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
                  const SizedBox(height: 32),

                  // 3 Core Technology Deep-Dive Cards
                  _buildTechCardsGrid(context),
                  const SizedBox(height: 36),

                  // Technology Architecture Banner
                  _buildTechArchitectureBanner(context),
                  const SizedBox(height: 36),

                  // Call to Action Banner
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
              Icon(Icons.bolt_rounded, color: AppColors.primary, size: 14),
              SizedBox(width: 6),
              Text(
                'NEXT-GEN FITNESS PLATFORM',
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
          'Smart Gym Technology',
          style: TextStyle(
            color: context.titleColor,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Intelligent fitness systems designed for everyday gym members. No guesswork, no generic plans—just algorithms tailored to your body and lifestyle.',
          style: TextStyle(
            color: context.subtitleColor,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTechCardsGrid(BuildContext context) {
    final isDark = context.isDark;

    final technologies = [
      {
        'icon': Icons.fitness_center_rounded,
        'color': AppColors.primary,
        'tag': 'SMART WORKOUTS',
        'title': 'Personalized Exercise Routines',
        'subtitle': '',
        'desc':
            'Generates tailored daily workout routines based on your fitness goals, experience level, and body metrics. You always know exactly what exercises, sets, and reps to do with zero guesswork.',
        'engine': 'MACHINE LEARNING CORE',
        'benefits': [
          'Adaptive progression based on workout logs',
          'Calibrated for Beginners, Intermediates, & Athletes',
          'Intelligent muscle recovery & split schedules',
          'Exercise alternatives for busy equipment hours',
        ],
      },
      {
        'icon': Icons.restaurant_menu_rounded,
        'color': AppColors.accentCyan,
        'tag': 'PRECISION NUTRITION',
        'title': 'Smart Daily Diet & Macros',
        'subtitle': '',
        'desc':
            'Builds balanced meal plans designed around your target calories and budget. Calculates optimal macronutrients to fuel your workouts using accessible, healthy everyday foods.',
        'engine': 'LINEAR OPTIMIZATION (PuLP)',
        'benefits': [
          'Calculates exact protein, carb, & fat balance',
          'Optimized for daily Filipino grocery budgets',
          'Healthy, accessible whole food ingredients',
          'Meal-by-meal breakdown for breakfast, lunch, dinner, & snacks',
        ],
      },
      {
        'icon': Icons.groups_rounded,
        'color': AppColors.accent,
        'tag': 'DEDICATED TRAINERS',
        'title': '1-on-1 Coach Pairing',
        'subtitle': 'Goal-Based Coach Matching',
        'desc':
            'Pairs you with dedicated fitness trainers matched to your primary fitness goal. Intelligent assignment ensures your coach has the time and focus to guide you through your fitness journey.',
        'engine': 'GOAL-ALIGNED MATCHING ENGINE',
        'benefits': [
          'Goal-aligned coach matching for targeted fitness progression',
          'Direct personalized guidance & accountability',
          'Form checks, customized advice, & regular milestones',
          'Scheduled 1-on-1 training sessions directly in-app',
        ],
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final is3Col = constraints.maxWidth >= 900;
        final is2Col = constraints.maxWidth >= 600;
        final cardWidth = is3Col
            ? ((constraints.maxWidth - 32) / 3).floorToDouble()
            : (is2Col ? ((constraints.maxWidth - 16) / 2).floorToDouble() : constraints.maxWidth);

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: technologies.map((tech) {
            final icon = tech['icon'] as IconData;
            final color = tech['color'] as Color;
            final tag = tech['tag'] as String;
            final title = tech['title'] as String;
            final subtitle = tech['subtitle'] as String;
            final desc = tech['desc'] as String;
            final engine = tech['engine'] as String;
            final benefits = tech['benefits'] as List<String>;

            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: color,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      desc,
                      style: TextStyle(
                        color: context.subtitleColor,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 1,
                      color: isDark ? AppColors.border : const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'KEY ADVANTAGES',
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...benefits.map((b) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_rounded, color: color, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  b,
                                  style: TextStyle(
                                    color: context.titleColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 3,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          engine,
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
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

  Widget _buildTechArchitectureBanner(BuildContext context) {
    final isDark = context.isDark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.hub_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'End-to-End Integrated Training Engine',
                  style: TextStyle(
                    color: context.titleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Every workout routine, nutrition plan, and coach session connects into a single unified health record. Your coach can monitor your progress live and adjust variables without friction.',
                  style: TextStyle(
                    color: context.subtitleColor,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
          const Icon(Icons.rocket_launch_rounded, color: AppColors.primary, size: 36),
          const SizedBox(height: 14),
          const Text(
            'Ready to Train with Smart Technology?',
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
            'Create your member profile in minutes to unlock customized workouts and meal plans.',
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
            child: const Text(
              'Get Started Now',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
