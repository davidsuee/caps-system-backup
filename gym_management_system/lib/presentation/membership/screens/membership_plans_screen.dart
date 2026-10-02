import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../domain/entities/membership_entity.dart';
import '../../../core/constants/membership_plans.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/membership_provider.dart';

class MembershipPlansScreen extends ConsumerWidget {
  const MembershipPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final memState = ref.watch(membershipNotifierProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final activePlan = memState.membership;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Membership Plans'),
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Current Plan / Status Card
            _buildSubscriptionStatusCard(activePlan, context),
            const SizedBox(height: 24),

            Text(
              'Select Membership Tier',
              style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Select a plan below and pay in cash at the gym counter to activate.',
              style: TextStyle(color: context.subtitleColor, fontSize: 13),
            ),
            const SizedBox(height: 18),

            ...kViciousMembershipPlans.map((plan) {
              final isCurrent = activePlan?.isActive == true && activePlan?.planName == plan.name;
              final isPending = activePlan?.isPending == true && activePlan?.planName == plan.name;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _TierCard(
                  title: plan.title,
                  price: '${plan.priceString} • ${plan.durationLabel}',
                  numericPrice: plan.price,
                  durationDays: plan.days,
                  description: plan.description,
                  features: plan.features,
                  badgeText: plan.badgeText,
                  accentColor: plan.accentColor,
                  isPopular: plan.isPopular,
                  isCurrentPlan: isCurrent,
                  isPendingPlan: isPending,
                  onSelect: () => _confirmCashRequest(
                    context: context,
                    ref: ref,
                    userId: user.id,
                    planName: plan.name,
                    price: plan.price,
                    days: plan.days,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatusCard(MembershipEntity? activePlan, BuildContext context) {
    if (activePlan == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.borderLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MEMBERSHIP STATUS',
              style: TextStyle(
                color: context.subtitleColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No Active Membership',
              style: TextStyle(
                color: context.titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a tier below to submit your cash payment request at the counter.',
              style: TextStyle(color: context.subtitleColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (activePlan.isPending) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.accent.withValues(alpha: 0.15),
              context.cardColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PENDING APPROVAL',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'WAITING FOR CASH',
                    style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'No Active Membership',
              style: TextStyle(
                color: context.titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Requested: ${activePlan.planName}',
                        style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '₱${activePlan.price.toStringAsFixed(0)} Cash Due',
                        style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Please proceed to the gym counter/admin to pay cash. Your plan will only activate once confirmed by the admin.',
                    style: TextStyle(color: context.subtitleColor, fontSize: 12, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (activePlan.isActive) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.18),
              context.cardColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ACTIVE SUBSCRIPTION',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              activePlan.planName,
              style: TextStyle(
                color: context.titleColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 16, color: context.subtitleColor),
                const SizedBox(width: 6),
                Text(
                  '${activePlan.remainingDays} days remaining (Expires ${DateFormat('MMM dd, yyyy').format(activePlan.endDate)})',
                  style: TextStyle(color: context.subtitleColor, fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Expired
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXPIRED MEMBERSHIP',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${activePlan.planName} (Expired)',
            style: TextStyle(
              color: context.titleColor,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a plan below to renew your gym membership access.',
            style: TextStyle(color: context.subtitleColor, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _confirmCashRequest({
    required BuildContext context,
    required WidgetRef ref,
    required String userId,
    required String planName,
    required double price,
    required int days,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.payments_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Confirm Cash Request',
                        style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.mutedColor),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.elevatedSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderLine),
                ),
                child: Column(
                  children: [
                    _DetailRow('Selected Plan:', planName),
                    const SizedBox(height: 8),
                    _DetailRow('Total Amount Due:', '₱${price.toStringAsFixed(0)}'),
                    const SizedBox(height: 8),
                    _DetailRow('Plan Duration:', '$days Days access'),
                    const SizedBox(height: 8),
                    const _DetailRow('Payment Option:', 'Over-the-Counter Cash'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your request will be submitted as PENDING. Please pay cash to the front desk admin to activate your pass.',
                        style: TextStyle(color: context.subtitleColor, fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Submit Cash Payment Request',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () async {
                  Navigator.pop(ctx);
                  final newPlan = MembershipEntity(
                    id: const Uuid().v4(),
                    userId: userId,
                    planName: planName,
                    price: price,
                    startDate: DateTime.now(),
                    endDate: DateTime.now().add(Duration(days: days)),
                    status: MembershipStatus.pending,
                  );

                  await ref.read(membershipNotifierProvider.notifier).requestCashPlan(newPlan);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Request submitted for $planName! Please pay ₱${price.toStringAsFixed(0)} cash at the front desk.'),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.subtitleColor, fontSize: 13)),
        Text(value, style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  final String title;
  final String price;
  final double numericPrice;
  final int durationDays;
  final String description;
  final List<String> features;
  final String? badgeText;
  final Color accentColor;
  final bool isPopular;
  final bool isCurrentPlan;
  final bool isPendingPlan;
  final VoidCallback onSelect;

  const _TierCard({
    required this.title,
    required this.price,
    required this.numericPrice,
    required this.durationDays,
    required this.description,
    this.features = const [],
    this.badgeText,
    this.accentColor = AppColors.primary,
    required this.isPopular,
    this.isCurrentPlan = false,
    this.isPendingPlan = false,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    String buttonText = 'Choose Plan & Pay Cash';
    if (isCurrentPlan) buttonText = 'Current Active Plan';
    if (isPendingPlan) buttonText = 'Request Pending (Pay Cash)';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPendingPlan
              ? AppColors.accent
              : (isPopular ? accentColor : context.borderLine),
          width: isPopular || isPendingPlan ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: context.titleColor, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.7)),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                )
              else if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'MOST POPULAR',
                    style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              if (isPendingPlan)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PENDING CASH',
                    style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            price,
            style: TextStyle(color: accentColor, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(color: context.subtitleColor, fontSize: 13, height: 1.4),
          ),
          if (features.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: context.borderLine, height: 1),
            const SizedBox(height: 10),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded, color: accentColor, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          f,
                          style: TextStyle(color: context.titleColor.withValues(alpha: 0.85), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 16),
          CustomButton(
            text: buttonText,
            isOutlined: !isPopular,
            onPressed: isCurrentPlan ? null : onSelect,
          ),
        ],
      ),
    );
  }
}

