import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Central anti-spam floating notification system for gym compliance and user feedback.
///
/// Prevents notification queue spamming:
/// - When tapped or clicked multiple times (e.g. 5x rapid spam), it persists steadily
///   on the screen without flickering, queuing multiple alerts, or re-animating in and out.
/// - Resets the dismissal timer on every click so the notice stays visible as long as
///   the user is actively interacting.
/// - Once the user stops clicking, the banner smoothly dismisses after a short delay.
class AppFeedbackHelper {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;
  static _AppNotificationBannerState? _activeState;

  /// Display a debounced floating notice.
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    Color? color,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    final effectiveColor = color ?? AppColors.primary;
    final effectiveIcon = icon ?? Icons.info_outline_rounded;
    final effectiveTitle = title;

    // If already showing on screen, update content in-place and reset timer.
    // Does NOT trigger exit/entry animations, so it stays steady on screen.
    if (_activeEntry != null && _activeState != null && _activeState!.mounted) {
      _dismissTimer?.cancel();
      _dismissTimer = Timer(duration, () => dismiss());

      _activeState?.updateContent(
        message: message,
        title: effectiveTitle,
        color: effectiveColor,
        icon: effectiveIcon,
      );
      return;
    }

    // Dismiss any orphaned entry
    _dismissTimer?.cancel();
    _activeEntry?.remove();
    _activeEntry = null;
    _activeState = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlay == null) {
      // Fallback for safety if overlay is unavailable
      ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: effectiveColor,
          duration: duration,
        ),
      );
      return;
    }

    _activeEntry = OverlayEntry(
      builder: (ctx) => _AppNotificationBanner(
        message: message,
        title: effectiveTitle,
        color: effectiveColor,
        icon: effectiveIcon,
        onStateCreated: (state) => _activeState = state,
        onDismissRequested: dismiss,
      ),
    );

    overlay.insert(_activeEntry!);

    _dismissTimer = Timer(duration, () => dismiss());
  }

  /// Warning notice (e.g. gym facility is closed)
  static void showWarning(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    show(
      context,
      message: message,
      title: title ?? 'FACILITY CLOSED',
      color: AppColors.error,
      icon: Icons.lock_clock_rounded,
      duration: duration,
    );
  }

  /// Check-in required notice
  static void showCheckInWarning(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    show(
      context,
      message: message,
      title: title ?? 'CHECK-IN REQUIRED',
      color: Colors.amber,
      icon: Icons.how_to_reg_rounded,
      duration: duration,
    );
  }

  /// Success notice
  static void showSuccess(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    show(
      context,
      message: message,
      title: title ?? 'SUCCESS',
      color: AppColors.primary,
      icon: Icons.check_circle_rounded,
      duration: duration,
    );
  }

  /// Info notice
  static void showInfo(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    show(
      context,
      message: message,
      title: title ?? 'NOTICE',
      color: AppColors.accentCyan,
      icon: Icons.info_outline_rounded,
      duration: duration,
    );
  }

  /// Dismiss the current notice smoothly
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_activeState != null && _activeState!.mounted) {
      _activeState!.animateOut(() {
        _activeEntry?.remove();
        _activeEntry = null;
        _activeState = null;
      });
    } else {
      _activeEntry?.remove();
      _activeEntry = null;
      _activeState = null;
    }
  }
}

class _AppNotificationBanner extends StatefulWidget {
  final String message;
  final String? title;
  final Color color;
  final IconData icon;
  final ValueChanged<_AppNotificationBannerState> onStateCreated;
  final VoidCallback onDismissRequested;

  const _AppNotificationBanner({
    required this.message,
    required this.title,
    required this.color,
    required this.icon,
    required this.onStateCreated,
    required this.onDismissRequested,
  });

  @override
  State<_AppNotificationBanner> createState() => _AppNotificationBannerState();
}

class _AppNotificationBannerState extends State<_AppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  late String _message;
  late String? _title;
  late Color _color;
  late IconData _icon;

  @override
  void initState() {
    super.initState();
    _message = widget.message;
    _title = widget.title;
    _color = widget.color;
    _icon = widget.icon;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _animController.forward();
    widget.onStateCreated(this);
  }

  /// Update content in-place without triggering exit/entry transitions
  void updateContent({
    required String message,
    String? title,
    required Color color,
    required IconData icon,
  }) {
    if (!mounted) return;
    setState(() {
      _message = message;
      _title = title;
      _color = color;
      _icon = icon;
    });
  }

  void animateOut(VoidCallback onComplete) {
    if (!mounted) {
      onComplete();
      return;
    }
    _animController.reverse().then((_) {
      onComplete();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 12,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141822),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _color.withValues(alpha: 0.65),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: _color.withValues(alpha: 0.22),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon, color: _color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_title != null) ...[
                          Text(
                            _title!,
                            style: TextStyle(
                              color: _color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        Text(
                          _message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: widget.onDismissRequested,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
