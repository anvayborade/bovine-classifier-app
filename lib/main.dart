import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'router.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BovineApp());
}

class BovineApp extends StatelessWidget {
  const BovineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bovine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),               // <- use the vibrant theme
      initialRoute: AuthService.initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}