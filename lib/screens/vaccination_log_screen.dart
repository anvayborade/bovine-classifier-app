import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/appbars.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/ui_kit.dart';

class VaccinationLogScreen extends StatefulWidget {
  const VaccinationLogScreen({super.key});
  @override
  State<VaccinationLogScreen> createState() => _VaccinationLogScreenState();
}

class _VaccinationLogScreenState extends State<VaccinationLogScreen> {
  final _ctrl = TextEditingController();
  List<_VaxItem> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('vaccination_log') ?? '[]';
    final list = (jsonDecode(raw) as List).cast<Map>();
    setState(() {
      _items = list.map((m) => _VaxItem(m['name'] as String, m['done'] as bool)).toList();
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final sp = await SharedPreferences.getInstance();
    final raw = jsonEncode(_items.map((e) => {'name': e.name, 'done': e.done}).toList());
    await sp.setString('vaccination_log', raw);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _add() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _items.add(_VaxItem(name, false));
      _ctrl.clear();
    });
    await _save();
  }

  Future<void> _toggle(int i, bool v) async {
    setState(() => _items[i] = _items[i].copyWith(done: v));
    await _save();
  }

  Future<void> _remove(int i) async {
    setState(() => _items.removeAt(i));
    await _save();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: topLevelAppBar('Vaccination log', transparent: true),
      drawer: const DrawerMenu(),
      body: GradientWrap(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Track shots & boosters'),
            const SizedBox(height: 10),

            // Add bar
            GlassCard(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                        labelText: 'Vaccine name',
                        prefixIcon: Icon(Icons.vaccines),
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PillButton(icon: Icons.add, label: 'Add +', onPressed: _add),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // List
            Expanded(
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (_saving) const LinearProgressIndicator(),
                    Expanded(
                      child: _items.isEmpty
                          ? const Center(child: Text('No vaccines added yet.'))
                          : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final it = _items[i];
                          return Dismissible(
                            key: ValueKey(it.name + i.toString()),
                            background: Container(color: Colors.red.shade100),
                            onDismissed: (_) => _remove(i),
                            child: CheckboxListTile(
                              value: it.done,
                              onChanged: (v) => _toggle(i, v ?? false),
                              title: Text(it.name),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaxItem {
  final String name;
  final bool done;
  _VaxItem(this.name, this.done);
  _VaxItem copyWith({String? name, bool? done}) =>
      _VaxItem(name ?? this.name, done ?? this.done);
}