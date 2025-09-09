import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

void main() => runApp(const BovineApp());

class BovineApp extends StatelessWidget {
  const BovineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bovine Breed Classifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,

        // ✅ belongs here, not in ChipThemeData
        visualDensity: VisualDensity.compact,

        // Optional chip styling that works across versions
        chipTheme: const ChipThemeData(
          padding: EdgeInsets.symmetric(horizontal: 8),
          labelPadding: EdgeInsets.symmetric(horizontal: 6),
          shape: StadiumBorder(),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class PredictResponse {
  final String model;
  final String label;
  final double confidence;
  final List<MapEntry<String, double>> top5;

  PredictResponse({
    required this.model,
    required this.label,
    required this.confidence,
    required this.top5,
  });

  factory PredictResponse.fromJson(Map<String, dynamic> json) {
    final rawTop5 = (json['top5'] as List)
        .map((e) => MapEntry<String, double>(e[0] as String, (e[1] as num).toDouble()))
        .toList();
    return PredictResponse(
      model: json['model'] as String,
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      top5: rawTop5,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ---------- Runtime-configurable base URL ----------
  static const _prefsKey = 'apiBaseUrl';
  String _apiBase = ''; // decided in initState
  bool _apiReachable = false;

  final ImagePicker _picker = ImagePicker();
  XFile? _xfile;
  Uint8List? _webImageBytes;

  PredictResponse? _result;
  bool _loading = false;
  String? _error;

  // Model options match FastAPI keys
  final Map<String, String> _modelOptions = const {
    'ensemble': 'Ensemble (All 3)',
    'effb0_d1d3': 'EfficientNet-B0 (d1d3)',
    'mnv3l': 'MobileNetV3-L',
    'effv2s': 'EfficientNetV2-S',
  };
  String _selectedModel = 'ensemble';

  // Ensemble / inference controls
  bool _tta = true;
  double _gamma = 2.0;
  double _wEffb0 = 0.294, _wMnv3l = 0.341, _wEffv2s = 0.365;

  @override
  void initState() {
    super.initState();
    _initApiBase();
  }

  Future<void> _initApiBase() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);

    // smart defaults
    String def;
    if (kIsWeb) {
      // if your web app is served over https, prefer https API to avoid mixed content
      final isHttps = Uri.base.scheme == 'https';
      def = isHttps ? 'https://YOUR_PUBLIC_HOST:8000' : 'http://localhost:8000';
    } else {
      // emulator vs. real device
      if (_isAndroidEmulator()) {
        def = 'http://10.0.2.2:8000';
      } else {
        def = 'http://192.168.1.2:8000'; // harmless placeholder; user can change in Settings
      }
    }

    setState(() => _apiBase = saved?.trim().isNotEmpty == true ? saved!.trim() : def);
    _checkReachability();
  }

  bool _isAndroidEmulator() {
    // crude but good enough: on Android + not web + running on emulator uses 10.0.2.2 default
    try {
      return !kIsWeb && Platform.isAndroid && !Platform.isIOS && !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkReachability() async {
    if (_apiBase.isEmpty) return;
    try {
      // Try /ping first, else /models
      final uriPing = Uri.parse('$_apiBase/ping');
      final r1 = await http.get(uriPing).timeout(const Duration(seconds: 3));
      if (r1.statusCode == 200) {
        setState(() => _apiReachable = true);
        return;
      }
    } catch (_) {}
    try {
      final uriModels = Uri.parse('$_apiBase/models');
      final r2 = await http.get(uriModels).timeout(const Duration(seconds: 3));
      setState(() => _apiReachable = r2.statusCode == 200);
    } catch (_) {
      setState(() => _apiReachable = false);
    }
  }

  Future<void> _openSettings() async {
    final controller = TextEditingController(text: _apiBase);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controllerSheet) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: const [BoxShadow(blurRadius: 12, offset: Offset(0, -4), color: Colors.black12)],
          ),
          child: ListView(
            controller: controllerSheet,
            children: [
              Row(
                children: [
                  Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Settings', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 16),
              Text('Server URL', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.link),
                  hintText: 'http://host:8000',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final val = controller.text.trim();
                  if (val.isEmpty) return;
                  setState(() => _apiBase = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(_prefsKey, _apiBase);
                  Navigator.pop(context);
                  _checkReachability();
                },
                icon: const Icon(Icons.save),
                label: const Text('Save & Test'),
              ),
              const Divider(height: 32),
              Text('Ensemble Weights', style: Theme.of(context).textTheme.labelLarge),
              _weightSlider('EffB0 d1d3', _wEffb0, (v) => setState(() => _wEffb0 = v)),
              _weightSlider('MNV3-L', _wMnv3l, (v) => setState(() => _wMnv3l = v)),
              _weightSlider('EffV2-S', _wEffv2s, (v) => setState(() => _wEffv2s = v)),
              const SizedBox(height: 8),
              Text('Boost (Gamma)', style: Theme.of(context).textTheme.labelLarge),
              Slider(
                value: _gamma, min: 0.5, max: 4.0, divisions: 35,
                label: _gamma.toStringAsFixed(2),
                onChanged: (v) => setState(() => _gamma = v),
              ),
              SwitchListTile(
                value: _tta,
                onChanged: (v) => setState(() => _tta = v),
                title: const Text('TTA (horizontal flip)'),
                secondary: const Icon(Icons.flip),
              ),
              const SizedBox(height: 12),
              const Text('Tip: For different networks, expose your API with a public URL (e.g., Cloudflare Tunnel) and paste it here.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weightSlider(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        Expanded(
          child: Slider(
            value: value, min: 0.0, max: 1.0, divisions: 100,
            label: value.toStringAsFixed(3),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    setState(() { _result = null; _error = null; });
    try {
      final XFile? picked = fromCamera
          ? await _picker.pickImage(source: ImageSource.camera, imageQuality: 92)
          : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
      if (picked != null) {
        if (kIsWeb) {
          final b = await picked.readAsBytes();
          setState(() { _xfile = picked; _webImageBytes = b; });
        } else {
          setState(() { _xfile = picked; _webImageBytes = null; });
        }
      }
    } catch (e) {
      setState(() => _error = 'Image pick failed: $e');
    }
  }

  String _weightsQuery() {
    // normalize to sum=1 server-side, but we send raw for clarity
    String f(double d) => d.toStringAsFixed(3);
    return 'effb0_d1d3:${f(_wEffb0)},mnv3l:${f(_wMnv3l)},effv2s:${f(_wEffv2s)}';
  }

  Future<void> _predict() async {
    if (_xfile == null || _apiBase.isEmpty) return;
    setState(() { _loading = true; _error = null; _result = null; });

    try {
      final base = _apiBase;
      final uri = _selectedModel == 'ensemble'
          ? Uri.parse('$base/predict_ensemble?weights=${Uri.encodeComponent(_weightsQuery())}&tta=$_tta&gamma=${_gamma.toStringAsFixed(3)}')
          : Uri.parse('$base/predict?model=$_selectedModel&tta=$_tta&gamma=${_gamma.toStringAsFixed(3)}');

      final request = http.MultipartRequest('POST', uri);
      if (kIsWeb) {
        final bytes = _webImageBytes ?? await _xfile!.readAsBytes();
        final mime = lookupMimeType('', headerBytes: bytes) ?? 'image/jpeg';
        final parts = mime.split('/');
        request.files.add(http.MultipartFile.fromBytes(
          'file', bytes, filename: _xfile!.name, contentType: MediaType(parts.first, parts.last),
        ));
      } else {
        final mime = lookupMimeType(_xfile!.path) ?? 'image/jpeg';
        final parts = mime.split('/');
        request.files.add(await http.MultipartFile.fromPath(
          'file', _xfile!.path,
          filename: p.basename(_xfile!.path),
          contentType: MediaType(parts.first, parts.last),
        ));
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        setState(() => _result = PredictResponse.fromJson(json.decode(resp.body)));
      } else {
        setState(() => _error = 'Server error: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      setState(() => _error = 'Request failed: $e');
    } finally {
      _checkReachability();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF2ecc71), Color(0xFF27ae60)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
      ),
      child: Row(
        children: [
          const Text('🐄', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Bovine Breed Classifier',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          GestureDetector(
            onTap: _openSettings,
            child: Chip(
              avatar: Icon(_apiReachable ? Icons.check_circle : Icons.wifi_off,
                  color: _apiReachable ? Colors.white : Colors.white70, size: 18),
              label: Text(_apiReachable ? 'Online' : 'Offline',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              backgroundColor: _apiReachable ? Colors.green.withOpacity(0.35) : Colors.black26,
              side: BorderSide(color: Colors.white.withOpacity(0.4)),
            ),
          ),
        ],
      ),
    );

    final imageWidget = (_xfile == null)
        ? Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200, style: BorderStyle.solid, width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: Text('No image selected')),
    )
        : ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: kIsWeb
          ? (_webImageBytes != null
          ? Image.memory(_webImageBytes!, height: 240, width: double.infinity, fit: BoxFit.cover)
          : Image.network(_xfile!.path, height: 240, width: double.infinity, fit: BoxFit.cover))
          : Image.file(File(_xfile!.path), height: 240, width: double.infinity, fit: BoxFit.cover),
    );

    return Scaffold(
      body: Column(
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.scatter_plot, size: 20),
                              const SizedBox(width: 8),
                              const Text('Model'),
                              const Spacer(),
                              DropdownButton<String>(
                                value: _selectedModel,
                                items: _modelOptions.entries
                                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedModel = v!),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          imageWidget,
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _pickImage(fromCamera: false),
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Gallery'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _pickImage(fromCamera: true),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Camera'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _xfile != null && !_loading ? _predict : null,
                                icon: _loading
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.insights),
                                label: const Text('Predict'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openSettings,
                                icon: const Icon(Icons.settings),
                                label: const Text('Settings'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('TTA'),
                              Switch(value: _tta, onChanged: (v) => setState(() => _tta = v)),
                              const SizedBox(width: 8),
                              const Text('Gamma'),
                              Expanded(
                                child: Slider(
                                  value: _gamma, min: 0.5, max: 4.0, divisions: 35,
                                  label: _gamma.toStringAsFixed(2),
                                  onChanged: (v) => setState(() => _gamma = v),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade400),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade700))),
                          ],
                        ),
                      ),
                    ),
                  if (_result != null) _PredictionCard(result: _result!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final PredictResponse result;
  const _PredictionCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline),
              const SizedBox(width: 6),
              Text("Prediction", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Chip(label: Text(result.model), avatar: const Icon(Icons.memory, size: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Text("${result.label}  (${(result.confidence * 100).toStringAsFixed(2)}%)",
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text("Top-5", style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...result.top5.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(e.key), Text("${(e.value * 100).toStringAsFixed(1)}%")],
            ),
          )),
        ]),
      ),
    );
  }
}
