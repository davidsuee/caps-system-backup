class Env {
  // Toggle this flag to true to use live Firebase Auth & Firestore, or false for offline/mock demo mode
  static const bool useFirebase = true;

  // Python ML & Optimization Microservice URL
  // Use 10.0.2.2 for Android Emulator, 127.0.0.1 for Web / Windows / Desktop, or local network IP for physical device
  static const String mlApiBaseUrl = 'http://127.0.0.1:8000';

  static const String appName = 'VICIOUS Gym & Recommender System';
  static const String appVersion = '1.0.0';
}
