import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/bmi_calculator.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/membership_entity.dart';
import '../../../data/models/membership_model.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../membership/providers/membership_provider.dart';
import '../../admin/providers/admin_provider.dart';
import '../../coach/providers/coach_provider.dart';
import '../providers/auth_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../meal/providers/meal_provider.dart';
import '../../../core/constants/membership_plans.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String? selectedPlanName;
  final double? selectedPlanPrice;
  final int? selectedPlanDays;

  const RegisterScreen({
    super.key,
    this.selectedPlanName,
    this.selectedPlanPrice,
    this.selectedPlanDays,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  // Step control (0: Account Credentials, 1: Biometrics & Goals, 2: Membership Plan)
  int _currentStep = 0;

  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  bool _obscurePassword = true;
  bool _emailAlreadyInUse = false;
  bool _isCheckingEmail = false;
  String? _gender;
  String _fitnessGoal = 'Muscle Gain';
  String _activityLevel = 'Moderately Active';
  String _experienceLevel = 'Beginner';

  late String? _chosenPlanName;
  late double? _chosenPlanPrice;
  late int? _chosenPlanDays;

  final _scrollController = ScrollController();

  static final List<Map<String, dynamic>> _membershipTiers = kViciousMembershipPlans.map((p) => {
    'name': p.name,
    'title': p.title,
    'price': p.priceString,
    'priceVal': p.price,
    'days': p.days,
    'duration': p.durationLabel,
    'icon': p.icon,
    'popular': p.isPopular,
    'badgeText': p.badgeText,
    'accentColor': p.accentColor,
    'features': p.features,
  }).toList();

  final List<Map<String, dynamic>> _goalOptions = [
    {'title': 'Muscle Gain', 'subtitle': 'Hypertrophy & Strength', 'icon': Icons.fitness_center_rounded},
    {'title': 'Weight Loss', 'subtitle': 'Caloric Deficit & Fat Burn', 'icon': Icons.local_fire_department_rounded},
    {'title': 'Improve Endurance', 'subtitle': 'Stamina & Cardio Conditioning', 'icon': Icons.directions_run_rounded},
    {'title': 'General Fitness', 'subtitle': 'Overall Mobility & Health', 'icon': Icons.self_improvement_rounded},
  ];

  final List<String> _activities = ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'];
  final List<String> _experiences = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _chosenPlanName = widget.selectedPlanName;
    if (_chosenPlanName != null) {
      final matching = _membershipTiers.firstWhere(
        (p) =>
            (p['title'] as String).toLowerCase() == _chosenPlanName!.toLowerCase() ||
            (p['name'] as String).toLowerCase() == _chosenPlanName!.toLowerCase(),
        orElse: () => {},
      );
      _chosenPlanPrice = widget.selectedPlanPrice ?? (matching['priceVal'] as num?)?.toDouble() ?? 1400.0;
      _chosenPlanDays = widget.selectedPlanDays ?? (matching['days'] as num?)?.toInt() ?? 30;
    } else {
      _chosenPlanName = null;
      _chosenPlanPrice = null;
      _chosenPlanDays = null;
    }

    _heightController.addListener(_onBiometricsChanged);
    _weightController.addListener(_onBiometricsChanged);
    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onBiometricsChanged() {
    setState(() {});
  }

  void _onPasswordChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _heightController.removeListener(_onBiometricsChanged);
    _weightController.removeListener(_onBiometricsChanged);
    _emailController.removeListener(_onEmailChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  double? get _computedBmi {
    final h = double.tryParse(_heightController.text.trim());
    final w = double.tryParse(_weightController.text.trim());
    if (h != null && w != null && h >= 80 && h <= 250 && w >= 25 && w <= 300) {
      return BmiCalculator.calculateBmi(w, h);
    }
    return null;
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onEmailChanged() {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || Validators.email(email) != null) {
      if (_emailAlreadyInUse) {
        setState(() => _emailAlreadyInUse = false);
      }
      return;
    }
    _checkEmailAvailability(email);
  }

  void _checkEmailAvailability(String email) {
    setState(() => _isCheckingEmail = true);
    final existingUser = LocalCacheService().getUserByEmail(email);
    if (mounted) {
      setState(() {
        _emailAlreadyInUse = existingUser != null;
        _isCheckingEmail = false;
      });
    }
  }

  bool _validateStep1() {
    if (_step1FormKey.currentState != null) {
      final valid = _step1FormKey.currentState!.validate();
      if (!valid) return false;
    }
    final nameError = Validators.fullName(_nameController.text.trim());
    if (nameError != null) {
      _showErrorSnackbar(nameError);
      return false;
    }
    final emailError = Validators.email(_emailController.text.trim());
    if (emailError != null) {
      _showErrorSnackbar(emailError);
      return false;
    }
    // Block proceeding if email is already registered
    if (_emailAlreadyInUse) {
      _showErrorSnackbar('This email address is already registered. Please use a different email.');
      return false;
    }
    final passwordError = Validators.password(_passwordController.text.trim());
    if (passwordError != null) {
      _showErrorSnackbar(passwordError);
      return false;
    }
    return true;
  }

  bool _isNavigatingStep = false;

  void _proceedToStep2() {
    if (_isNavigatingStep) return;
    if (_validateStep1()) {
      _isNavigatingStep = true;
      setState(() => _currentStep = 1);
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      Future.delayed(const Duration(milliseconds: 350), () {
        _isNavigatingStep = false;
      });
    }
  }

  void _proceedToStep3() {
    if (_isNavigatingStep) return;
    if (_validateStep2()) {
      _isNavigatingStep = true;
      setState(() => _currentStep = 2);
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      Future.delayed(const Duration(milliseconds: 350), () {
        _isNavigatingStep = false;
      });
    }
  }

  bool _validateStep2() {
    if (_step2FormKey.currentState != null) {
      final valid = _step2FormKey.currentState!.validate();
      if (!valid) return false;
    }
    final ageText = _ageController.text.trim();
    final age = int.tryParse(ageText);
    if (age == null || age < 10 || age > 120) {
      _showErrorSnackbar('Please enter a valid age between 10 and 120.');
      return false;
    }
    if (_gender == null) {
      _showErrorSnackbar('Please select your gender (Male or Female).');
      return false;
    }
    final heightText = _heightController.text.trim();
    final height = double.tryParse(heightText);
    if (height == null || height < 80 || height > 250) {
      _showErrorSnackbar('Please enter a valid height in cm (80-250 cm).');
      return false;
    }
    final weightText = _weightController.text.trim();
    final weight = double.tryParse(weightText);
    if (weight == null || weight < 25 || weight > 300) {
      _showErrorSnackbar('Please enter a valid weight in kg (25-300 kg).');
      return false;
    }
    return true;
  }

  void _goToStep(int targetStep) {
    if (targetStep == _currentStep) return;
    if (targetStep < _currentStep) {
      setState(() => _currentStep = targetStep);
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      return;
    }
    if (targetStep == 1) {
      if (_validateStep1()) {
        setState(() => _currentStep = 1);
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    } else if (targetStep == 2) {
      if (_validateStep1() && _validateStep2()) {
        setState(() => _currentStep = 2);
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (ref.read(authNotifierProvider).isLoading) return;
    if (!_validateStep1()) {
      setState(() => _currentStep = 0);
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      return;
    }

    if (!_validateStep2()) {
      setState(() => _currentStep = 1);
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      return;
    }

    if (_chosenPlanName == null) {
      _showErrorSnackbar('Please select a membership plan to complete registration.');
      setState(() => _currentStep = 2);
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      return;
    }

    final user = await ref.read(authNotifierProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          role: UserRole.member,
          age: int.tryParse(_ageController.text.trim()) ?? 20,
          heightCm: double.tryParse(_heightController.text.trim()) ?? 170.0,
          weightKg: double.tryParse(_weightController.text.trim()) ?? 65.0,
          gender: _gender!,
          fitnessGoal: _fitnessGoal,
          activityLevel: _activityLevel,
          experienceLevel: _experienceLevel,
        );

    if (user != null && mounted) {
      if (_chosenPlanName != null && _chosenPlanPrice != null) {
        final days = _chosenPlanDays ?? 30;
        final newPlan = MembershipEntity(
          id: const Uuid().v4(),
          userId: user.id,
          planName: _chosenPlanName!,
          price: _chosenPlanPrice!,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(Duration(days: days)),
          status: MembershipStatus.pending,
        );

        await ref.read(membershipNotifierProvider.notifier).requestCashPlan(newPlan);

        final model = MembershipModel(
          id: newPlan.id,
          userId: newPlan.userId,
          planName: newPlan.planName,
          price: newPlan.price,
          startDate: newPlan.startDate,
          endDate: newPlan.endDate,
          status: newPlan.status,
        );
        LocalCacheService().saveMembership(model);
      }

      try {
        ref.read(adminNotifierProvider.notifier).loadDashboard();
        ref.read(coachNotifierProvider.notifier).loadDashboard();
      } catch (_) {}

      try {
        await ref.read(workoutNotifierProvider.notifier).generatePlan(user);
        final bmr = BmiCalculator.calculateBmr(
          weightKg: user.weightKg,
          heightCm: user.heightCm,
          age: user.age,
          gender: user.gender,
        );
        final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: user.activityLevel);
        final tCal = BmiCalculator.calculateTargetCalories(
          tdee: tdee,
          fitnessGoal: user.fitnessGoal,
          bmi: user.bmi,
        );
        final macros = BmiCalculator.calculateTargetMacros(targetCalories: tCal, fitnessGoal: user.fitnessGoal);
        await ref.read(mealNotifierProvider.notifier).generateMealPlan(
          user: user,
          targetCalories: tCal,
          targetProtein: macros.protein,
          targetCarbs: macros.carbs,
          targetFat: macros.fat,
        );
      } catch (_) {}

      if (mounted) {
        context.go(AppRoutes.memberDashboard);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.surfaceBg,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.fitness_center_rounded, color: Colors.black, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'VICIOUS',
                style: TextStyle(
                  color: context.titleColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'FITNESS',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.titleColor),
          tooltip: 'Back',
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
              _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            } else if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.welcome);
            }
          },
        ),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 4),
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
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          // Ambient Athletic Green Glow
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accentCyan.withValues(alpha: 0.08),
                    AppColors.accentCyan.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // Main Step-by-Step Form Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- HERO BRANDING HEADER ---
                      _buildHeroHeader(),
                      const SizedBox(height: 18),

                      // --- PRE-SELECTED PLAN NOTICE (If any) ---
                      if (_chosenPlanName != null) _buildPreSelectedPlanBanner(),

                      // --- STEP-BY-STEP PROGRESS STEPPER ---
                      _buildStepProgressIndicator(),

                      // Error Banner if registration fails
                      if (authState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  authState.errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // --- STEP CONTENT (Animated Switcher) ---
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.04, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey<int>(_currentStep),
                          child: _buildCurrentStepContent(authState),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP PROGRESS INDICATOR ---
  Widget _buildStepProgressIndicator() {
    final steps = [
      {'num': '1', 'title': 'Account', 'subtitle': 'Credentials'},
      {'num': '2', 'title': 'Biometrics', 'subtitle': 'Physique & Goals'},
      {'num': '3', 'title': 'Membership', 'subtitle': 'Plan Selection'},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderLine, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: InkWell(
                    onTap: () => _goToStep(i),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentStep > i
                                  ? AppColors.primary
                                  : (_currentStep == i
                                      ? AppColors.primary.withValues(alpha: 0.2)
                                      : context.elevatedSurface),
                              border: Border.all(
                                color: _currentStep >= i ? AppColors.primary : context.borderLine,
                                width: _currentStep == i ? 2 : 1,
                              ),
                              boxShadow: _currentStep == i
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: _currentStep > i
                                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                                  : Text(
                                      steps[i]['num'] as String,
                                      style: TextStyle(
                                        color: _currentStep == i ? AppColors.primary : context.mutedColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'STEP ${i + 1}',
                                  style: TextStyle(
                                    color: _currentStep == i
                                        ? AppColors.primary
                                        : (_currentStep > i ? context.titleColor.withValues(alpha: 0.7) : context.mutedColor),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  steps[i]['title'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _currentStep >= i ? context.titleColor : context.mutedColor,
                                    fontSize: 11,
                                    fontWeight: _currentStep == i ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (i < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Container(
                      width: 12,
                      height: 2,
                      color: _currentStep > i ? AppColors.primary : AppColors.border,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Progress Percentage Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / steps.length,
              backgroundColor: context.borderLine,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // --- PRE-SELECTED PLAN BANNER ---
  Widget _buildPreSelectedPlanBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.white),
                children: [
                  const TextSpan(text: 'Selected Plan: '),
                  TextSpan(
                    text: '$_chosenPlanName (₱${_chosenPlanPrice?.toStringAsFixed(0)})',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
                  ),
                  TextSpan(
                    text: _currentStep == 2
                        ? ' — ready to finalize'
                        : ' — will be finalized in Step 3 (Membership)',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CURRENT STEP CONTENT DISPATCHER ---
  Widget _buildCurrentStepContent(AuthState authState) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          if (_currentStep == 0) {
            _proceedToStep2();
            return KeyEventResult.handled;
          } else if (_currentStep == 1) {
            _proceedToStep3();
            return KeyEventResult.handled;
          } else if (_currentStep == 2) {
            if (!authState.isLoading) {
              _handleRegister();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          switch (_currentStep) {
            case 0:
              return _buildStep1AccountCredentials();
            case 1:
              return _buildStep2Biometrics();
            case 2:
            default:
              return _buildStep3Membership(authState);
          }
        },
      ),
    );
  }

  // =========================================================================
  // STEP 1: ACCOUNT CREDENTIALS
  // =========================================================================
  Widget _buildStep1AccountCredentials() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          _proceedToStep2();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            icon: Icons.person_rounded,
            iconColor: AppColors.primary,
            title: 'Account Credentials',
            badgeText: 'STEP 1 OF 3',
            subtitle: 'Create your secure member login credentials for Vicious Fitness',
            children: [
              Form(
                key: _step1FormKey,
                child: Column(
                  children: [
                    CustomTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'e.g. Juan Dela Cruz',
                      prefixIcon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: Validators.fullName,
                      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      hint: 'name@example.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: Validators.email,
                      onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                    ),
                    // Real-time email availability warning
                    if (_emailAlreadyInUse)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'This email is already in use. Please use a different email address.',
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_isCheckingEmail)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Checking email availability...',
                              style: TextStyle(
                                color: context.mutedColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'At least 8 characters (Upper, Lower, Number, Symbol)',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _proceedToStep2(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: Validators.password,
                    ),
                    _buildPasswordRequirements(_passwordController.text, context),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Step 1 CTA
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _proceedToStep2,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Continue to Step 2: Biometrics & Goals',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Already have a Vicious account? ',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => context.push(AppRoutes.login),
                    child: const Text(
                      'Log In Here',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordRequirements(String password, BuildContext context) {
    final hasMin = Validators.hasMinLength(password);
    final hasUpper = Validators.hasUppercase(password);
    final hasLower = Validators.hasLowercase(password);
    final hasDigit = Validators.hasDigit(password);
    final hasSpecial = Validators.hasSpecialChar(password);

    Widget buildItem(String text, bool met) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: met ? AppColors.primary.withValues(alpha: 0.15) : context.elevatedSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: met ? AppColors.primary : context.borderLine,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 13,
              color: met ? AppColors.primary : context.mutedColor,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: met ? FontWeight.w700 : FontWeight.w500,
                color: met ? (context.isDark ? AppColors.primary : Colors.green.shade800) : context.subtitleColor,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Password Strength Requirements:',
          style: TextStyle(
            color: context.titleColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            buildItem('8+ Chars', hasMin),
            buildItem('Uppercase (A-Z)', hasUpper),
            buildItem('Lowercase (a-z)', hasLower),
            buildItem('Number (0-9)', hasDigit),
            buildItem('Special Char (!@#\$)', hasSpecial),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // STEP 2: BIOMETRICS & TRAINING GOALS
  // =========================================================================
  Widget _buildStep2Biometrics() {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          _proceedToStep3();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionCard(
            icon: Icons.speed_rounded,
            iconColor: AppColors.accentCyan,
            title: 'Biometrics & AI Training Profile',
            badgeText: 'STEP 2 OF 3',
            subtitle: 'Feeds our Machine Learning & Linear Optimization engines to generate custom routines and diet plans',
            children: [
              Form(
                key: _step2FormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Age & Gender
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _ageController,
                            label: 'Age',
                            hint: 'e.g. 24',
                            prefixIcon: Icons.calendar_today_rounded,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                            validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter age';
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 10 || n > 120) return 'Valid age (10-120)';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gender',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildGenderTile(
                                    label: 'Male',
                                    icon: Icons.male_rounded,
                                    isSelected: _gender == 'Male',
                                    onTap: () => setState(() => _gender = 'Male'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildGenderTile(
                                    label: 'Female',
                                    icon: Icons.female_rounded,
                                    isSelected: _gender == 'Female',
                                    onTap: () => setState(() => _gender = 'Female'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Height & Weight
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomTextField(
                          controller: _heightController,
                          label: 'Height (cm)',
                          hint: 'e.g. 170',
                          prefixIcon: Icons.height_rounded,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter height';
                            final n = double.tryParse(v.trim());
                            if (n == null || n < 80 || n > 250) return 'Valid cm (80-250)';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: CustomTextField(
                          controller: _weightController,
                          label: 'Weight (kg)',
                          hint: 'e.g. 65',
                          prefixIcon: Icons.monitor_weight_outlined,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _proceedToStep3(),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter weight';
                            final n = double.tryParse(v.trim());
                            if (n == null || n < 25 || n > 300) return 'Valid kg (25-300)';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  // LIVE DYNAMIC BMI CALCULATOR PREVIEW BADGE
                  const SizedBox(height: 14),
                  _buildLiveBmiPreview(),
                  const SizedBox(height: 18),

                  // Fitness Goal Interactive Cards
                  const Text(
                    'Primary Fitness Goal',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildFitnessGoalSelector(),
                  const SizedBox(height: 16),

                  // Activity & Experience Dropdowns
                  _buildDropdownField(
                    'Activity Level',
                    _activityLevel,
                    _activities,
                    (v) => setState(() => _activityLevel = v),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Training Experience',
                    _experienceLevel,
                    _experiences,
                    (v) => setState(() => _experienceLevel = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Step 2 Action Buttons (Back + Next)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _currentStep = 0);
                    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _proceedToStep3,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Continue to Membership',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    );
  }

  // =========================================================================
  // STEP 3: MEMBERSHIP PLAN SELECTION & FINAL REGISTRATION
  // =========================================================================
  Widget _buildStep3Membership(AuthState authState) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          if (!authState.isLoading) {
            _handleRegister();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMembershipPlansSection(),
        const SizedBox(height: 18),

        // Registration Summary Card
        _buildRegistrationSummaryCard(),
        const SizedBox(height: 24),

        // Step 3 Action Buttons (Back + Submit)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _currentStep = 1);
                    _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Back', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    elevation: 6,
                    shadowColor: AppColors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                        )
                      : Text(
                          _chosenPlanName != null
                              ? '⚡ Register & Request $_chosenPlanName'
                              : '⚡ Complete Registration',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            color: Colors.black,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              Icon(Icons.lock_rounded, color: AppColors.textMuted, size: 14),
              SizedBox(width: 6),
              Text(
                'Secure 256-Bit SSL • Instant AI Plan Generation • Free to Start',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  // --- REGISTRATION ORDER SUMMARY CARD ---
  Widget _buildRegistrationSummaryCard() {
    final bmi = _computedBmi;
    final planDesc = _chosenPlanName != null
        ? '$_chosenPlanName (₱${_chosenPlanPrice?.toStringAsFixed(0)} / ${_chosenPlanDays ?? 30} Days)'
        : 'Monthly Basic (₱1,200 / 30 Days)';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderLine, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Registration Summary',
                style: TextStyle(
                  color: context.titleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _goToStep(0),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Edit Info',
                  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: context.borderLine, height: 1),
          const SizedBox(height: 12),
          _buildSummaryRow(
            label: 'Member Name',
            value: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Not provided',
          ),
          const SizedBox(height: 6),
          _buildSummaryRow(
            label: 'Email',
            value: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : 'Not provided',
          ),
          const SizedBox(height: 6),
          _buildSummaryRow(
            label: 'Biometrics Profile',
            value:
                '${_ageController.text.trim().isNotEmpty ? _ageController.text.trim() : "--"} yrs • ${_gender ?? "Unspecified"} • ${_heightController.text.trim()} cm / ${_weightController.text.trim()} kg${bmi != null ? ' (BMI ${bmi.toStringAsFixed(1)})' : ''}',
          ),
          const SizedBox(height: 6),
          _buildSummaryRow(
            label: 'Fitness Goal',
            value: _fitnessGoal,
          ),
          const SizedBox(height: 6),
          _buildSummaryRow(
            label: 'Selected Membership',
            value: planDesc,
            valueColor: AppColors.primary,
            isBold: true,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.elevatedSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: context.mutedColor, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cash or RFID payment is settled at the front desk upon arrival.',
                    style: TextStyle(color: context.mutedColor, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.subtitleColor, fontSize: 12),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor ?? context.titleColor,
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // --- HERO HEADER ---
  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: context.isDark ? 0.12 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, color: AppColors.primary, size: 14),
                    SizedBox(width: 5),
                    Text(
                      'START YOUR TRANSFORMATION',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Join VICIOUS',
            style: TextStyle(
              color: context.titleColor,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create your member account in 3 easy steps to access customized workouts, AI meal plans, and gym passes.',
            style: TextStyle(
              color: context.subtitleColor,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          // Micro-Badges Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureMicroChip(Icons.psychology_rounded, 'AI Workout Recommender', AppColors.primary),
              _buildFeatureMicroChip(Icons.restaurant_menu_rounded, 'PuLP Meal Optimizer', AppColors.accentCyan),
              _buildFeatureMicroChip(Icons.groups_rounded, 'Dedicated Coach Pairing', AppColors.accent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureMicroChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION CONTAINER CARD ---
  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badgeText,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderLine, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  // --- GENDER SELECTOR TILE ---
  Widget _buildGenderTile({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : context.elevatedSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.borderLine,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LIVE BMI DYNAMIC CHIP ---
  Widget _buildLiveBmiPreview() {
    final bmi = _computedBmi;
    if (bmi != null) {
      final category = BmiCalculator.getCategory(bmi);
      Color categoryColor = AppColors.primary;
      if (category == 'Overweight') categoryColor = AppColors.accent;
      if (category == 'Obese') categoryColor = AppColors.error;
      if (category == 'Underweight') categoryColor = AppColors.accentCyan;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: categoryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: categoryColor.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, color: categoryColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 12),
                  children: [
                    const TextSpan(text: 'Live Biometrics: ', style: TextStyle(color: Colors.white70)),
                    TextSpan(
                      text: 'BMI ${bmi.toStringAsFixed(1)} ',
                      style: TextStyle(color: categoryColor, fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: '($category) ',
                      style: TextStyle(color: categoryColor, fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(
                      text: '• Ready for ML training allocation',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderLine),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: context.mutedColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Enter height & weight to calculate your live baseline BMI & caloric targets.',
              style: TextStyle(color: context.mutedColor, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // --- FITNESS GOAL SELECTOR CARDS ---
  Widget _buildFitnessGoalSelector() {
    return Column(
      children: _goalOptions.map((g) {
        final title = g['title'] as String;
        final subtitle = g['subtitle'] as String;
        final icon = g['icon'] as IconData;
        final isSelected = _fitnessGoal == title;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : context.elevatedSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : context.borderLine,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _fitnessGoal = title),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: isSelected ? Colors.black : Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- DROPDOWN FIELD ---
  Widget _buildDropdownField(String label, String currentVal, List<String> options, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: context.subtitleColor, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: context.elevatedSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderLine),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentVal,
              isExpanded: true,
              dropdownColor: context.cardColor,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              items: options.map((o) {
                return DropdownMenuItem(
                  value: o,
                  child: Text(
                    o,
                    style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- MEMBERSHIP PLANS SECTION ---
  Widget _buildMembershipPlansSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderLine, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.35 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.card_membership_rounded, color: AppColors.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Membership Plan (Step 3)',
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select a membership tier to activate your gym access upon account registration',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: context.borderLine, height: 1),
          const SizedBox(height: 18),

          // Plan options
          ..._membershipTiers.map((t) {
            final title = t['title'] as String;
            final price = t['price'] as String;
            final duration = t['duration'] as String;
            final popular = t['popular'] as bool;
            final features = t['features'] as List<String>;
            final priceVal = (t['priceVal'] as num?)?.toDouble() ?? 1400.0;
            final daysVal = (t['days'] as num?)?.toInt() ?? 30;
            final badgeText = t['badgeText'] as String?;
            final accentColor = t['accentColor'] as Color? ?? AppColors.primary;
            final isSelected = _chosenPlanName != null &&
                _chosenPlanName!.toLowerCase() == title.toLowerCase();

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.1)
                    : context.elevatedSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : (popular ? AppColors.primary.withValues(alpha: 0.7) : context.borderLine),
                  width: isSelected ? 2.2 : (popular ? 1.8 : 1.0),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() {
                      _chosenPlanName = title;
                      _chosenPlanPrice = priceVal;
                      _chosenPlanDays = daysVal;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: context.titleColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    duration,
                                    style: TextStyle(color: context.mutedColor, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (popular)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'MOST POPULAR',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                      ),
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
                                      badgeText,
                                      style: const TextStyle(
                                        color: Colors.amber,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: accentColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Colors.black, size: 12),
                                        SizedBox(width: 4),
                                        Text(
                                          'SELECTED',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              price,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• $duration',
                              style: TextStyle(color: context.subtitleColor, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(color: context.borderLine, height: 1),
                        const SizedBox(height: 12),
                        ...features.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 15),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      f,
                                      style: TextStyle(color: context.titleColor.withValues(alpha: 0.8), fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _chosenPlanName = title;
                                _chosenPlanPrice = priceVal;
                                _chosenPlanDays = daysVal;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected ? AppColors.primary : context.cardColor,
                              foregroundColor: isSelected ? Colors.black : context.titleColor,
                              elevation: 0,
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : context.borderLine,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isSelected ? 'Selected Plan ✓' : 'Select Plan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
