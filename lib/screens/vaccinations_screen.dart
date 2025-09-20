import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../widgets/appbars.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/ui_kit.dart';

class VaccinationsScreen extends StatefulWidget {
  const VaccinationsScreen({super.key});
  @override
  State<VaccinationsScreen> createState() => _VaccinationsScreenState();
}

class _VaccinationsScreenState extends State<VaccinationsScreen> {
  final _breed = TextEditingController();
  String? _ai;
  bool _busy = false;
  String? _err;

  Future<void> _go() async {
    final q = _breed.text.trim();
    if (q.isEmpty) {
      setState(() => _err = 'Please enter a breed name first.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _busy = true; _err = null; _ai = null; });
    try {
      _ai = await ApiService.ai('/ai/vaccinations', breed: q);
    } catch (e) {
      _err = '$e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() { _breed.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: topLevelAppBar('Vaccinations & care', transparent: true),
      drawer: const DrawerMenu(),
      body: GradientWrap(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Keep your herd protected'),
              const SizedBox(height: 10),

              // ---- AI suggestions card ----
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Get vaccination & care suggestions',
                        style: Theme.of(c).textTheme.titleMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _breed,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _go(),
                      decoration: const InputDecoration(
                        labelText: 'Breed',
                        prefixIcon: Icon(Icons.vaccines),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        PillButton(
                          icon: Icons.health_and_safety,
                          label: _busy ? 'Working…' : 'Get suggestions',
                          onPressed: _busy ? null : _go,
                        ),
                        const SizedBox(width: 10),
                        if (_busy)
                          const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    if (_err != null) ...[
                      const SizedBox(height: 8),
                      Text(_err!, style: const TextStyle(color: Colors.white)),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      height: 240,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _busy
                          ? const Center(child: CircularProgressIndicator())
                          : (_ai == null
                          ? const Center(child: Text(
                          'Suggestions will appear here',
                          style: TextStyle(color: Colors.black54)))
                          : Markdown(data: _ai!)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ---- Vaccination log (Firestore) ----
              Expanded(
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        child: Row(
                          children: [
                            Text('Your vaccination log',
                                style: Theme.of(c).textTheme.titleMedium),
                            const Spacer(),
                            const Icon(Icons.check_circle, color: Colors.teal),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // Stream list
                      Expanded(
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: DbService.vaccStream(),
                          builder: (c, s) {
                            if (s.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (s.hasError) {
                              return Center(child: Text('Error: ${s.error}'));
                            }
                            final docs = s.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('No vaccinations tracked yet.'),
                                ),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: docs.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final d = docs[i];
                                final name = d.data()['name'] as String? ?? '-';
                                final given = (d.data()['given'] ?? false) as bool;
                                return CheckboxListTile(
                                  value: given,
                                  onChanged: (v) => DbService.setVaccination(name, v ?? false),
                                  title: Text(name),
                                  controlAffinity: ListTileControlAffinity.leading,
                                );
                              },
                            );
                          },
                        ),
                      ),

                      // Add row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                        child: Row(
                          children: const [
                            Expanded(child: _AddVaccineInlineField()),
                            SizedBox(width: 8),
                            Text('Tap to toggle ✓'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// submit-to-add using DbService.setVaccination(name,false)
class _AddVaccineInlineField extends StatefulWidget {
  const _AddVaccineInlineField();
  @override
  State<_AddVaccineInlineField> createState() => _AddVaccineInlineFieldState();
}

class _AddVaccineInlineFieldState extends State<_AddVaccineInlineField> {
  final _tf = TextEditingController();
  @override void dispose() { _tf.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _tf,
      decoration: const InputDecoration(
        hintText: 'Add vaccine name',
        prefixIcon: Icon(Icons.add),
      ),
      onSubmitted: (v) {
        if (v.trim().isNotEmpty) DbService.setVaccination(v.trim(), false);
        _tf.clear();
      },
    );
  }
}