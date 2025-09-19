import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import '../widgets/appbars.dart';
import '../widgets/drawer_menu.dart';
import '../widgets/ui_kit.dart';

class CrossbreedScreen extends StatefulWidget {
  const CrossbreedScreen({super.key});
  @override State<CrossbreedScreen> createState()=>_CrossbreedScreenState();
}

class _CrossbreedScreenState extends State<CrossbreedScreen>{
  final _breed=TextEditingController(); String? _text; bool _busy=false; String? _err;

  Future<void> _go() async{
    if (_breed.text.trim().isEmpty) {
      setState(() => _err = 'Please enter a breed name first.');
      return;
    }
    setState((){_busy=true;_err=null;_text=null;});
    try{ _text = await ApiService.ai('/ai/crossbreed', breed:_breed.text.trim()); }
    catch(e){ _err='$e'; }
    finally{ if(mounted) setState(()=>_busy=false); }
  }

  @override void dispose(){_breed.dispose();super.dispose();}
  @override
  Widget build(BuildContext c){
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: topLevelAppBar('Crossbreed suggester', transparent: true),
      drawer: const DrawerMenu(),
      body: GradientWrap(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Hello, Farmer 👋'),
            const SizedBox(height: 10),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find compatible crossbreeds', style: Theme.of(c).textTheme.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 10),
                  TextField(controller:_breed, decoration: const InputDecoration(
                      labelText:'Breed (e.g., Gir)', prefixIcon: Icon(Icons.pets))),
                  const SizedBox(height: 12),
                  PillButton(icon: Icons.lightbulb, label: _busy ? 'Working…' : 'Suggest', onPressed:_busy?null:_go),
                  if(_err!=null) ...[
                    const SizedBox(height: 10),
                    Text(_err!, style: const TextStyle(color: Colors.white)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GlassCard(
                padding: const EdgeInsets.all(10),
                child: _text!=null
                    ? Markdown(data: _text!, padding: const EdgeInsets.all(8), styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(c)))
                    : const Center(child: Text('Results will appear here', style: TextStyle(color: Colors.white70))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}