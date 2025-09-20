import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';
import '../services/osm_poi_service.dart';
import '../widgets/appbars.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/ui_kit.dart';
import '../services/api_service.dart';

class VetsScreen extends StatefulWidget {
  const VetsScreen({super.key});
  @override
  State<VetsScreen> createState() => _VetsScreenState();
}

class _VetsScreenState extends State<VetsScreen> {
  bool _busy = false;
  String? _err;
  List<Poi> _vets = [];

  // Thumbnails (cycles 1→2→3→1…)
  final List<ImageProvider> _thumbs = const [
    AssetImage('assets/vet_thumbs/vet_1.jpg'),
    AssetImage('assets/vet_thumbs/vet_2.jpg'),
    AssetImage('assets/vet_thumbs/vet_3.jpg'),
  ];
  ImageProvider _thumbFor(int index) => _thumbs[index % _thumbs.length];

  Future<void> _find() async {
    setState(() { _busy = true; _err = null; _vets = []; });

    try {
      final pos = await LocationService.current();
      if (pos == null) {
        setState(() => _err = 'Location unavailable');
        return;
      }
      final base = await ApiService.baseUrl();
      final _poi = OsmPoiService(base, apiPrefix: '');
      final items = await _poi.nearby(
        lat: pos.latitude,
        lon: pos.longitude,
        type: 'vet',
        radiusM: 30000,
        limit: 20,
        nocache: true,
      );
      if (!mounted) return;
      setState(() => _vets = items);
      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No nearby vets found in the selected radius.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMaps(double lat, double lon) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: topLevelAppBar('Nearby veterinarians', transparent: true),
      drawer: const DrawerMenu(),
      body: GradientWrap(
        child: SafeArea(
          child: Column( // <-- back to Column so the next GlassCard expands
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Find help for your herd'),
              const SizedBox(height: 10),

              // Actions
              GlassCard(
                child: Row(
                  children: [
                    PillButton(
                      icon: Icons.search,
                      label: _busy ? 'Searching…' : 'Find nearby vets',
                      onPressed: _busy ? null : _find,
                    ),
                    const SizedBox(width: 10),
                    StatChip(icon: Icons.place, label: 'Found', value: '${_vets.length}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_err != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(_err!, style: const TextStyle(color: Colors.white)),
                ),

              // Results GlassCard fills the rest of the screen; list scrolls inside
              Expanded(
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: _busy
                      ? const Center(child: CircularProgressIndicator())
                      : (_vets.isEmpty
                      ? const Center(child: Text('No vets found yet.'))
                      : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _vets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = _vets[i];
                      final title = (p.name?.trim().isNotEmpty ?? false)
                          ? p.name!
                          : 'Unnamed clinic';
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image(
                              image: _thumbFor(i),
                              width: 56, height: 56, fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            'lat ${p.lat.toStringAsFixed(5)}, lon ${p.lon.toStringAsFixed(5)}',
                          ),
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
            ],
          ),
        ),
      ),
    );
  }
}