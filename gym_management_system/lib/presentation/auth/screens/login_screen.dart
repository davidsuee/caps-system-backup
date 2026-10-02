import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/user_entity.dart';
import '../../coach/providers/coach_provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    final user = await ref.read(authNotifierProvider.notifier).login(email, password);

    if (user != null && mounted) {
      // Role-Based Access Control (RBAC) automatic navigation
      switch (user.role) {
        case UserRole.member:
          context.go(AppRoutes.memberDashboard);
          break;
        case UserRole.coach:
          await ref.read(coachNotifierProvider.notifier).loadDashboard(user.id);
          if (mounted) context.go(AppRoutes.coachDashboard);
          break;
        case UserRole.admin:
          context.go(AppRoutes.adminDashboard);
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Logo & Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.arrow_back_rounded, color: context.titleColor),
                            tooltip: 'Back to Vicious Fitness',
                            onPressed: () {
                              if (Navigator.of(context).canPop()) {
                                context.pop();
                              } else {
                                context.go(AppRoutes.welcome);
                              }
                            },
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Image.asset(
                              'assets/images/vicious_logo.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center, color: AppColors.primary, size: 26),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VICIOUS',
                                  style: TextStyle(
                                    color: context.titleColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Text(
                                  'Gym & Recommendation Platform',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.subtitleColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ThemeToggleButton(),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.home_outlined, color: AppColors.primary),
                          tooltip: 'Vicious Fitness Home',
                          onPressed: () => context.go(AppRoutes.welcome),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                Text(
                  'Sign In',
                  style: TextStyle(
                    color: context.titleColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Welcome back! Enter your credentials to access your account.',
                  style: TextStyle(
                    color: context.subtitleColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                if (authState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            authState.errorMessage!,
                            style: const TextStyle(color: AppColors.error, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                CustomTextField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  label: 'Email Address',
                  hint: 'name@example.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  validator: Validators.email,
                  suffixIcon: _emailController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                          onPressed: () {
                            _emailController.clear();
                          },
                        )
                      : null,
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  label: 'Password',
                  hint: 'Enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  validator: Validators.loginPassword,
                  onFieldSubmitted: (_) => _handleLogin(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),

                const SizedBox(height: 32),
                CustomButton(
                  text: 'Sign In',
                  isLoading: authState.isLoading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TextStyle(color: context.subtitleColor, fontSize: 14),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => context.push(AppRoutes.register),
                        child: const Text(
                          'Create an Account',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Quick Demo Login (One-Tap Access)
                _buildQuickDemoLogins(context),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _loginAsDemo(String email) {
    _emailController.text = email;
    _passwordController.text = 'password123';
    _handleLogin();
  }

  Widget _buildQuickDemoLogins(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'Demo Quick Access (One-Tap Sign In)',
                style: TextStyle(
                  color: context.titleColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap any role below to automatically sign in for testing or defense:',
            style: TextStyle(color: context.subtitleColor, fontSize: 11),
          ),
          const SizedBox(height: 12),
          _buildDemoChip(
            context: context,
            roleTitle: 'Coach / Trainer',
            name: 'Coach Marcus Vance',
            email: 'coach@gym.com',
            icon: Icons.fitness_center_rounded,
            color: AppColors.accent,
          ),
          const SizedBox(height: 8),
          _buildDemoChip(
            context: context,
            roleTitle: 'Gym Administrator',
            name: 'Admin Sarah Connor',
            email: 'staff@gym.com',
            icon: Icons.admin_panel_settings_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _buildDemoChip(
            context: context,
            roleTitle: 'Gym Member',
            name: 'Sarah Jenkins',
            email: 'sarah.j@example.com',
            icon: Icons.person_rounded,
            color: Colors.tealAccent,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.elevatedSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.borderLine),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Coach accounts are provisioned exclusively by Gym Administrators.',
                    style: TextStyle(color: context.subtitleColor, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoChip({
    required BuildContext context,
    required String roleTitle,
    required String name,
    required String email,
    required IconData icon,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _loginAsDemo(email),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          roleTitle,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• $name',
                          style: TextStyle(
                            color: context.titleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
