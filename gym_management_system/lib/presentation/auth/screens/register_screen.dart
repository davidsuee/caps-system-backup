import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/membership_entity.dart';
import '../../../data/models/membership_model.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../membership/providers/membership_provider.dart';
import '../../admin/providers/admin_provider.dart';
import '../../coach/providers/coach_provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/bmi_calculator.dart';
import '../../workout/providers/workout_provider.dart';
import '../../meal/providers/meal_provider.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String? _gender;
  String _fitnessGoal = 'Muscle Gain';
  String _activityLevel = 'Moderately Active';
  String _experienceLevel = 'Beginner';

  late String? _chosenPlanName;
  late double? _chosenPlanPrice;
  late int? _chosenPlanDays;

  final _scrollController = ScrollController();
  final _planSectionKey = GlobalKey();

  void _scrollToPlanSection() {
    final ctx = _planSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  static const List<Map<String, dynamic>> _membershipTiers = [
    {
      'name': 'Day Pass',
      'title': 'Day Pass',
      'price': '₱150',
      'priceVal': 150.0,
      'days': 1,
      'duration': '1 Day Access',
      'icon': Icons.flash_on_rounded,
      'popular': false,
      'features': [
        'Full access to all facility zones',
        'Locker & shower amenities',
        'Digital attendance check-in/out',
      ],
    },
    {
      'name': 'Monthly Basic',
      'title': 'Monthly Basic',
      'price': '₱1,200',
      'priceVal': 1200.0,
      'days': 30,
      'duration': '30 Days Access',
      'icon': Icons.fitness_center_rounded,
      'popular': true,
      'features': [
        'Unlimited gym entry all hours',
        'AI-Powered Workout Recommender',
        'Progress & weigh-in log tracking',
        'Standard equipment orientation',
      ],
    },
    {
      'name': 'Quarterly Pro',
      'title': 'Quarterly Pro',
      'price': '₱3,200',
      'priceVal': 3200.0,
      'days': 90,
      'duration': '90 Days Access',
      'icon': Icons.military_tech_rounded,
      'popular': false,
      'features': [
        'All Monthly Basic benefits',
        'PuLP Linear Optimization Meal Plans',
        'Assigned Dedicated Fitness Coach',
        'Bi-weekly progress evaluation',
      ],
    },
    {
      'name': 'Annual VIP',
      'title': 'Annual VIP',
      'price': '₱10,800',
      'priceVal': 10800.0,
      'days': 365,
      'duration': '365 Days Access',
      'icon': Icons.workspace_premium_rounded,
      'popular': false,
      'features': [
        'Full VIP gym privileges 365 days',
        'Priority coach session booking',
        'Personalized AI training & diet regimes',
        '2 Free Guest Day Passes / month',
      ],
    },
  ];

  final List<String> _goals = ['Weight Loss', 'Muscle Gain', 'Improve Endurance', 'General Fitness'];
  final List<String> _activities = ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'];
  final List<String> _experiences = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    // Only set if user explicitly selected a plan from Welcome Screen; otherwise null
    _chosenPlanName = widget.selectedPlanName;
    if (_chosenPlanName != null) {
      final matching = _membershipTiers.firstWhere(
        (p) => (p['title'] as String).toLowerCase() == _chosenPlanName!.toLowerCase() ||
               (p['name'] as String).toLowerCase() == _chosenPlanName!.toLowerCase(),
        orElse: () => {},
      );
      _chosenPlanPrice = widget.selectedPlanPrice ?? (matching['priceVal'] as num?)?.toDouble() ?? 1200.0;
      _chosenPlanDays = widget.selectedPlanDays ?? (matching['days'] as num?)?.toInt() ?? 30;
    } else {
      _chosenPlanPrice = null;
      _chosenPlanDays = null;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender (Male or Female).'),
          backgroundColor: AppColors.error,
        ),
      );
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
      // Create pending membership request ONLY if user selected a plan
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

      // Notify Admin and Coach live streams so new member is immediately visible in rosters & directory
      try {
        ref.read(adminNotifierProvider.notifier).loadDashboard();
        ref.read(coachNotifierProvider.notifier).loadDashboard();
      } catch (_) {}

      // Automatically generate tailored initial workout routine & meal plan
      try {
        await ref.read(workoutNotifierProvider.notifier).generatePlan(user);
        final bmr = BmiCalculator.calculateBmr(
          weightKg: user.weightKg,
          heightCm: user.heightCm,
          age: user.age,
          gender: user.gender,
        );
        final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: user.activityLevel);
        final tCal = BmiCalculator.calculateTargetCalories(tdee: tdee, fitnessGoal: user.fitnessGoal);
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
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Viscious Fitness',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.welcome);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Join VISCOUS',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Create your member account to access workouts, meal recommendations, and gym passes.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // Top Membership Plan Banner (Tapping scrolls to full membership section below)
                if (_chosenPlanName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.card_membership_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selected Membership Plan:',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_chosenPlanName • ₱${_chosenPlanPrice?.toStringAsFixed(0)} ($_chosenPlanDays Days)',
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Will be submitted for Admin cash approval',
                                style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _scrollToPlanSection,
                          child: const Text('Change', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _scrollToPlanSection,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.card_membership_rounded, color: AppColors.textMuted, size: 24),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Membership Plan (Optional):',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'No Plan Selected • Choose Below',
                                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Day Pass, Monthly Basic, Quarterly, VIP or None',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'View Plans',
                              style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (authState.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 18),
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
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'e.g. Juan Dela Cruz',
                  prefixIcon: Icons.person_outline,
                  validator: Validators.required,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'name@example.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'At least 6 characters',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: Validators.password,
                ),

                // ── Biometrics & Target Goals ──
                const SizedBox(height: 20),
                const Divider(color: AppColors.border),
                const SizedBox(height: 14),
                const Text(
                  'Biometrics & Target Goals',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                // Age & Gender (Manual input for Age, Male & Female only for Gender)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _ageController,
                        label: 'Age',
                        hint: 'e.g. 24',
                        keyboardType: TextInputType.number,
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
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(() => _gender = 'Male'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: _gender == 'Male'
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _gender == 'Male' ? AppColors.primary : AppColors.border,
                                        width: _gender == 'Male' ? 1.8 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.male_rounded,
                                          color: _gender == 'Male' ? AppColors.primary : AppColors.textSecondary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Male',
                                          style: TextStyle(
                                            color: _gender == 'Male' ? AppColors.primary : AppColors.textPrimary,
                                            fontWeight: _gender == 'Male' ? FontWeight.w800 : FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => setState(() => _gender = 'Female'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: _gender == 'Female'
                                          ? AppColors.primary.withValues(alpha: 0.15)
                                          : AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _gender == 'Female' ? AppColors.primary : AppColors.border,
                                        width: _gender == 'Female' ? 1.8 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.female_rounded,
                                          color: _gender == 'Female' ? AppColors.primary : AppColors.textSecondary,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Female',
                                          style: TextStyle(
                                            color: _gender == 'Female' ? AppColors.primary : AppColors.textPrimary,
                                            fontWeight: _gender == 'Female' ? FontWeight.w800 : FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Height & Weight (Manual input)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _heightController,
                        label: 'Height (cm)',
                        hint: 'e.g. 170',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter height';
                          final n = double.tryParse(v.trim());
                          if (n == null || n < 80 || n > 250) return 'Valid cm';
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
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter weight';
                          final n = double.tryParse(v.trim());
                          if (n == null || n < 25 || n > 300) return 'Valid kg';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDropdownField('Fitness Goal', _fitnessGoal, _goals, (v) => setState(() => _fitnessGoal = v)),
                const SizedBox(height: 16),
                _buildDropdownField('Activity Level', _activityLevel, _activities, (v) => setState(() => _activityLevel = v)),
                const SizedBox(height: 16),
                _buildDropdownField('Experience Level', _experienceLevel, _experiences, (v) => setState(() => _experienceLevel = v)),

                // --- FULL COPY OF MEMBERSHIP PLANS RIGHT ABOVE REGISTER ACCOUNT ---
                _buildMembershipPlansSection(),

                const SizedBox(height: 28),
                CustomButton(
                  text: _chosenPlanName != null
                      ? 'Register & Request $_chosenPlanName'
                      : 'Register Account',
                  isLoading: authState.isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.login),
                      child: const Text(
                        'Log In',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipPlansSection() {
    return Column(
      key: _planSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(color: AppColors.border),
        const SizedBox(height: 18),

        // Section Header (Identical style to Welcome screen)
        const Text(
          'Membership Plans',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Flexible access tailored for every fitness milestone',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),

        // 1. Option for Register Only / No Plan
        _buildNoPlanCard(),
        const SizedBox(height: 14),

        // 2. Full Copy of the Membership Plans from Welcome Screen
        ..._membershipTiers.map((t) {
          final title = t['title'] as String;
          final price = t['price'] as String;
          final duration = t['duration'] as String;
          final popular = t['popular'] as bool;
          final features = t['features'] as List<String>;
          final priceVal = (t['priceVal'] as num?)?.toDouble() ?? 1200.0;
          final daysVal = (t['days'] as num?)?.toInt() ?? 30;
          final isSelected = _chosenPlanName != null &&
              _chosenPlanName!.toLowerCase() == title.toLowerCase();

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (popular ? AppColors.primary : AppColors.border),
                width: isSelected ? 2.2 : (popular ? 2 : 1),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _chosenPlanName = null;
                      _chosenPlanPrice = null;
                      _chosenPlanDays = null;
                    } else {
                      _chosenPlanName = title;
                      _chosenPlanPrice = priceVal;
                      _chosenPlanDays = daysVal;
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                duration,
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.black, size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'SELECTED',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (popular)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'MOST POPULAR',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            price,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/${duration.split(' ').first}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 14),
                      ...features.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    f,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: CustomButton(
                          text: isSelected ? 'Selected Plan ✓' : 'Select Plan & Register',
                          isOutlined: !isSelected,
                          onPressed: () {
                            setState(() {
                              if (isSelected) {
                                _chosenPlanName = null;
                                _chosenPlanPrice = null;
                                _chosenPlanDays = null;
                              } else {
                                _chosenPlanName = title;
                                _chosenPlanPrice = priceVal;
                                _chosenPlanDays = daysVal;
                              }
                            });
                          },
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
    );
  }

  Widget _buildNoPlanCard() {
    final isNoPlan = _chosenPlanName == null;
    return Container(
      decoration: BoxDecoration(
        color: isNoPlan ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNoPlan ? AppColors.primary : AppColors.border,
          width: isNoPlan ? 1.8 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _chosenPlanName = null;
              _chosenPlanPrice = null;
              _chosenPlanDays = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isNoPlan ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: isNoPlan ? AppColors.primary : AppColors.textMuted,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Register Account Only (No Plan)',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Free registration. You can choose or buy a gym pass anytime at the counter.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isNoPlan ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: isNoPlan ? AppColors.primary : AppColors.textMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, String currentVal, List<String> options, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentVal,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
