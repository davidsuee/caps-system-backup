import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../firebase_options.dart';
import '../local/local_cache_service.dart';

class AuthUserResult {
  final String uid;
  final String email;
  final String? idToken;
  final String? refreshToken;
  final User? rawFirebaseUser;

  const AuthUserResult({
    required this.uid,
    required this.email,
    this.idToken,
    this.refreshToken,
    this.rawFirebaseUser,
  });
}

class FirebaseAuthService {
  final FirebaseAuth? _customAuth;
  final Dio _dio;

  static AuthUserResult? _lastAuthenticatedUser;
  static AuthUserResult? get lastAuthenticatedUser {
    if (_lastAuthenticatedUser != null) return _lastAuthenticatedUser;
    try {
      final prefs = LocalCacheService.prefs;
      if (prefs != null) {
        final uid = prefs.getString('viscous_cached_auth_uid');
        final email = prefs.getString('viscous_cached_auth_email');
        final token = prefs.getString('viscous_cached_auth_token');
        if (uid != null && uid.isNotEmpty && email != null) {
          _lastAuthenticatedUser = AuthUserResult(
            uid: uid,
            email: email,
            idToken: token,
          );
        }
      }
    } catch (_) {}
    return _lastAuthenticatedUser;
  }

  static void _setLastAuthenticatedUser(AuthUserResult? result) {
    _lastAuthenticatedUser = result;
    try {
      final prefs = LocalCacheService.prefs;
      if (prefs != null) {
        if (result != null) {
          prefs.setString('viscous_cached_auth_uid', result.uid);
          prefs.setString('viscous_cached_auth_email', result.email);
          if (result.idToken != null) {
            prefs.setString('viscous_cached_auth_token', result.idToken!);
          }
        } else {
          prefs.remove('viscous_cached_auth_uid');
          prefs.remove('viscous_cached_auth_email');
          prefs.remove('viscous_cached_auth_token');
        }
      }
    } catch (_) {}
  }

  FirebaseAuthService([FirebaseAuth? auth, Dio? dio])
      : _customAuth = auth,
        _dio = dio ?? Dio();

  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  String _getApiKey() {
    try {
      final key = DefaultFirebaseOptions.currentPlatform.apiKey;
      if (key.isNotEmpty && !key.startsWith('AIzaSyC2V8H')) {
        return key;
      }
    } catch (_) {}
    return DefaultFirebaseOptions.web.apiKey;
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  User? get currentFirebaseUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  String? get currentUserId {
    try {
      final u = _auth.currentUser;
      if (u != null) return u.uid;
    } catch (_) {}
    return _lastAuthenticatedUser?.uid;
  }

  Future<AuthUserResult> signInWithEmailPassword(String email, String password) async {
    final cleanEmail = email.trim();

    // On Windows desktop, official firebase_auth plugin has no C++ desktop channel.
    // Use Google Firebase Identity Toolkit REST API directly.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _restSignIn(cleanEmail, password);
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final firebaseUser = cred.user;
      final uid = firebaseUser?.uid ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
      final idToken = await firebaseUser?.getIdToken();
      final result = AuthUserResult(
        uid: uid,
        email: cleanEmail,
        idToken: idToken,
        rawFirebaseUser: firebaseUser,
      );
      _setLastAuthenticatedUser(result);
      return result;
    } on FirebaseAuthException catch (e) {
      throw Exception(_translateFirebaseError(e.code));
    } catch (e) {
      debugPrint('[FirebaseAuth] Native plugin exception: $e. Falling back to Identity Toolkit REST.');
      return _restSignIn(cleanEmail, password);
    }
  }

