class Validators {
  static String? required(String? val, [String message = 'This field is required']) {
    if (val == null || val.trim().isEmpty) return message;
    return null;
  }

  static String? fullName(String? val, [String message = 'Please enter your full name (First & Last name)']) {
    if (val == null || val.trim().isEmpty) return 'Full name is required';
    final parts = val.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length < 2) {
      return 'Please enter your full name (e.g. Juan Dela Cruz)';
    }
    if (parts.any((p) => p.length < 2)) {
      return 'Each part of the name must be at least 2 characters';
    }
    return null;
  }

  static String? email(String? val) {
    if (val == null || val.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(val.trim())) return 'Please enter a valid email address';
    return null;
  }

  /// Strong password validator for account creation (Registration & Coach creation)
  static String? strongPassword(String? val) {
    if (val == null || val.trim().isEmpty) return 'Password is required';
    final trimmed = val.trim();
    if (trimmed.length < 8) return 'Password must be at least 8 characters long';
    if (!RegExp(r'[A-Z]').hasMatch(trimmed)) {
      return 'Password must contain at least one uppercase letter (A-Z)';
    }
    if (!RegExp(r'[a-z]').hasMatch(trimmed)) {
      return 'Password must contain at least one lowercase letter (a-z)';
    }
    if (!RegExp(r'[0-9]').hasMatch(trimmed)) {
      return 'Password must contain at least one number (0-9)';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/`~]').hasMatch(trimmed)) {
      return 'Password must contain at least one special character (!@#\$%^&*)';
    }
    return null;
  }

  /// Default password validator (enforces strong password requirements for account creation)
  static String? password(String? val) => strongPassword(val);

  /// Validator for login input (allows existing pre-seeded demo accounts to sign in)
  static String? loginPassword(String? val) {
    if (val == null || val.trim().isEmpty) return 'Password is required';
    if (val.trim().length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // Password criteria helper methods for live UI feedback
  static bool hasMinLength(String? val, [int min = 8]) => val != null && val.trim().length >= min;
  static bool hasUppercase(String? val) => val != null && RegExp(r'[A-Z]').hasMatch(val);
  static bool hasLowercase(String? val) => val != null && RegExp(r'[a-z]').hasMatch(val);
  static bool hasDigit(String? val) => val != null && RegExp(r'[0-9]').hasMatch(val);
  static bool hasSpecialChar(String? val) =>
      val != null && RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\/`~]').hasMatch(val);
  static bool isStrongPassword(String? val) => strongPassword(val) == null;

  static String? number(String? val, [String message = 'Enter a valid number']) {
    if (val == null || val.trim().isEmpty) return message;
    if (double.tryParse(val.trim()) == null) return message;
    return null;
  }
}
