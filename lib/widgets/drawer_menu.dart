import 'package:flutter/material.dart';
import '../router.dart';
import '../services/auth_service.dart';

class DrawerMenu extends StatelessWidget {
  const DrawerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(AuthService.displayName()),
            accountEmail: Text(AuthService.email ?? ''),
            currentAccountPicture: const CircleAvatar(child: Text('🐄')),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pushReplacementNamed(context, Routes.home),
          ),
          ListTile(
            leading: const Icon(Icons.biotech),
            title: const Text('Crossbreed suggester'),
            onTap: () => Navigator.pushReplacementNamed(context, Routes.crossbreed),
          ),
          ListTile(
            leading: const Icon(Icons.storefront),
            title: const Text('Marketplace'),
            onTap: () => Navigator.pushReplacementNamed(context, Routes.market),
          ),
          ListTile(
            leading: const Icon(Icons.local_drink),
            title: const Text('Dairy marketplace'),
            onTap: () => Navigator.pushReplacementNamed(context, Routes.dairyMarket),
          ),
          ListTile(
            leading: const Icon(Icons.vaccines),
            title: const Text('Vaccinations & care'),
            onTap: () => Navigator.pushReplacementNamed(context, Routes.vacc),
          ),
          ListTile(
            leading: const Icon(Icons.fact_check),
            title: const Text('Vaccination log'),
            onTap: () => Navigator.pushReplacementNamed(context, Routes.vaccLog),
          ),
          ListTile(
            leading: const Icon(Icons.local_hospital),
            title: const Text('Nearby veterinarians'),
            onTap: () => Navigator.pushReplacementNamed(context, Routes.vets),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => Navigator.pushNamed(context, Routes.settings),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              await AuthService.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}