import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/osm_poi_service.dart';
import '../services/tts_service.dart';
import '../widgets/appbars.dart';
import '../widgets/drawer_menu.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _breed = TextEditingController();

  // Places state
  bool _loadingPlaces = false;
  List<Poi> _places = [];
  String? _placesErr;

  // AI state
  bool _loadingAi = false;
  String? _text;   // Gemini markdown
  String? _aiErr;

  // TTS
  bool _speaking = false;

  bool get _busy => _loadingPlaces || _loadingAi;

  Future<void> _go() async {
    final breed = _breed.text.trim();
    if (breed.isEmpty) {
      setState(() => _aiErr = 'Please enter a breed name first.');
      return;
    }

    setState(() {
      _places = [];
      _text = null;
      _placesErr = null;
      _aiErr = null;
      _loadingPlaces = true;
      _loadingAi = false;
      _speaking = false;
    });

    // 1) Nearby marketplaces (location-only; AI won’t use location)
    try {
      final base = await ApiService.baseUrl();
      final poi = OsmPoiService(base, apiPrefix: '');
      final pos = await LocationService.current()
          .timeout(const Duration(seconds: 12), onTimeout: () => null);

      if (pos == null) {
        setState(() => _placesErr = 'Location unavailable (nearby marketplaces skipped).');
      } else {
        final results = await poi
            .nearby(
          lat: pos.latitude,
          lon: pos.longitude,
          type: 'market',
          radiusM: 15000,
        )
            .timeout(const Duration(seconds: 12));
        if (!mounted) return;
        setState(() => _places = results);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _placesErr = 'Failed to load marketplaces: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loadingPlaces = false);
    }

    // 2) AI advice (breed only)
    setState(() { _loadingAi = true; _text = null; _aiErr = null; });
    try {
      final t = await ApiService.ai('/ai/market', breed: breed);
      if (!mounted) return;
      setState(() => _text = t);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiErr = '$e');
    } finally {
      if (!mounted) return;
      setState(() => _loadingAi = false);
    }
  }

  // --- TTS helpers (translate to Hindi first, and sanitize) ------------------

  String _toPlainForTts(String s) {
    var t = s;
    t = t.replaceAll(RegExp(r'\r\n?'), '\n');                                   // CRLF -> LF
    t = t.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!); // [label](url) -> label
    t = t.replaceAll(RegExp(r'\([^)]*\)'), '');                                 // remove (..)
    t = t.replaceAll(RegExp(r'[*_`>#~]'), '');                                  // strip md symbols
    t = t.replaceAll(RegExp(r'https?://\S+'), '');                              // strip urls
    t = t.replaceAll(RegExp(r'\n\s*-\s'), '\n');                                // bullets
    t = t.replaceAll(RegExp(r'[ \t]{2,}'), ' ');                                // spaces
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');                                // newlines
    return t.trim();
  }

  Future<void> _toggleHindiTts() async {
    if (_text == null) return;
    if (_speaking) {
      await TtsService.instance.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    try {
      final plain = _toPlainForTts(_text!);
      String hindi;
      try {
        hindi = await ApiService.ai('/ai/translate_hi', breed: plain);
      } catch (_) {
        hindi = plain;
      }
      await TtsService.instance.speakHindi(hindi);
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _openMaps(double lat, double lon) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _breed.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: topLevelAppBar('Marketplace'),
    drawer: const DrawerMenu(),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _breed,
            decoration: const InputDecoration(
              labelText: 'Breed (e.g., Gir)',
              prefixIcon: Icon(Icons.storefront),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _go,
            child: _busy
                ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Suggest'),
          ),
          const SizedBox(height: 12),

          if (_placesErr != null)
            Text(_placesErr!, style: const TextStyle(color: Colors.red)),
          if (_aiErr != null)
            Text(_aiErr!, style: const TextStyle(color: Colors.red)),

          // --- Places list takes the flexible height ---
          Expanded(
            child: _loadingPlaces
                ? const Center(child: CircularProgressIndicator())
                : ListView(
              children: [
                if (_places.isNotEmpty) ...[
                  const Text('Nearby marketplaces:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                ],
                if (_places.isEmpty && _placesErr == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No marketplaces found yet.'),
                  ),
                ..._places.map((p) {
                  final title =
                  (p.name?.trim().isNotEmpty ?? false) ? p.name! : 'Unnamed market';
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.storefront),
                        title: Text(title),
                        subtitle: Text(
                            'lat ${p.lat.toStringAsFixed(5)}, lon ${p.lon.toStringAsFixed(5)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.directions),
                          onPressed: () => _openMaps(p.lat, p.lon),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // --- AI advice block rendered BELOW the list ---
          if (_loadingAi) const SizedBox(height: 8),
          if (_loadingAi)
            const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),

          if (_text != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _toggleHindiTts,
                  icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                  label: Text(_speaking ? 'रोकें' : 'Hindi mai suno'),
                ),
              ],
            ),
            // Give the advice its own fixed-height block so it never fights the list.
            Container(
              height: 240,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Markdown(data: _text!),
            ),
          ],
        ],
      ),
    ),
  );
}