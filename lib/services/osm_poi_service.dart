// lib/services/osm_poi_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class Poi {
  final int id;
  final String? name;
  final double lat;
  final double lon;
  final String category;
  final Map<String, dynamic> tags;

  Poi({
    required this.id,
    this.name,
    required this.lat,
    required this.lon,
    required this.category,
    required this.tags,
  });

  factory Poi.fromJson(Map<String, dynamic> j) => Poi(
    id: (j['id'] as num).toInt(),
    name: j['name'] as String?,
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
    category: j['category'] as String,
    tags: Map<String, dynamic>.from(j['tags'] ?? const {}),
  );
}

class OsmPoiService {
  final String baseUrl;   // http://10.0.2.2:8000 (Android) or http://localhost:8000
  final String apiPrefix; // '' or '/api'
  OsmPoiService(this.baseUrl, {this.apiPrefix = ''});

  Future<List<Poi>> nearbyMarkets({
    required double lat,
    required double lon,
    int radiusM = 15000,
  }) =>
      nearby(lat: lat, lon: lon, type: 'market', radiusM: radiusM);

  Future<List<Poi>> nearby({
    required double lat,
    required double lon,
    String type = 'vet', // 'vet' or 'market'
    int radiusM = 30000,
    int limit = 30,
    bool nocache = false,
  }) async {
    final nocacheStr = nocache ? '&nocache=1' : '';
    final uri = Uri.parse(
      '$baseUrl$apiPrefix/places'
          '?lat=$lat&lon=$lon&type=$type&radius_m=$radiusM&limit=$limit$nocacheStr',
    );
    // ignore: avoid_print
    print('GET $uri');

    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('Places error: ${res.statusCode} ${res.body}');
    }

    final decoded = json.decode(res.body);
    final List listJson;
    if (decoded is List) {
      listJson = decoded;
    } else if (decoded is Map && decoded['places'] is List) {
      listJson = decoded['places'] as List;
    } else {
      throw FormatException('Unexpected response shape: ${decoded.runtimeType}');
    }

    return listJson
        .map((e) => Poi.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}