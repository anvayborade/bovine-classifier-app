import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../router.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../widgets/appbars.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/ui_kit.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _picker = ImagePicker();
  XFile? _file;
  Uint8List? _bytes;
  String? _error;
  Map<String, dynamic>? _resp;
  String _model = 'ensemble';

  // ====== FUNCTIONALITY (unchanged) ======
  Future<void> _pick(bool camera) async {
    setState(() => _error = null);
    final x = camera
        ? await _picker.pickImage(source: ImageSource.camera, imageQuality: 92)
        : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (x == null) return;
    _bytes = await x.readAsBytes();
    setState(() {
      _file = x;
      _resp = null;
    });
  }

  Future<void> _predict() async {
    if (_bytes == null) return;
    try {
      final res = await ApiService.predict(modelKey: _model, bytes: _bytes!);
      setState(() => _resp = res);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _addToHerd() async {
    final breed = _resp?['label']?.toString();
    if (breed == null) return;
    try {
      await DbService.addBreed(breed);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Added $breed to your herd')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  // ====== UI HELPERS ======
  Widget _softSection({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.95),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
      ],
    ),
    child: child,
  );

  Widget _sectionHeader(String title, {Widget? trailing}) => Row(
    children: [
      Expanded(
        child: Text(title,
            style:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      if (trailing != null) trailing,
    ],
  );

  @override
  Widget build(BuildContext c) {
    final imgWidget = _file == null
        ? Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text('No image selected',
            style: TextStyle(color: Colors.black54)),
      ),
    )
        : ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: kIsWeb
          ? Image.memory(_bytes!,
          height: 200, width: double.infinity, fit: BoxFit.cover)
          : Image.file(File(_file!.path),
          height: 200, width: double.infinity, fit: BoxFit.cover),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: topLevelAppBar('Bovine Dashboard', transparent: true),
      drawer: const DrawerMenu(),
      body: GradientWrap(
        // soft green vibe like your reference UI
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                // ====== TOP: WEATHER + QUICK ACTIONS ======
                _softSection(
                  child: Column(
                    children: [
                      // mini header bar
                      Row(
                        children: const [
                          Icon(Icons.grass, color: Color(0xFF2E7D32)),
                          SizedBox(width: 8),
                          Text('Welcome to your farm',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Weather chip
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7F7EE),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: const [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: Color(0xFFB8EFC9),
                                    child: Icon(Icons.wb_sunny_outlined,
                                        color: Color(0xFF2E7D32)),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text('34°C • No Rain • 43% • 9.4 km/h',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Notifications shortcut
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7F7EE),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.notifications_none,
                                  color: Color(0xFF2E7D32)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Quick actions grid
                      _sectionHeader('Quick Actions'),
                      const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisExtent: 128, // was using childAspectRatio; this avoids overflow
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (_, i) => [
              _ActionTile(icon: Icons.psychology_alt_outlined, label: 'AI Predictor', onTap: () {}),
              _ActionTile(icon: Icons.vaccines_outlined, label: 'Vaccination', onTap: () => Navigator.pushNamed(context, '/vaccinations')),
              _ActionTile(icon: Icons.fact_check_outlined, label: 'Vax Log', onTap: () => Navigator.pushNamed(context, '/vaccination-log')),
              _ActionTile(icon: Icons.agriculture, label: 'Crossbreed', onTap: () => Navigator.pushNamed(context, '/crossbreed')),
              _ActionTile(icon: Icons.store_mall_directory_outlined, label: 'Marketplace', onTap: () => Navigator.pushNamed(context, '/market')),
              _ActionTile(icon: Icons.local_grocery_store_outlined, label: 'Dairy Market', onTap: () => Navigator.pushNamed(context, '/dairy-market')),
            ][i],
          ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ====== CENTERPIECE: AI PREDICTOR ======
                _softSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('AI Breed Predictor',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 8),
                              const Icon(Icons.tune, color: Colors.black54),
                              const SizedBox(width: 6),
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _model,
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'ensemble',
                                        child: Text('Ensemble (All 3)')),
                                    DropdownMenuItem(
                                        value: 'effb0_d1d3',
                                        child: Text('EfficientNet-B0')),
                                    DropdownMenuItem(
                                        value: 'mnv3l',
                                        child: Text('MobileNetV3-L')),
                                    DropdownMenuItem(
                                        value: 'effv2s',
                                        child: Text('EfficientNetV2-S')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _model = v!),
                                ),
                              ),
                            ],
                          )),
                      const SizedBox(height: 12),
                      // Image preview
                      imgWidget,
                      const SizedBox(height: 12),
                      // Controls
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          PillButton(
                            icon: Icons.photo_library,
                            label: 'Gallery',
                            onPressed: () => _pick(false),
                          ),
                          PillButton(
                            icon: Icons.camera_alt,
                            label: 'Camera',
                            onPressed: () => _pick(true),
                          ),
                          PillButton(
                            icon: Icons.psychology,
                            label: 'Predict',
                            onPressed: _bytes != null ? _predict : null,
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(_error!,
                            style:
                            const TextStyle(color: Colors.redAccent)),
                      ],
                    ],
                  ),
                ),

                // ====== RESULT ======
                if (_resp != null) ...[
                  const SizedBox(height: 16),
                  _softSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Prediction: ${_resp!['label']}  (${((_resp!['confidence'] as num) * 100).toStringAsFixed(1)}%)",
                          style: Theme.of(c)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        // top-5 as neat rows + chips
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FBF9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Top-5',
                                  style:
                                  TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              ...((_resp!['top5'] as List).map((e) => Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e[0].toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  Text(
                                      '${((e[1] as num) * 100).toStringAsFixed(1)}%'),
                                ],
                              ))),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        PillButton(
                          icon: Icons.add,
                          label: 'Add to my herd',
                          onPressed: _addToHerd,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ====== DAILY TASKS (optional pretty section) ======
                _softSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader('Daily Tasks', trailing: TextButton.icon(
                          onPressed: () {}, icon: const Icon(Icons.add, size: 18), label: const Text('Add Task'))),
                      const SizedBox(height: 8),
                      const _TaskRow('Milk cows'),
                      const _TaskRow('Check feed inventory'),
                      const _TaskRow('Plan vaccinations'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====== small widgets ======
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: const Color(0xFFE7F7EE),
              child: Icon(icon, color: const Color(0xFF2E7D95), size: 26),
            ),
            const SizedBox(height: 10),
        // inside _ActionTile
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
        ),
          ],
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final String text;
  const _TaskRow(this.text);
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle_outline, color: Color(0xFF2E7D32)),
      title: Text(text),
      trailing: IconButton(
        icon: const Icon(Icons.more_horiz),
        onPressed: () {},
      ),
    );
  }
}