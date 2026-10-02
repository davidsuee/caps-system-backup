import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/utils/bmi_calculator.dart';
import '../../../core/utils/validators.dart';
import '../../auth/providers/auth_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../meal/providers/meal_provider.dart';
import '../../progress/providers/progress_provider.dart';
import '../../dashboard/widgets/member_app_bar.dart';
import '../../dashboard/widgets/member_bottom_nav.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  late String _fitnessGoal;
  late String _activityLevel;
  late String _experienceLevel;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _ageController = TextEditingController(text: user?.age.toString() ?? '25');
    _heightController = TextEditingController(text: user?.heightCm.toString() ?? '175');
    _weightController = TextEditingController(text: user?.weightKg.toString() ?? '70');
    _fitnessGoal = user?.fitnessGoal ?? 'Muscle Gain';
    _activityLevel = user?.activityLevel ?? 'Moderately Active';
    _experienceLevel = user?.experienceLevel ?? 'Intermediate';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) return;

    final newWeight = double.tryParse(_weightController.text.trim()) ?? user.weightKg;
    final weightChanged = (newWeight - user.weightKg).abs() > 0.05;

    final updated = user.copyWith(
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? user.age,
      heightCm: double.tryParse(_heightController.text.trim()) ?? user.heightCm,
      weightKg: newWeight,
      fitnessGoal: _fitnessGoal,
      activityLevel: _activityLevel,
      experienceLevel: _experienceLevel,
    );

    await ref.read(authNotifierProvider.notifier).updateProfile(updated);

    if (weightChanged) {
      final diff = newWeight - user.weightKg;
      final diffSign = diff > 0 ? '+' : '';
      try {
        await ref.read(progressNotifierProvider.notifier).addLog(
          userId: user.id,
          weightKg: newWeight,
          notes: 'Weight update from Profile ($diffSign${diff.toStringAsFixed(1)} kg)',
          user: user,
        );
      } catch (_) {}
    }

    // Trigger AI re-generation for the updated goals, activity level, and experience level
    await ref.read(workoutNotifierProvider.notifier).generatePlan(updated);

    final bmr = BmiCalculator.calculateBmr(
      weightKg: updated.weightKg,
      heightCm: updated.heightCm,
      age: updated.age,
      gender: updated.gender,
    );
    final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: updated.activityLevel);
    final tCal = BmiCalculator.calculateTargetCalories(
      tdee: tdee,
      fitnessGoal: updated.fitnessGoal,
      bmi: updated.bmi,
    );
    final macros = BmiCalculator.calculateTargetMacros(targetCalories: tCal, fitnessGoal: updated.fitnessGoal);

    await ref.read(mealNotifierProvider.notifier).generateMealPlan(
      user: updated,
      targetCalories: tCal,
      targetProtein: macros.protein,
      targetCarbs: macros.carbs,
      targetFat: macros.fat,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated! New workout & meal plans tailored for ${tCal.toInt()} kcal & $_fitnessGoal generated!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.welcome);
      });
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final bmi = user.bmi;
    final bmr = BmiCalculator.calculateBmr(
      weightKg: user.weightKg,
      heightCm: user.heightCm,
      age: user.age,
      gender: user.gender,
    );
    final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: user.activityLevel);

    return Scaffold(
      appBar: MemberAppBar(
        title: 'Member Profile',
        subtitle: 'Account Settings & Biometrics',
        icon: Icons.person_rounded,
        actions: [
          Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderLine),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
              tooltip: 'Sign Out',
              onPressed: () async {
                context.go(AppRoutes.welcome);
                await ref.read(authNotifierProvider.notifier).logout();
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Basic Info
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.name,
                      style: TextStyle(color: context.titleColor, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(color: context.subtitleColor, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Role: ${user.role.displayName}',
                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Sports Science Biometric Cards
              const Text(
                'Biometrics & Metabolism Metrics',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard('BMI', bmi.toString(), BmiCalculator.getCategory(bmi), AppColors.accentCyan),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard('BMR', '${bmr.toInt()} kcal', 'Basal Metabolic', AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard('TDEE', '${tdee.toInt()} kcal', 'Daily Burn', AppColors.accent),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Edit Form
              const Text(
                'Update Measurements & Goals',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: _nameController,
                label: 'Name',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _ageController,
                      label: 'Age',
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.number(v, 'Enter age'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _heightController,
                      label: 'Height (cm)',
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.number(v, 'Enter cm'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomTextField(
                      controller: _weightController,
                      label: 'Weight (kg)',
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.number(v, 'Enter kg'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildDropdown('Fitness Goal', _fitnessGoal, ['Weight Loss', 'Muscle Gain', 'Improve Endurance', 'General Fitness'], (v) => setState(() => _fitnessGoal = v)),
              const SizedBox(height: 14),
              _buildDropdown('Activity Level', _activityLevel, ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active'], (v) => setState(() => _activityLevel = v)),
              const SizedBox(height: 14),
              _buildDropdown('Experience Level', _experienceLevel, ['Beginner', 'Intermediate', 'Advanced'], (v) => setState(() => _experienceLevel = v)),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Save Biometric Updates',
                onPressed: _saveChanges,
              ),
              const SizedBox(height: 14),
              CustomButton(
                text: 'Log Out',
                color: AppColors.error,
                textColor: Colors.white,
                isOutlined: true,
                onPressed: () async {
                  context.go(AppRoutes.welcome);
                  await ref.read(authNotifierProvider.notifier).logout();
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MemberBottomNav(currentIndex: 4),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.subtitleColor, fontSize: 13, fontWeight: FontWeight.w600)),
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
              value: value,
              isExpanded: true,
              dropdownColor: context.cardColor,
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(color: context.titleColor, fontSize: 14)))).toList(),
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

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String sub;
  final Color color;

  const _MetricCard(this.title, this.value, this.sub, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: context.mutedColor, fontSize: 10), maxLines: 1),
        ],
      ),
    );
  }
}