  Future<AuthUserResult> signUpWithEmailPassword(String email, String password) async {
    final cleanEmail = email.trim();

    // On Windows desktop, official firebase_auth plugin has no C++ desktop channel.
    // Use Google Firebase Identity Toolkit REST API directly.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      return _restSignUp(cleanEmail, password);
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final firebaseUser = cred.user;
      final uid = firebaseUser?.uid ?? 'usr_${DateTime.now().millisecondsSinceEpoch}';
      final idToken = await firebaseUser?.getIdToken();
      final result = AuthUserResult(
        uid: uid,
        email: cleanEmail,
        idToken: idToken,
        rawFirebaseUser: firebaseUser,
      );
      _setLastAuthenticatedUser(result);
      return result;
    } on FirebaseAuthException catch (e) {
      throw Exception(_translateFirebaseError(e.code));
    } catch (e) {
      debugPrint('[FirebaseAuth] Native plugin exception: $e. Falling back to Identity Toolkit REST.');
      return _restSignUp(cleanEmail, password);
    }
  }

  Future<AuthUserResult> _restSignUp(String email, String password) async {
    final apiKey = _getApiKey();
    final url = 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey';

    try {
      final response = await _dio.post(
        url,
        data: {
          'email': email,
          'password': password,
          'returnSecureToken': true,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final data = response.data as Map<String, dynamic>;
      final result = AuthUserResult(
        uid: data['localId'] as String,
        email: data['email'] as String? ?? email,
        idToken: data['idToken'] as String?,
        refreshToken: data['refreshToken'] as String?,
      );
      _setLastAuthenticatedUser(result);
      debugPrint('[FirebaseAuth] Live Firebase Auth user registered via REST: ${result.uid} (${result.email})');
      return result;
    } on DioException catch (dioError) {
      throw _handleDioAuthError(dioError);
    } catch (e) {
      throw Exception('Failed to connect to Firebase Authentication: $e');
    }
  }

  Future<AuthUserResult> _restSignIn(String email, String password) async {
    final apiKey = _getApiKey();
    final url = 'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey';

    try {
      final response = await _dio.post(
        url,
        data: {
          'email': email,
          'password': password,
          'returnSecureToken': true,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      final data = response.data as Map<String, dynamic>;
      final result = AuthUserResult(
        uid: data['localId'] as String,
        email: data['email'] as String? ?? email,
        idToken: data['idToken'] as String?,
        refreshToken: data['refreshToken'] as String?,
      );
      _setLastAuthenticatedUser(result);
      debugPrint('[FirebaseAuth] Live Firebase Auth user signed in via REST: ${result.uid} (${result.email})');
      return result;
    } on DioException catch (dioError) {
      throw _handleDioAuthError(dioError);
    } catch (e) {
      throw Exception('Failed to sign in via Firebase: $e');
    }
  }

  Exception _handleDioAuthError(DioException dioError) {
    final respData = dioError.response?.data;
    if (respData != null) {
      try {
        final errorMap = (respData is Map) ? (respData['error'] as Map?) : null;
        final rawMsg = errorMap?['message']?.toString() ?? '';
        return Exception(_translateFirebaseError(rawMsg));
      } catch (_) {}
    }
    return Exception('Firebase network error: ${dioError.message ?? "Unable to reach Firebase"}');
  }

  String _translateFirebaseError(String code) {
    final upper = code.toUpperCase();
    if (upper.contains('EMAIL_EXISTS')) {
      return 'This email address is already registered. Please sign in instead.';
    }
    if (upper.contains('WEAK_PASSWORD')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }
    if (upper.contains('INVALID_EMAIL')) {
      return 'The email address format is invalid.';
    }
    if (upper.contains('INVALID_LOGIN_CREDENTIALS') ||
        upper.contains('INVALID-CREDENTIAL') ||
        upper.contains('INVALID_CREDENTIAL') ||
        upper.contains('EMAIL_NOT_FOUND') ||
        upper.contains('INVALID_PASSWORD') ||
        upper.contains('USER_NOT_FOUND') ||
        upper.contains('WRONG_PASSWORD')) {
      return 'Invalid email or password. Please verify your credentials or tap a Quick Demo Login.';
    }
    if (upper.contains('USER_DISABLED')) {
      return 'This user account has been disabled.';
    }
    if (upper.contains('TOO_MANY_ATTEMPTS_TRY_LATER') || upper.contains('TOO-MANY-REQUESTS')) {
      return 'Too many attempts. Access is temporarily disabled. Please try again later.';
    }
    if (upper.contains('OPERATION_NOT_ALLOWED')) {
      return 'Email/password sign-in is not enabled in Firebase Console.';
    }
    return 'Authentication error: $code';
  }

  Future<void> signOut() async {
    _setLastAuthenticatedUser(null);
    try {
      await _auth.signOut().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }
}
