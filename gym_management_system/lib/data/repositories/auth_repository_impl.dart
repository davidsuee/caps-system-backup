import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../config/env.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';
import '../models/progress_log_model.dart';
import '../datasources/remote/firebase_auth_service.dart';
import '../datasources/remote/firestore_service.dart';
import '../datasources/local/local_cache_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthService _firebaseAuth;
  final FirestoreService _firestore;
  final LocalCacheService _localCache;

  AuthRepositoryImpl({
    FirebaseAuthService? firebaseAuth,
    FirestoreService? firestore,
    LocalCacheService? localCache,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuthService(),
        _firestore = firestore ?? FirestoreService(),
        _localCache = localCache ?? LocalCacheService();

  @override
  Future<UserEntity?> getCurrentUser() async {
    if (Env.useFirebase) {
      try {
        final currentUid = _firebaseAuth.currentUserId;
        if (currentUid != null) {
          final userModel = await _firestore.getUser(currentUid);
          if (userModel != null) {
            _localCache.saveUser(userModel);
            _localCache.setCurrentUser(userModel);
            return userModel;
          }
        }
      } catch (e) {
        debugPrint('[AuthRepository] Error checking current user: $e');
      }
    }
    return _localCache.getCurrentUser();
  }

  String _resolveDemoEmailAlias(String email) {
    final e = email.toLowerCase().trim();
    if (e == 'coach@viscious.com' ||
        e == 'coach@viscous.com' ||
        e == 'coach@vicious.com' ||
        e == 'coach.marcus@gym.com' ||
        e == 'marcus@gym.com' ||
        e == 'coach@gym.ph') {
      return 'coach@gym.com';
    }
    if (e == 'admin@viscious.com' ||
        e == 'admin@viscous.com' ||
        e == 'admin@vicious.com' ||
        e == 'admin@gym.com' ||
        e == 'admin@gym.ph' ||
        e == 'sarah.admin@gym.com') {
      return 'staff@gym.com';
    }
    if (e == 'member@viscious.com' || e == 'member@vicious.com' || e == 'member@gym.com') {
      return 'sarah.j@example.com';
    }
    return e;
  }

  @override
  Future<UserEntity> signInWithEmailPassword(String email, String password) async {
    final cleanEmail = email.toLowerCase().trim();
    final resolvedEmail = _resolveDemoEmailAlias(cleanEmail);

    if (Env.useFirebase) {
      try {
        final cred = await _firebaseAuth.signInWithEmailPassword(resolvedEmail, password);
        final uid = cred.uid;
        var user = await _firestore.getUser(uid);
        if (user == null) {
          user = _localCache.getUserByEmail(resolvedEmail) ?? _localCache.getUserByEmail(cleanEmail);
          if (user == null) {
            final inferredRole = _inferRoleFromEmail(resolvedEmail);
            user = UserModel(
              id: uid,
              name: resolvedEmail.split('@').first,
              email: resolvedEmail,
              role: inferredRole,
              createdAt: DateTime.now(),
            );
            await _firestore.saveUser(user);
          }
        }
        _localCache.saveUser(user);
        _localCache.saveUserPassword(cleanEmail, password);
        _localCache.setCurrentUser(user);
        return user;
      } catch (e) {
        debugPrint('[AuthRepository] Firebase SignIn failed: $e');

        // Check local pre-seeded or Admin-created accounts
        final cached = _localCache.getUserByEmail(resolvedEmail) ??
            _localCache.getUserByEmail(cleanEmail);
        if (cached != null) {
          if (!_localCache.verifyUserPassword(cached.email, password)) {
            throw Exception('Incorrect password. Please verify your credentials or contact the gym administrator.');
          }
          _localCache.setCurrentUser(cached);
          return cached;
        }

        // Capstone fallback: Head Coach (Coach Marcus Vance)
        if (resolvedEmail == 'coach@gym.com' || cleanEmail == 'coach@gym.com') {
          final demoCoach = _localCache.getUserById('coach_demo_01') ??
              _localCache.getUsersByRole(UserRole.coach).firstOrNull;
          if (demoCoach != null) {
            if (!_localCache.verifyUserPassword(demoCoach.email, password)) {
              throw Exception('Incorrect password. Please verify your credentials or contact the gym administrator.');
            }
            _localCache.setCurrentUser(demoCoach);
            return demoCoach;
          }
        } else if (cleanEmail.contains('admin') || cleanEmail.contains('staff')) {
          final demoAdmin = _localCache.getUserById('admin_demo_01') ??
              _localCache.getUsersByRole(UserRole.admin).firstOrNull;
          if (demoAdmin != null) {
            _localCache.setCurrentUser(demoAdmin);
            return demoAdmin;
          }
        } else if (cleanEmail.contains('member') || cleanEmail.contains('sarah')) {
          final demoMember = _localCache.getUserById('member_seed_01') ??
              _localCache.getUsersByRole(UserRole.member).firstOrNull;
          if (demoMember != null) {
            _localCache.setCurrentUser(demoMember);
            return demoMember;
          }
        } else if (cleanEmail.contains('coach') || cleanEmail.contains('trainer')) {
          throw Exception('No coach account found for "$cleanEmail". Coach accounts can only be created by an Admin.');
        }

        rethrow;
      }
    }

    final user = _localCache.getUserByEmail(resolvedEmail) ?? _localCache.getUserByEmail(cleanEmail);
    if (user != null) {
      if (!_localCache.verifyUserPassword(user.email, password)) {
        throw Exception('Incorrect password. Please verify your credentials or contact the gym administrator.');
      }
      _localCache.setCurrentUser(user);
      return user;
    }

    if (cleanEmail.contains('coach') || cleanEmail.contains('trainer')) {
      throw Exception('No coach account found for "$cleanEmail". Coach accounts can only be created by an Admin.');
    }

    throw Exception('No account found for "$cleanEmail". Please create an account or verify your credentials.');
  }

  UserRole _inferRoleFromEmail(String email) {
    if (email.contains('admin') || email.contains('staff')) {
      return UserRole.admin;
    }
    // Any self-registered or inferred role is strictly member. Coach accounts must be Admin-created.
    return UserRole.member;
  }

  @override
  Future<UserEntity> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    required int age,
    required double heightCm,
    required double weightKg,
    required String gender,
    required String fitnessGoal,
    required String activityLevel,
    required String experienceLevel,
  }) async {
    if (role == UserRole.coach) {
      throw Exception('Coach accounts cannot be self-registered. They must be registered by a Gym Administrator.');
    }

    final cleanEmail = email.toLowerCase().trim();

    if (Env.useFirebase) {
      try {
        final cred = await _firebaseAuth.signUpWithEmailPassword(cleanEmail, password);
        final uid = cred.uid;
        final user = UserModel(
          id: uid,
          name: name,
          email: cleanEmail,
          role: role,
          age: age,
          heightCm: heightCm,
          weightKg: weightKg,
          gender: gender,
          fitnessGoal: fitnessGoal,
          activityLevel: activityLevel,
          experienceLevel: experienceLevel,
          createdAt: DateTime.now(),
        );
        await _firestore.saveUser(user);
        final initialLog = ProgressLogModel(
          id: const Uuid().v4(),
          userId: uid,
          date: DateTime.now(),
          weightKg: weightKg,
          notes: 'Initial weigh-in',
        );
        try {
          await _firestore.addProgressLog(initialLog);
        } catch (_) {}
        _localCache.saveUser(user);
        _localCache.saveUserPassword(cleanEmail, password);
        _localCache.setCurrentUser(user);
        _localCache.addProgressLog(initialLog);
        return user;
      } catch (e) {
        debugPrint('[AuthRepository] Firebase SignUp error: $e');
        // Do NOT swallow errors and fake success when Firebase is enabled.
        // Rethrow so the user sees the real Firebase error message.
        rethrow;
      }
    }

    // Offline-only mock path when Env.useFirebase is set to false
    final newUser = UserModel(
      id: const Uuid().v4(),
      name: name,
      email: cleanEmail,
      role: role,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      gender: gender,
      fitnessGoal: fitnessGoal,
      activityLevel: activityLevel,
      experienceLevel: experienceLevel,
      createdAt: DateTime.now(),
    );
    final initialLog = ProgressLogModel(
      id: const Uuid().v4(),
      userId: newUser.id,
      date: DateTime.now(),
      weightKg: weightKg,
      notes: 'Initial weigh-in',
    );
    _localCache.saveUser(newUser);
    _localCache.saveUserPassword(cleanEmail, password);
    _localCache.setCurrentUser(newUser);
    _localCache.addProgressLog(initialLog);
    return newUser;
  }

  @override
  Future<void> signOut() async {
    if (Env.useFirebase) {
      try {
        await _firebaseAuth.signOut();
      } catch (_) {}
    }
    _localCache.setCurrentUser(null);
  }

  @override
  Future<void> updateUserProfile(UserEntity user) async {
    final model = UserModel.fromEntity(user);
    if (Env.useFirebase) {
      try {
        await _firestore.saveUser(model);
      } catch (_) {}
    }
    _localCache.saveUser(model);
    _localCache.setCurrentUser(model);
  }
}
