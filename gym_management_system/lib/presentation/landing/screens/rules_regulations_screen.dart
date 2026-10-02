import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../widgets/public_app_bar.dart';

class RulesRegulationsScreen extends StatelessWidget {
  const RulesRegulationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: const PublicAppBar(
        currentRoute: AppRoutes.publicRules,
        showBackButton: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Main Banner / Header matching poster
                  _buildPosterHeader(context),
                  const SizedBox(height: 32),

                  // 2-Column Poster Layout on Desktop, 1-Column on Mobile
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth >= 850;

                      if (isDesktop) {
                        return _buildDesktopGrid(context);
                      } else {
                        return _buildMobileList(context);
                      }
                    },
                  ),
                  const SizedBox(height: 40),

                  // Bottom Commitment / Disclaimer Card
                  _buildFooterNotice(context),
                  const SizedBox(height: 32),

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

  // --- POSTER HEADER ---
  Widget _buildPosterHeader(BuildContext context) {
    return Column(
      children: [
        // Brand Snake Logo
        Container(
          width: 72,
          height: 72,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/vicious_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.fitness_center_rounded,
              color: AppColors.primary,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Subtitle brand badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: context.elevatedSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderLine),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.shield_rounded, color: AppColors.primary, size: 14),
                SizedBox(width: 6),
                Text(
                  'VICIOUS GAINS HYBRID GYM',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Big Poster Heading
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'GYM RULES AND REGULATIONS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.titleColor,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Text(
            'To ensure a safe, disciplined, and supportive training environment for all athletes and guests, everyone inside the facility must uphold the following code of conduct.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.subtitleColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // --- DESKTOP 2-COLUMN LAYOUT (With Central Divider Line) ---
  Widget _buildDesktopGrid(BuildContext context) {
    final leftRules = _allRules.sublist(0, 5);
    final rightRules = _allRules.sublist(5, 10);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.borderLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (Rules 1 to 5)
            Expanded(
              child: Column(
                children: [
                  for (int i = 0; i < leftRules.length; i++) ...[
                    _buildRuleCard(context, leftRules[i]),
                    if (i < leftRules.length - 1) const SizedBox(height: 20),
                  ],
                ],
              ),
            ),

            // Center Glowing Neon Divider Line
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.1),
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
            ),

            // Right Column (Rules 6 to 10)
            Expanded(
              child: Column(
                children: [
                  for (int i = 0; i < rightRules.length; i++) ...[
                    _buildRuleCard(context, rightRules[i]),
                    if (i < rightRules.length - 1) const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MOBILE SINGLE COLUMN LIST ---
  Widget _buildMobileList(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < _allRules.length; i++) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderLine),
            ),
            child: _buildRuleCard(context, _allRules[i]),
          ),
          if (i < _allRules.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  // --- RULE CARD ITEM ---
  Widget _buildRuleCard(BuildContext context, _GymRule rule) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rule Header with Icon and Title
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: rule.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: rule.color.withValues(alpha: 0.4)),
              ),
              child: Icon(rule.icon, color: rule.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${rule.number}. ${rule.title}',
                style: TextStyle(
                  color: rule.color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Bullets
        for (final bullet in rule.bullets) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: rule.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    bullet,
                    style: TextStyle(
                      color: context.titleColor.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- FOOTER NOTICE ---
  Widget _buildFooterNotice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zero Tolerance on Misconduct & Safety Violations',
                  style: TextStyle(
                    color: context.titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vicious Fitness reserves the right to suspend or revoke membership privileges without refund for repeated failure to comply with safety and etiquette standards.',
                  style: TextStyle(
                    color: context.subtitleColor,
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
  }

  // --- CTA BANNER ---
  Widget _buildCtaBanner(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isNarrow ? 18 : 28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.15),
                AppColors.accentCyan.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Ready to Train Responsibly?',
                  style: TextStyle(
                    fontSize: isNarrow ? 18 : 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Join our community of athletes and dedicated fitness enthusiasts today.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.subtitleColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.register),
                    icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.black),
                    label: const Text('Join Vicious Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.login),
                    icon: const Icon(Icons.login_rounded, size: 16, color: AppColors.primary),
                    label: const Text('Member Portal Login', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Data class representing each numbered rule
class _GymRule {
  final int number;
  final String title;
  final IconData icon;
  final Color color;
  final List<String> bullets;

  const _GymRule({
    required this.number,
    required this.title,
    required this.icon,
    required this.color,
    required this.bullets,
  });
}

// 10 Official Rules exactly matching the Vicious Gains poster
final List<_GymRule> _allRules = [
  const _GymRule(
    number: 1,
    title: 'GENERAL CONDUCT',
    icon: Icons.sports_kabaddi_rounded,
    color: Color(0xFFFF9100), // Orange / Gold
    bullets: [
      'RESPECT EVERYONE. NO HARASSMENT, DISCRIMINATION, OR AGGRESSIVE BEHAVIOR.',
      'FOLLOW STAFF INSTRUCTIONS AT ALL TIMES.',
      'KEEP NOISE AT A REASONABLE LEVEL; AVOID UNNECESSARY SHOUTING OR SLAMMING WEIGHTS.',
    ],
  ),
  const _GymRule(
    number: 2,
    title: 'ATTIRE & HYGIENE',
    icon: Icons.checkroom_rounded,
    color: Color(0xFF00E676), // Neon Green
    bullets: [
      'WEAR PROPER GYM ATTIRE AND FOOTWEAR AT ALL TIMES. NO WEARING OF SLIPPERS; ONLY CLOSED-TOE FOOTWEAR.',
      'IT IS ADVISABLE TO BRING A TOWEL.',
      'WIPE DOWN EQUIPMENT AFTER EVERY USE.',
      'MAINTAIN GOOD PERSONAL HYGIENE FOR THE COMFORT OF EVERYONE.',
    ],
  ),
  const _GymRule(
    number: 3,
    title: 'EQUIPMENT USE & SAFETY',
    icon: Icons.fitness_center_rounded,
    color: Color(0xFF00E676), // Neon Green
    bullets: [
      'RE-RACK WEIGHTS AFTER USE.',
      'RETURN ITEMS AND ACCESSORIES TO THEIR DESIGNATED AREAS.',
      'DO NOT DROP OR SLAM WEIGHTS UNNECESSARILY.',
    ],
  ),
  const _GymRule(
    number: 4,
    title: 'RESTRICTIONS',
    icon: Icons.block_rounded,
    color: Color(0xFFFF5252), // Red / Restrictions
    bullets: [
      'NO OUTSIDE COACHING OR UNAUTHORIZED PERSONAL TRAINING.',
      'NO SMOKING, VAPING, OR ALCOHOL INSIDE THE GYM.',
      'NO CHILDREN ON THE GYM FLOOR UNLESS PART OF AN OFFICIAL PROGRAM.',
    ],
  ),
  const _GymRule(
    number: 5,
    title: 'BAGS & PERSONAL BELONGINGS',
    icon: Icons.backpack_rounded,
    color: Color(0xFF69F0AE), // Light Green
    bullets: [
      'STORE BAGS ONLY IN DESIGNATED AREAS OR LOCKERS.',
      'THE GYM IS NOT RESPONSIBLE FOR LOST OR STOLEN ITEMS.',
      'DO NOT LEAVE PERSONAL ITEMS LYING AROUND THE FLOOR OR EQUIPMENT.',
    ],
  ),
  const _GymRule(
    number: 6,
    title: 'TIME & SPACE ETIQUETTE',
    icon: Icons.hourglass_top_rounded,
    color: Color(0xFFFFD700), // Gold / Amber
    bullets: [
      'LIMIT MACHINE USE TO 10 MINUTES DURING PEAK HOURS.',
      'SHARE EQUIPMENT AND ALLOW “SHARING IN” WHEN POSSIBLE.',
      'DO NOT OCCUPY BENCHES OR MACHINES WHILE ON YOUR PHONE.',
    ],
  ),
  const _GymRule(
    number: 7,
    title: 'COMBAT SPORTS AREA',
    icon: Icons.sports_mma_rounded,
    color: Color(0xFFFF1744), // Crimson Red
    bullets: [
      'WEAR HAND WRAPS AND PROPER GEAR FOR BOXING/KICKBOXING SESSIONS.',
      'SPARRING IS ALLOWED ONLY WITH COACH SUPERVISION.',
      'KEEP THE MATS CLEAN; NO SHOES ON THE MAT UNLESS REQUIRED.',
      'DO NOT KICK THE HEAVY BAG WITH SHOES ON.',
    ],
  ),
  const _GymRule(
    number: 8,
    title: 'CLEANLINESS',
    icon: Icons.sanitizer_rounded,
    color: Color(0xFFFF4081), // Pink / Cleanliness
    bullets: [
      'DISPOSE OF TRASH PROPERLY.',
      'RETURN SPRAY BOTTLES AND TOWELS AFTER USE.',
      'KEEP RESTROOMS AND SHOWERS TIDY FOR THE NEXT PERSON.',
    ],
  ),
  const _GymRule(
    number: 9,
    title: 'MEMBERSHIP & ACCESS',
    icon: Icons.groups_rounded,
    color: Color(0xFF00E5FF), // Cyan / Access
    bullets: [
      'MEMBERS MUST CHECK IN UPON ENTERING.',
      'SHARING ACCESS OR LETTING OTHERS IN WITHOUT PERMISSION IS PROHIBITED.',
      'MEMBERSHIP FEES MUST BE SETTLED ON TIME TO MAINTAIN ACCESS.',
    ],
  ),
  const _GymRule(
    number: 10,
    title: 'RESPECT THE SPACE',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFF6D00), // Fire Orange
    bullets: [
      'TAKE CARE OF EQUIPMENT AND FACILITIES AS IF THEY WERE YOUR OWN.',
      'HELP MAINTAIN A POSITIVE, SUPPORTIVE TRAINING ENVIRONMENT.',
      'TRAIN HARD—BUT TRAIN RESPONSIBLY.',
    ],
  ),
];
