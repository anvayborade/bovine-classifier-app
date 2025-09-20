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
  final _breed = TextEditingController();
  String? _text;
  bool _busy = false;
  String? _err;

  Future<void> _go() async{
    final q = _breed.text.trim();
    if (q.isEmpty) {
      setState(() => _err = 'Please enter a breed name first.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState((){ _busy=true; _err=null; _text=null; });
    try{
      _text = await ApiService.ai('/ai/crossbreed', breed:q);
    }catch(e){ _err='$e';
    }finally{ if(mounted) setState(()=>_busy=false); }
  }

  @override void dispose(){ _breed.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext c){
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: topLevelAppBar('Crossbreed suggester', transparent: true),
      drawer: const DrawerMenu(),
      body: GradientWrap(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Hello, Farmer 👋'),
              const SizedBox(height: 10),

              // Input + action
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Find compatible crossbreeds',
                        style: Theme.of(c).textTheme.titleMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 10),
                    TextField(
                      controller:_breed,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _go(),
                      decoration: const InputDecoration(
                        labelText:'Breed (e.g., Gir)',
                        prefixIcon: Icon(Icons.pets),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        PillButton(
                          icon: Icons.lightbulb,
                          label: _busy ? 'Working…' : 'Suggest',
                          onPressed:_busy?null:_go,
                        ),
                        const SizedBox(width: 10),
                        if (_busy)
                          const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    if(_err!=null) ...[
                      const SizedBox(height: 10),
                      Text(_err!, style: const TextStyle(color: Colors.white)),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Results
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(10),
                  child: _busy
                      ? const Center(child: CircularProgressIndicator())
                      : (_text!=null
                      ? Markdown(
                      data: _text!,
                      padding: const EdgeInsets.all(8),
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(c)))
                      : const Center(
                      child: Text('Results will appear here',
                          style: TextStyle(color: Colors.white70)))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}