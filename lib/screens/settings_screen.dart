import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget { const SettingsScreen({super.key}); @override State<SettingsScreen> createState()=>_SettingsScreenState();}
class _SettingsScreenState extends State<SettingsScreen>{
  final _url = TextEditingController(); bool _tta=true; double _gamma=2.0; bool _saved=false;

  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async{
    _url.text = await ApiService.baseUrl();
    final t = await ApiService.loadInference();
    setState((){ _tta = t.$1; _gamma = t.$2; });
  }
  Future<void> _save() async{
    await ApiService.saveBaseUrl(_url.text.trim());
    await ApiService.saveInference(tta:_tta, gamma:_gamma);
    setState(()=>_saved=true);
    await Future.delayed(const Duration(seconds: 1));
    if(mounted) setState(()=>_saved=false);
  }

  @override void dispose(){ _url.dispose(); super.dispose();}
  @override Widget build(BuildContext c)=>Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller:_url, decoration: const InputDecoration(prefixIcon: Icon(Icons.link), labelText:'Server URL (http/https)')),
      const SizedBox(height: 12),
      SwitchListTile(value:_tta, onChanged:(v)=>setState(()=>_tta=v), title: const Text('TTA (flip)')),
      Row(children:[
        const Text('Gamma boost'),
        Expanded(child: Slider(value:_gamma, min:0.5, max:4.0, divisions:35, label:_gamma.toStringAsFixed(2), onChanged:(v)=>setState(()=>_gamma=v))),
        Text(_gamma.toStringAsFixed(2)),
      ]),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed:_save, icon: const Icon(Icons.save), label: const Text('Save')),
      if(_saved) const Padding(padding: EdgeInsets.only(top:8), child: Text('Saved ✓', style: TextStyle(color: Colors.green))),
      const SizedBox(height: 12),
      const Text('Tip: For different networks, use a public URL (Cloudflare Tunnel) and paste it here.'),
    ]),
  );
}