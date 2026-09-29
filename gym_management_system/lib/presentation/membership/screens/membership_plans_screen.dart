import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../domain/entities/membership_entity.dart';
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
      appBar: AppBar(title: const Text('Membership Plans')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Current Plan / Status Card
            _buildSubscriptionStatusCard(activePlan),
            const SizedBox(height: 24),

            const Text(
              'Select Membership Tier',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select a plan below and pay in cash at the gym counter to activate.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),

            _TierCard(
              title: 'Monthly Standard',
              price: '₱1,500 / mo',
              numericPrice: 1500,
              durationDays: 30,
              description: 'Full gym floor access, locker access, and workout routines.',
              isPopular: false,
              isCurrentPlan: activePlan?.isActive == true && activePlan?.planName == 'Monthly Standard',
              isPendingPlan: activePlan?.isPending == true && activePlan?.planName == 'Monthly Standard',
              onSelect: () => _confirmCashRequest(
                context: context,
                ref: ref,
                userId: user.id,
                planName: 'Monthly Standard',
                price: 1500,
                days: 30,
              ),
            ),
            const SizedBox(height: 14),

            _TierCard(
              title: 'VIP All-Access Pass',
              price: '₱2,800 / mo',
              numericPrice: 2800,
              durationDays: 30,
              description: 'Unlimited 24/7 access, trainer consultations, PuLP LP meal generator, sauna & recovery.',
              isPopular: true,
              isCurrentPlan: activePlan?.isActive == true && activePlan?.planName == 'VIP All-Access Pass',
              isPendingPlan: activePlan?.isPending == true && activePlan?.planName == 'VIP All-Access Pass',
              onSelect: () => _confirmCashRequest(
                context: context,
                ref: ref,
                userId: user.id,
                planName: 'VIP All-Access Pass',
                price: 2800,
                days: 30,
              ),
            ),
            const SizedBox(height: 14),

            _TierCard(
              title: 'Student Semester Pass',
              price: '₱3,900 / 3 mos',
              numericPrice: 3900,
              durationDays: 90,
              description: 'Discounted multi-month plan with valid school ID verification.',
              isPopular: false,
              isCurrentPlan: activePlan?.isActive == true && activePlan?.planName == 'Student Semester Pass',
              isPendingPlan: activePlan?.isPending == true && activePlan?.planName == 'Student Semester Pass',
              onSelect: () => _confirmCashRequest(
                context: context,
                ref: ref,
                userId: user.id,
                planName: 'Student Semester Pass',
                price: 3900,
                days: 90,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionStatusCard(MembershipEntity? activePlan) {
    if (activePlan == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MEMBERSHIP STATUS',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'No Active Membership',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Select a tier below to submit your cash payment request at the counter.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
              AppColors.surface,
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
            const Text(
              'No Active Membership',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
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
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '₱${activePlan.price.toStringAsFixed(0)} Cash Due',
                        style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Please proceed to the gym counter/admin to pay cash. Your plan will only activate once confirmed by the admin.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
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
              AppColors.surface,
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
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '${activePlan.remainingDays} days remaining (Expires ${DateFormat('MMM dd, yyyy').format(activePlan.endDate)})',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
        color: AppColors.surface,
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
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a plan below to renew your gym membership access.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
      backgroundColor: AppColors.surface,
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
                      const Text(
                        'Confirm Cash Request',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
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
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.accent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your request will be submitted as PENDING. Please pay cash to the front desk admin to activate your pass.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
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
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPendingPlan
              ? AppColors.accent
              : (isPopular ? AppColors.primary : AppColors.border),
          width: isPopular || isPendingPlan ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
              ),
              if (isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'MOST POPULAR',
                    style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              if (isPendingPlan)
                Container(
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
            style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: buttonText,
            isOutlined: true,
            onPressed: isCurrentPlan ? null : onSelect,
          ),
        ],
      ),
    );
  }
}
