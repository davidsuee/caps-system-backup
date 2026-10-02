import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme_provider.dart';

class ThemeToggleButton extends ConsumerWidget {
  final bool showLabel;
  final EdgeInsetsGeometry? margin;

  const ThemeToggleButton({
    super.key,
    this.showLabel = false,
    this.margin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final tooltip = isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode';
    final bgColor = isDark ? const Color(0xFF1E242C) : const Color(0xFFE2E8F0);
    final borderColor = isDark ? const Color(0xFF333C4D) : const Color(0xFFCBD5E1);
    final iconColor = isDark ? const Color(0xFFFFD54F) : const Color(0xFF334155);
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    final screenWidth = MediaQuery.of(context).size.width;
    final displayLabel = showLabel && screenWidth >= 640;

    return Tooltip(
      message: tooltip,
      child: Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
            borderRadius: BorderRadius.circular(12),
            hoverColor: isDark ? Colors.white10 : Colors.black12,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: displayLabel ? 10 : 8,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => RotationTransition(
                      turns: anim,
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      key: ValueKey<bool>(isDark),
                      size: 16,
                      color: iconColor,
                    ),
                  ),
                  if (displayLabel) ...[
                    const SizedBox(width: 6),
                    Text(
                      isDark ? 'Light' : 'Dark',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
