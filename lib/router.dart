import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/crossbreed_screen.dart';
import 'screens/marketplace_screen.dart';
import 'screens/vaccinations_screen.dart';
import 'screens/vets_screen.dart';
import 'screens/settings_screen.dart';

// NEW screens:
import 'screens/vaccination_log_screen.dart';
import 'screens/dairy_marketplace_screen.dart';

import 'services/auth_service.dart';

class Routes {
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const crossbreed = '/crossbreed';
  static const market = '/market';
  static const vacc = '/vaccinations';
  static const vets = '/vets';
  static const settings = '/settings';

  // NEW:
  static const vaccLog = '/vaccination-log';
  static const dairyMarket = '/dairy-market';
}

class AppRouter {
  static Route onGenerateRoute(RouteSettings s) {
    final name = s.name ?? Routes.login;

    // If already logged in, never show login/register again
    if (AuthService.isLoggedIn &&
        (name == Routes.login || name == Routes.register)) {
      return MaterialPageRoute(builder: (_) => const DashboardScreen());
    }

    if (!AuthService.isLoggedIn &&
        name != Routes.login &&
        name != Routes.register) {
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    }

    switch (name) {
      case Routes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case Routes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case Routes.home:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case Routes.crossbreed:
        return MaterialPageRoute(builder: (_) => const CrossbreedScreen());
      case Routes.market:
        return MaterialPageRoute(builder: (_) => const MarketplaceScreen());
      case Routes.vacc:
        return MaterialPageRoute(builder: (_) => const VaccinationsScreen());
      case Routes.vets:
        return MaterialPageRoute(builder: (_) => const VetsScreen());
      case Routes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

    // NEW routes:
      case Routes.vaccLog:
        return MaterialPageRoute(builder: (_) => const VaccinationLogScreen());
      case Routes.dairyMarket:
        return MaterialPageRoute(builder: (_) => const DairyMarketplaceScreen());

      default:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
  }
}