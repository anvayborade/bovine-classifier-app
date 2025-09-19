import 'package:flutter/material.dart';
import '../../router.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState()=>_RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>{
  final _name=TextEditingController();
  final _email=TextEditingController();
  final _pass=TextEditingController();
  bool _busy=false; String? _err;

  @override void dispose(){_name.dispose();_email.dispose();_pass.dispose();super.dispose();}

  Future<void> _register() async{
    setState((){_busy=true;_err=null;});
    try{
      await AuthService.signUp(_email.text.trim(), _pass.text, _name.text.trim());
      await DbService.ensureUserDoc();
      if(mounted) {
        Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
      }
    }catch(e){setState(()=>_err='$e');} finally{if(mounted) setState(()=>_busy=false);}
  }

  @override
  Widget build(BuildContext c)=>WillPopScope(
    onWillPop: () async => false,
    child: Scaffold(
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children:[
          Text('Bovine – Register', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height:12),
          TextField(controller:_name, decoration: const InputDecoration(prefixIcon:Icon(Icons.person), labelText:'Name')),
          const SizedBox(height:8),
          TextField(controller:_email, decoration: const InputDecoration(prefixIcon:Icon(Icons.email), labelText:'Email')),
          const SizedBox(height:8),
          TextField(controller:_pass, decoration: const InputDecoration(prefixIcon:Icon(Icons.lock), labelText:'Password'), obscureText:true),
          const SizedBox(height:12),
          if(_err!=null) Text(_err!, style: const TextStyle(color:Colors.red)),
          const SizedBox(height:8),
          FilledButton(onPressed:_busy?null:_register, child:_busy?const CircularProgressIndicator():const Text('Create account')),
          TextButton(onPressed:()=>Navigator.pushReplacementNamed(c, Routes.login), child: const Text('Back to login'))
        ]))),
      )),
    ),
  );
}
