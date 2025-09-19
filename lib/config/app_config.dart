// lib/config/app_config.dart
//
// Centralized config for your backend base URL and API prefix.
// Works across Android emulator, iOS simulator, Web, and desktop.
// You can also override via --dart-define at run/build time.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConfig {
  // Optional compile-time overrides (recommended for staging/prod):
  // flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=API_PREFIX=/api
  static const String _envBaseUrl =
  String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _envApiPrefix =
  String.fromEnvironment('API_PREFIX', defaultValue: '');

  /// Base URL (protocol + host + port), no trailing slash.
  /// Defaults:
  /// - Web/iOS/desktop: http://localhost:8000
  /// - Android emulator: http://10.0.2.2:8000
  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;

    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) return 'http://localhost:8000';
    } catch (_) {
      // Platform may not be available (e.g., in tests); fall through.
    }
    return 'http://localhost:8000';
  }

  /// If your FastAPI is mounted with a prefix (e.g., app.include_router(..., prefix="/api")),
  /// set this to '/api'. Otherwise, leave it ''.
  static String get apiPrefix => _envApiPrefix.isNotEmpty ? _envApiPrefix : '';

  /// Helper to build full URIs consistently.
  /// Example: AppConfig.uri('/places', {'lat': 19.0760, 'lon': 72.8777})
  static Uri uri(String path, [Map<String, dynamic>? query]) {
    final base = '$apiBaseUrl$apiPrefix$path';
    if (query == null || query.isEmpty) return Uri.parse(base);
    // Ensure all values are strings.
    final qp = query.map((k, v) => MapEntry(k, '$v'));
    return Uri.parse(base).replace(queryParameters: qp);
  }
}