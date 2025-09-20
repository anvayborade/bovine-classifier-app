import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/osm_poi_service.dart';
import '../services/tts_service.dart';
import '../widgets/appbars.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/ui_kit.dart';

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

  // thumbnails to cycle (1,2,3,1,2,3…)
  final List<ImageProvider> _thumbs = const [
    AssetImage('assets/market_thumbs/market_1.jpg'),
    AssetImage('assets/market_thumbs/market_2.jpg'),
    AssetImage('assets/market_thumbs/market_3.jpg'),
  ];
  ImageProvider _thumbFor(int index) => _thumbs[index % _thumbs.length];

  @override
  void dispose() {
    _breed.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

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

    // 1) Nearby marketplaces (location-only)
    try {
      final base = await ApiService.baseUrl();
      final poi = OsmPoiService(base, apiPrefix: '');
      final pos = await LocationService.current()
          .timeout(const Duration(seconds: 40), onTimeout: () => null);

      if (pos == null) {
        setState(() => _placesErr = 'Location unavailable (nearby marketplaces skipped).');
      } else {
        final results = await poi.nearby(
          lat: pos.latitude,
          lon: pos.longitude,
          type: 'market',
          radiusM: 15000,
        ).timeout(const Duration(seconds: 40));
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
    t = t.replaceAll(RegExp(r'\r\n?'), '\n');
    t = t.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!);
    t = t.replaceAll(RegExp(r'\([^)]*\)'), '');
    t = t.replaceAll(RegExp(r'[*_`>#~]'), '');
    t = t.replaceAll(RegExp(r'https?://\S+'), '');
    t = t.replaceAll(RegExp(r'\n\s*-\s'), '\n');
    t = t.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  }

  // Slower TTS rate (0.1–1.0; smaller = slower)
  static const double _ttsRate = 0.36;

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

      // ↓ slow down the voice
      await TtsService.instance.setRate(_ttsRate);
      // (If your TtsService supports a rate param instead, use:
      // await TtsService.instance.speakHindi(hindi, rate: _ttsRate);
      // and remove the line above.)

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
  Widget build(BuildContext c) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: topLevelAppBar('Marketplace', transparent: true),
      drawer: const DrawerMenu(),
      body: GradientWrap(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('Find markets near you'),
                      const SizedBox(height: 10),

                      // --- Input + Action ---
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Search by breed / product',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.white)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _breed,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _go(),
                              decoration: const InputDecoration(
                                labelText: 'Breed (e.g., Gir)',
                                prefixIcon: Icon(Icons.storefront),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                PillButton(
                                  icon: Icons.search,
                                  label: _busy ? 'Working…' : 'Suggest',
                                  onPressed: _busy ? null : _go,
                                ),
                                const SizedBox(width: 10),
                                StatChip(icon: Icons.place, label: 'Found', value: '${_places.length}'),
                              ],
                            ),
                            if (_placesErr != null) ...[
                              const SizedBox(height: 8),
                              Text(_placesErr!, style: const TextStyle(color: Colors.white)),
                            ],
                            if (_aiErr != null) ...[
                              const SizedBox(height: 4),
                              Text(_aiErr!, style: const TextStyle(color: Colors.white)),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // --- Places list, fixed-height, scrolls inside card ---
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: SizedBox(
                          height: 280, // shows ≥2 items
                          child: _loadingPlaces
                              ? const Center(child: CircularProgressIndicator())
                              : (_places.isEmpty && _placesErr == null
                              ? const Center(child: Text('No marketplaces found yet.'))
                              : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _places.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final p = _places[i];
                              final title = (p.name?.trim().isNotEmpty ?? false)
                                  ? p.name!
                                  : 'Unnamed market';
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  // thumbnail (cycles 1→2→3→1…)
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image(
                                      image: _thumbFor(i),
                                      width: 56, height: 56, fit: BoxFit.cover,
                                    ),
                                  ),
                                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text('lat ${p.lat.toStringAsFixed(5)}, '
                                      'lon ${p.lon.toStringAsFixed(5)}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.navigation),
                                    onPressed: () => _openMaps(p.lat, p.lon),
                                  ),
                                ),
                              );
                            },
                          )),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // --- Gemini advice (unchanged) ---
                      if (_loadingAi)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        ),
                      if (_text != null)
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Expanded(child: Text('Gemini Advice',
                                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white))),
                                TextButton.icon(
                                  onPressed: _toggleHindiTts,
                                  icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
                                  label: Text(_speaking ? 'रोकें' : 'Hindi mai suno'),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              Container(
                                height: 240,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.95),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Markdown(data: _text!),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}