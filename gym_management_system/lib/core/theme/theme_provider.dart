import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/local_cache_service.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final saved = LocalCacheService.prefs?.getString('vicious_theme_mode');
    if (saved == 'light') return ThemeMode.light;
    return ThemeMode.dark;
  }

  void toggleTheme() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    LocalCacheService.prefs?.setString(
      'vicious_theme_mode',
      next == ThemeMode.light ? 'light' : 'dark',
    );
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    LocalCacheService.prefs?.setString(
      'vicious_theme_mode',
      mode == ThemeMode.light ? 'light' : 'dark',
    );
  }

  bool get isDarkMode => state == ThemeMode.dark;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
