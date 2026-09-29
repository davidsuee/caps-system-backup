class Validators {
  static String? required(String? val, [String message = 'This field is required']) {
    if (val == null || val.trim().isEmpty) return message;
    return null;
  }

  static String? email(String? val) {
    if (val == null || val.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(val.trim())) return 'Please enter a valid email address';
    return null;
  }

  static String? password(String? val) {
    if (val == null || val.trim().isEmpty) return 'Password is required';
    if (val.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? number(String? val, [String message = 'Enter a valid number']) {
    if (val == null || val.trim().isEmpty) return message;
    if (double.tryParse(val.trim()) == null) return message;
    return null;
  }
}
