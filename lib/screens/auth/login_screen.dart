import 'package:flutter/material.dart';
import '../../router.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>{
  final _email=TextEditingController();
  final _pass=TextEditingController();
  bool _busy=false; String? _err;

  @override void dispose(){_email.dispose();_pass.dispose();super.dispose();}

  Future<void> _login() async{
    setState((){_busy=true;_err=null;});
    try{
      await AuthService.signIn(_email.text.trim(), _pass.text);
      await DbService.ensureUserDoc();
      if(mounted) {
        Navigator.pushNamedAndRemoveUntil(context, Routes.home, (_) => false);
      }
    }catch(e){setState(()=>_err='$e');} finally{if(mounted) setState(()=>_busy=false);}
  }

  @override
  Widget build(BuildContext c)=>WillPopScope(
    onWillPop: () async => false, // disable back from login
    child: Scaffold(
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children:[
            Text('Bovine – Sign in', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height:12),
            TextField(controller:_email, decoration: const InputDecoration(prefixIcon:Icon(Icons.email), labelText:'Email')),
            const SizedBox(height:8),
            TextField(controller:_pass, decoration: const InputDecoration(prefixIcon:Icon(Icons.lock), labelText:'Password'), obscureText:true),
            const SizedBox(height:12),
            if(_err!=null) Text(_err!, style: const TextStyle(color:Colors.red)),
            const SizedBox(height:8),
            FilledButton(onPressed:_busy?null:_login, child:_busy?const CircularProgressIndicator():const Text('Sign in')),
            TextButton(onPressed:()=>Navigator.pushReplacementNamed(c, Routes.register), child: const Text('Create account'))
          ])),
        ),
      )),
    ),
  );
}
