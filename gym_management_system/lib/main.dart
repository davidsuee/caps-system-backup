import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/env.dart';
import 'config/firebase_options.dart';
import 'data/datasources/local/local_cache_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCacheService.initialize();

  // Initialize Firebase with the connected project gymmanagementcaps
  if (Env.useFirebase) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[Firebase] Initialized successfully with project: gymmanagementcaps');
    } catch (e) {
      debugPrint('[Firebase] Initialization error: $e. Proceeding with offline-first state.');
    }
  }

  runApp(
    const ProviderScope(
      child: ViscousApp(),
    ),
  );
}