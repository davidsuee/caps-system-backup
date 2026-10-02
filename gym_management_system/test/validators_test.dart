import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_system/core/utils/validators.dart';

void main() {
  group('Strong Password Validation Tests', () {
    test('Empty or null password returns error', () {
      expect(Validators.strongPassword(null), isNotNull);
      expect(Validators.strongPassword(''), isNotNull);
      expect(Validators.strongPassword('   '), isNotNull);
    });

    test('Password shorter than 8 characters returns length error', () {
      final result = Validators.strongPassword('P@ss1');
      expect(result, contains('at least 8 characters'));
    });

    test('Password missing uppercase letter returns uppercase error', () {
      final result = Validators.strongPassword('p@ssword123');
      expect(result, contains('uppercase letter (A-Z)'));
    });

    test('Password missing lowercase letter returns lowercase error', () {
      final result = Validators.strongPassword('P@SSWORD123');
      expect(result, contains('lowercase letter (a-z)'));
    });

    test('Password missing numeric digit returns number error', () {
      final result = Validators.strongPassword('P@sswordNone');
      expect(result, contains('number (0-9)'));
    });

    test('Password missing special character returns symbol error', () {
      final result = Validators.strongPassword('Password123');
      expect(result, contains('special character'));
    });

    test('Valid strong passwords pass validation', () {
      expect(Validators.strongPassword('Coach@123'), isNull);
      expect(Validators.strongPassword('P@ssword1!'), isNull);
      expect(Validators.strongPassword('Vicious#2026'), isNull);
      expect(Validators.strongPassword('Admin\$Safe99'), isNull);
    });

    test('Validators.password alias also enforces strong requirements', () {
      expect(Validators.password('weak'), isNotNull);
      expect(Validators.password('Coach@123'), isNull);
    });

    test('loginPassword allows legacy/demo 6+ char passwords', () {
      expect(Validators.loginPassword('password123'), isNull);
      expect(Validators.loginPassword('12345'), isNotNull);
    });

    test('Criteria boolean helpers accurately report state', () {
      expect(Validators.hasMinLength('12345678'), isTrue);
      expect(Validators.hasMinLength('1234567'), isFalse);

      expect(Validators.hasUppercase('aBc'), isTrue);
      expect(Validators.hasUppercase('abc'), isFalse);

      expect(Validators.hasLowercase('AbC'), isTrue);
      expect(Validators.hasLowercase('ABC'), isFalse);

      expect(Validators.hasDigit('ab3c'), isTrue);
      expect(Validators.hasDigit('abc'), isFalse);

      expect(Validators.hasSpecialChar('ab@c'), isTrue);
      expect(Validators.hasSpecialChar('abc'), isFalse);

      expect(Validators.isStrongPassword('Coach@123'), isTrue);
      expect(Validators.isStrongPassword('weak'), isFalse);
    });
  });

  group('Full Name Validation Tests', () {
    test('Empty or whitespace-only name fails validation', () {
      expect(Validators.fullName(null), isNotNull);
      expect(Validators.fullName(''), isNotNull);
      expect(Validators.fullName('   '), isNotNull);
    });

    test('Single-word name fails validation', () {
      expect(Validators.fullName('Jonel'), contains('e.g. Juan Dela Cruz'));
      expect(Validators.fullName('Alex'), contains('e.g. Juan Dela Cruz'));
      expect(Validators.fullName('Madonna'), contains('e.g. Juan Dela Cruz'));
    });

    test('Parts with less than 2 characters fail validation', () {
      expect(Validators.fullName('J Dela Cruz'), contains('at least 2 characters'));
      expect(Validators.fullName('Jonel D'), contains('at least 2 characters'));
    });

    test('Valid full name passes validation', () {
      expect(Validators.fullName('Juan Dela Cruz'), isNull);
      expect(Validators.fullName('Alex Turner'), isNull);
      expect(Validators.fullName('Marcus Vance'), isNull);
      expect(Validators.fullName('Maria Santos Gomez'), isNull);
    });
  });
}

