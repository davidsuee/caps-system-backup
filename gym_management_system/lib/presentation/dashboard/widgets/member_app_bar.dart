import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/theme_toggle_button.dart';

class MemberAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const MemberAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF141820) : Colors.white;
    final borderColor = isDark ? AppColors.border.withValues(alpha: 0.7) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? AppColors.textPrimary : const Color(0xFF0F172A);
    final subtitleColor = isDark ? AppColors.textMuted : const Color(0xFF64748B);
    final backBtnBg = isDark ? AppColors.surface : const Color(0xFFF1F5F9);
    final backBtnBorder = isDark ? AppColors.border.withValues(alpha: 0.8) : const Color(0xFFCBD5E1);
    final backIconColor = isDark ? AppColors.textPrimary : const Color(0xFF0F172A);

    return AppBar(
      backgroundColor: bgColor,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      shape: Border(
        bottom: BorderSide(
          color: borderColor,
          width: 1.0,
        ),
      ),
      leading: showBackButton
          ? Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
              child: InkWell(
                onTap: onBackPressed ?? () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(AppRoutes.memberDashboard);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: backBtnBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: backBtnBorder,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    color: backIconColor,
                    size: 18,
                  ),
                ),
              ),
            )
          : null,
      leadingWidth: showBackButton ? 56 : 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        const ThemeToggleButton(),
        if (actions != null)
          ...actions!.map((action) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: action,
              )),
        const SizedBox(width: 4),
      ],
    );
  }
}

