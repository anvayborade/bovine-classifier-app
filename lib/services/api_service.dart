// lib/services/api_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static const _keyUrl = 'apiBaseUrl';
  static const _keyTta = 'inference_tta';
  static const _keyGamma = 'inference_gamma';

  // ---- Base URL helpers -----------------------------------------------------

  static String _normalizeBase(String url) {
    final u = url.trim();
    if (u.isEmpty) return u;
    // Remove trailing slash only (keep protocol)
    return u.endsWith('/') ? u.substring(0, u.length - 1) : u;
  }

  static Uri _join(String base, String pathAndQuery) {
    // Ensure single leading slash on path
    final p = pathAndQuery.startsWith('/') ? pathAndQuery : '/$pathAndQuery';
    return Uri.parse('${_normalizeBase(base)}$p');
  }

  static Future<String> baseUrl() async {
    final sp = await SharedPreferences.getInstance();
    // NOTE: Physical device cannot reach 10.0.2.2.
    // Make sure you saved your Cloudflare HTTPS URL in Settings.
    return sp.getString(_keyUrl) ??
        (kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000');
  }

  static Future<void> saveBaseUrl(String url) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_keyUrl, _normalizeBase(url));
  }

  // ---- Inference prefs ------------------------------------------------------

  static Future<void> saveInference({required bool tta, required double gamma}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_keyTta, tta);
    await sp.setDouble(_keyGamma, gamma);
  }

  static Future<(bool, double)> loadInference() async {
    final sp = await SharedPreferences.getInstance();
    return (sp.getBool(_keyTta) ?? true, sp.getDouble(_keyGamma) ?? 2.0);
  }

  // ---- Healthcheck ----------------------------------------------------------

  static Future<bool> ping() async {
    final base = await baseUrl();
    final uri = _join(base, '/ping');
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---- Predict (image) ------------------------------------------------------

  static Future<Map<String, dynamic>> predict({
    required String modelKey,
    required Uint8List bytes,
    String weights = 'effb0_d1d3:0.294,mnv3l:0.341,effv2s:0.365',
  }) async {
    final base = await baseUrl();
    final (tta, gamma) = await loadInference();

    final uri = (modelKey == 'ensemble')
        ? _join(base, '/predict_ensemble?weights=${Uri.encodeComponent(weights)}&tta=$tta&gamma=${gamma.toStringAsFixed(3)}')
        : _join(base, '/predict?model=$modelKey&tta=$tta&gamma=${gamma.toStringAsFixed(3)}');

    final req = http.MultipartRequest('POST', uri);
    final mime = lookupMimeType('', headerBytes: bytes) ?? 'image/jpeg';
    final parts = mime.split('/');
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: 'image.jpg',
      contentType: MediaType(parts.first, parts.last),
    ));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamed).timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) {
      throw Exception('Server ${resp.statusCode}: ${resp.body}');
    }
    final body = resp.body;
    if (body.isEmpty) {
      throw const FormatException('Empty response body from /predict');
    }
    final decoded = json.decode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected response shape from /predict');
    }
    return decoded;
  }

  // ---- AI endpoints (Gemini-wrapped) ---------------------------------------

  /// Calls AI route like `/ai/crossbreed`, `/ai/market`, `/ai/dairy_market`, `/ai/vaccinations`.
  /// Returns non-empty `text` or throws with a clear message.
  static Future<String> ai(
      String path, {
        required String breed,
        String? location,
      }) async {
    final base = await baseUrl();
    final uri = _join(base, path);

    final r = await http
        .post(
      uri,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'breed': breed,
        // Send location only if provided; callers can omit it
        if (location != null) 'location': location,
      }),
    )
        .timeout(const Duration(seconds: 50));

    if (r.statusCode != 200) {
      throw Exception('Server ${r.statusCode}: ${r.body}');
    }

    if (r.body.isEmpty) {
      throw const FormatException('Empty AI response body');
    }

    final dynamic m;
    try {
      m = json.decode(r.body);
    } catch (e) {
      throw FormatException('AI response is not JSON: ${r.body}');
    }

    if (m is Map && m['error'] != null) {
      throw Exception(m['error'].toString());
    }

    // Enforce non-empty text to avoid “blank Markdown” rendering
    final text = (m is Map ? (m['text'] ?? '') : '').toString().trim();
    if (text.isEmpty) {
      throw const FormatException('AI response missing `text`');
    }
    return text;
  }

  // ---- (Legacy) OSM proxy search by free text (if you still use it) --------

  static Future<List<Map<String, dynamic>>> places({
    required String query,
    required double lat,
    required double lon,
    int limit = 10,
    double radiusKm = 50,
    String country = 'in',
  }) async {
    final base = await baseUrl();
    final uri = _join(
      base,
      '/places?q=${Uri.encodeComponent(query)}&lat=$lat&lon=$lon&limit=$limit&radius_km=$radiusKm&country=$country',
    );
    final r = await http.get(uri).timeout(const Duration(seconds: 40));
    if (r.statusCode != 200) {
      throw Exception('Places error: ${r.statusCode} ${r.body}');
    }
    if (r.body.isEmpty) return const [];
    final decoded = json.decode(r.body);
    // Accept both shapes: {"items":[...]} or top-level list
    if (decoded is Map && decoded['items'] is List) {
      return (decoded['items'] as List).cast<Map<String, dynamic>>();
    } else if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    // Unknown shape — return empty to avoid crashes
    return const [];
  }
}