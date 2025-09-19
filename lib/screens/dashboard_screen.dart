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

  @override
  Widget build(BuildContext c) {
    final imgWidget = _file == null
        ? Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: Text('No image selected')),
    )
        : ClipRRect(
      borderRadius: BorderRadius.circular(12),
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
        child: ListView(
          children: [
            // Model picker
            GlassCard(
              child: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Model:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _model,
                    dropdownColor: Colors.white,
                    items: const [
                      DropdownMenuItem(value: 'ensemble', child: Text('Ensemble (All 3)')),
                      DropdownMenuItem(value: 'effb0_d1d3', child: Text('EfficientNet-B0')),
                      DropdownMenuItem(value: 'mnv3l', child: Text('MobileNetV3-L')),
                      DropdownMenuItem(value: 'effv2s', child: Text('EfficientNetV2-S')),
                    ],
                    onChanged: (v) => setState(() => _model = v!),
                  ),
                ],
              ),
            ),

            // Image area
            GlassCard(child: imgWidget),

            // Controls
            GlassCard(
              child: Wrap(
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
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_error!, style: const TextStyle(color: Colors.white)),
              ),

            // Result card
            if (_resp != null)
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Prediction: ${_resp!['label']}  (${((_resp!['confidence'] as num) * 100).toStringAsFixed(1)}%)",
                      style: Theme.of(c).textTheme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Top-5:', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          ...((_resp!['top5'] as List).map((e) => Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e[0].toString()),
                              Text('${((e[1] as num) * 100).toStringAsFixed(1)}%'),
                            ],
                          ))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    PillButton(icon: Icons.add, label: 'Add to my herd', onPressed: _addToHerd),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}