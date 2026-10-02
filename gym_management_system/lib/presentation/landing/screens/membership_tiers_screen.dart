import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/membership_plans.dart';
import '../widgets/public_app_bar.dart';

class MembershipTiersScreen extends StatelessWidget {
  const MembershipTiersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: const PublicAppBar(
        currentRoute: AppRoutes.publicMemberships,
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

                  // Cash Counter Note
                  _buildCashCounterNotice(context),
                  const SizedBox(height: 20),

                  // Membership Tiers Grid
                  _buildTiersGrid(context),
                  const SizedBox(height: 36),

                  // Membership FAQ Section
                  _buildFaqSection(context),
                  const SizedBox(height: 36),

                  // Call to Action
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
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.card_membership_rounded, color: AppColors.accent, size: 14),
              SizedBox(width: 6),
              Text(
                'TRANSPARENT PRICING • NO HIDDEN FEES',
                style: TextStyle(
                  color: AppColors.accent,
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
          'Membership Plans',
          style: TextStyle(
            color: context.titleColor,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Flexible gym access designed for every fitness milestone. No lock-in contracts or initiation fees. Choose a plan and begin your transformation today.',
          style: TextStyle(
            color: context.subtitleColor,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCashCounterNotice(BuildContext context) {
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
            child: const Icon(Icons.payments_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Counter Payment Process',
                  style: TextStyle(
                    color: context.titleColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Register online below, then pay cash directly at the gym reception desk (8:00 AM – 11:00 PM) for immediate activation.',
                  style: TextStyle(
                    color: context.subtitleColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildTiersGrid(BuildContext context) {
    final isDark = context.isDark;

    final tiers = kViciousMembershipPlans.map((p) => {
      'title': p.name,
      'price': p.priceString,
      'unit': '/ ${p.durationLabel}',
      'priceNumeric': p.price,
      'days': p.days,
      'tag': p.badgeText ?? (p.isPopular ? 'MOST POPULAR' : (p.hasCoach ? 'INCLUDES COACH' : 'NO WALK-IN FEE')),
      'isPopular': p.isPopular,
      'color': p.accentColor,
      'desc': p.description,
      'perks': p.features,
    }).toList();

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
          children: tiers.map((tier) {
            final title = tier['title'] as String;
            final price = tier['price'] as String;
            final unit = tier['unit'] as String;
            final priceNumeric = tier['priceNumeric'] as double;
            final days = tier['days'] as int;
            final tag = tier['tag'] as String;
            final isPopular = tier['isPopular'] as bool;
            final color = tier['color'] as Color;
            final desc = tier['desc'] as String;
            final perks = tier['perks'] as List<String>;

            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPopular ? AppColors.accent : (isDark ? AppColors.border : const Color(0xFFE2E8F0)),
                    width: isPopular ? 2.0 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isPopular
                          ? AppColors.accent.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: isPopular ? 18 : 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                        if (isPopular)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'HOT',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            color: context.titleColor,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          style: TextStyle(
                            color: context.subtitleColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      desc,
                      style: TextStyle(
                        color: context.subtitleColor,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(height: 1, color: isDark ? AppColors.border : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 14),
                    ...perks.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_rounded, color: color, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p,
                                  style: TextStyle(
                                    color: context.titleColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final uri = Uri(
                            path: AppRoutes.register,
                            queryParameters: {
                              'plan': title,
                              'price': priceNumeric.toString(),
                              'days': days.toString(),
                            },
                          );
                          context.push(uri.toString());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPopular ? AppColors.accent : (isDark ? AppColors.surfaceLight : const Color(0xFFF1F5F9)),
                          foregroundColor: isPopular ? Colors.black : context.titleColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: isPopular
                                ? BorderSide.none
                                : BorderSide(color: isDark ? AppColors.border : const Color(0xFFCBD5E1)),
                          ),
                        ),
                        child: Text(
                          'Select Plan',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isPopular ? Colors.black : context.titleColor,
                          ),
                        ),
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

  Widget _buildFaqSection(BuildContext context) {
    final isDark = context.isDark;

    final faqs = [
      {
        'q': 'How do I activate and pay for my membership?',
        'a': 'Select any plan above and complete your registration. Then simply walk into the gym reception desk during operating hours (8:00 AM to 11:00 PM) to pay cash. The front desk staff will instantly verify and activate your pass.',
      },
      {
        'q': 'Can I schedule 1-on-1 sessions with a coach?',
        'a': 'Yes! Active members are paired with certified coaches who have open capacity (max 20 clients per coach). Training sessions can be booked directly in the app between 8:00 AM and 11:00 PM.',
      },
      {
        'q': 'Are there any hidden fees or cancellation penalties?',
        'a': 'None! We believe in 100% transparency. There are no initiation charges, annual maintenance surprises, or cancellation fees.',
      },
      {
        'q': 'What happens if I check in close to 11:00 PM?',
        'a': 'Our operating hours are strictly 8:00 AM to 11:00 PM Daily. All active member sessions are automatically checked out at 11:00 PM when the gym closes for cleaning and maintenance.',
      },
    ];

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
              const Icon(Icons.help_outline_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Frequently Asked Questions',
                style: TextStyle(
                  color: context.titleColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...faqs.map((faq) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      faq['q']!,
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      faq['a']!,
                      style: TextStyle(
                        color: context.subtitleColor,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )),
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
            'Ready to Begin Your Fitness Journey?',
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
            'Create your account now to lock in your preferred membership tier and join the Vicious community.',
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
            child: const Text('Create Member Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
