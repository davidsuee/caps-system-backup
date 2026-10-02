import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../providers/admin_provider.dart';

Future<void> showAddCoachDialog(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => _AddCoachSheet(parentRef: ref),
  );
}

class _AddCoachSheet extends StatefulWidget {
  final WidgetRef parentRef;

  const _AddCoachSheet({required this.parentRef});

  @override
  State<_AddCoachSheet> createState() => _AddCoachSheetState();
}

class _AddCoachSheetState extends State<_AddCoachSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedSpecialization = 'Muscle Gain';
  final _ageController = TextEditingController(text: '30');
  final _phoneController = TextEditingController();

  int _maxClients = 20;
  String _selectedGender = 'Male';
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _specializationOptions = [
    {
      'title': 'Muscle Gain',
      'subtitle': 'Hypertrophy & Strength',
      'icon': Icons.fitness_center_rounded,
    },
    {
      'title': 'Weight Loss',
      'subtitle': 'Caloric Deficit & Fat Burn',
      'icon': Icons.local_fire_department_rounded,
    },
    {
      'title': 'Improve Endurance',
      'subtitle': 'Stamina & Cardio Conditioning',
      'icon': Icons.directions_run_rounded,
    },
    {
      'title': 'General Fitness',
      'subtitle': 'Overall Mobility & Health',
      'icon': Icons.self_improvement_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final existingCoaches = widget.parentRef.read(adminNotifierProvider).coaches;
    final email = _emailController.text.trim().toLowerCase();
    if (existingCoaches.any((c) => c.email.toLowerCase() == email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A coach with this email address already exists.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final formattedName = name.toLowerCase().startsWith('coach') ? name : 'Coach $name';
    final age = int.tryParse(_ageController.text.trim()) ?? 30;
    final password = _passwordController.text.trim();
    final specialization = _selectedSpecialization;

    final created = await widget.parentRef.read(adminNotifierProvider.notifier).addCoach(
      name: formattedName,
      email: email,
      specialization: specialization,
      password: password,
      maxClients: _maxClients,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
      gender: _selectedGender,
      age: age,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (created != null) {
      Navigator.pop(context);
      _showCredentialsDialog(
        context: context,
        name: formattedName,
        email: email,
        password: password,
        specialization: specialization,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add coach. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showCredentialsDialog({
    required BuildContext context,
    required String name,
    required String email,
    required String password,
    required String specialization,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coach Account Created',
                    style: TextStyle(
                      color: context.titleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Provide these credentials to the coach',
                    style: TextStyle(color: context.subtitleColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.elevatedSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCredentialRow('Coach Name', name, context),
                  const Divider(height: 16),
                  _buildCredentialRow('Login Email', email, context),
                  const Divider(height: 16),
                  _buildCredentialRow('Password', password, context, isSecret: true),
                  const Divider(height: 16),
                  _buildCredentialRow('Specialization', specialization, context),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The coach can now sign in using these credentials to view and monitor member progress.',
                      style: TextStyle(color: context.titleColor, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: 'Coach Portal Login\nName: $name\nEmail: $email\nPassword: $password\nSpecialization: $specialization',
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coach credentials copied to clipboard!'),
                  backgroundColor: AppColors.primary,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
            label: const Text('Copy Info', style: TextStyle(color: AppColors.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value, BuildContext context, {bool isSecret = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: context.subtitleColor, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.titleColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: isSecret ? 'monospace' : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.mutedColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add New Gym Coach',
                            style: TextStyle(
                              color: context.titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Register a fitness trainer to the coaching staff',
                            style: TextStyle(
                              color: context.subtitleColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: context.mutedColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Full Name
              CustomTextField(
                controller: _nameController,
                label: 'Coach Name',
                hint: 'e.g. Alex Turner',
                prefixIcon: Icons.badge_outlined,
                validator: Validators.fullName,
              ),
              const SizedBox(height: 14),

              // Email Address
              CustomTextField(
                controller: _emailController,
                label: 'Coach Email (Login ID)',
                hint: 'e.g. alex.coach@gym.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: (v) => Validators.email(v),
              ),
              const SizedBox(height: 14),

              // Account Password
              CustomTextField(
                controller: _passwordController,
                label: 'Account Password',
                hint: 'Set password for coach login',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                validator: Validators.password,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Admin Provisioned Account: Provide this password to the coach so they can log in to view and track member progress.',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildPasswordRequirements(_passwordController.text, context),
              const SizedBox(height: 14),

              // Specialization / Discipline (Primary Fitness Goals)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Specialization / Primary Fitness Goal',
                    style: TextStyle(
                      color: context.titleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Select 1',
                    style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                children: _specializationOptions.map((opt) {
                  final title = opt['title'] as String;
                  final subtitle = opt['subtitle'] as String;
                  final icon = opt['icon'] as IconData;
                  final isSelected = _selectedSpecialization == title;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : context.elevatedSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : context.borderLine,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _selectedSpecialization = title),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : context.cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  icon,
                                  color: isSelected ? Colors.black : context.subtitleColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color: isSelected ? AppColors.primary : context.titleColor,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      subtitle,
                                      style: TextStyle(color: context.subtitleColor, fontSize: 10.5),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                color: isSelected ? AppColors.primary : context.mutedColor,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Row: Age & Gender
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _ageController,
                      label: 'Age',
                      hint: '30',
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.cake_outlined,
                      validator: (v) => Validators.number(v, 'Enter age'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gender',
                          style: TextStyle(
                            color: context.titleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: context.borderLine),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedGender,
                              isExpanded: true,
                              dropdownColor: context.cardColor,
                              items: const [
                                DropdownMenuItem(value: 'Male', child: Text('Male')),
                                DropdownMenuItem(value: 'Female', child: Text('Female')),
                                DropdownMenuItem(value: 'Other', child: Text('Other')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedGender = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Client Capacity Slider
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Max Client Capacity',
                    style: TextStyle(
                      color: context.titleColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$_maxClients Clients',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _maxClients.toDouble(),
                min: 5,
                max: 30,
                divisions: 25,
                activeColor: AppColors.primary,
                inactiveColor: context.elevatedSurface,
                onChanged: (v) => setState(() => _maxClients = v.toInt()),
              ),
              Text(
                'Standard gym allocation limit is 20 clients per coach.',
                style: TextStyle(color: context.mutedColor, fontSize: 11),
              ),
              const SizedBox(height: 20),

              // Submit Button
              CustomButton(
                text: _isSubmitting ? 'Registering Coach...' : 'Register Coach',
                icon: Icons.how_to_reg_rounded,
                isLoading: _isSubmitting,
                color: AppColors.primary,
                onPressed: _submit,
              ),
            ],
          ),
        ),
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
}
