import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import 'backup_screen.dart';

import 'catches_screen.dart';
import 'map_screen.dart';
import 'home_screen.dart';
import 'stats_screen.dart';
import 'weather_screen.dart';

/// Cât ocupă bannerul de jos (înălțime + margine) peste conținut: butoanele
/// și finalul listelor de pe ecranele principale se ridică cu atât.
const kBannerSpace = 84.0;

/// Ridică un buton plutitor deasupra bannerului de jos.
Widget aboveBanner(Widget fab) => Padding(
  padding: const EdgeInsets.only(bottom: kBannerSpace),
  child: fab,
);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // previzualizarea de pe calculator deschisă cu ?export=1 salvează singură
    // o copie de siguranță (descărcată direct în iCloud Drive)
    if (kIsWeb && Uri.base.queryParameters['export'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final name = await exportBackupFile(context.read<AppStore>());
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Copie salvată: $name')));
        }
      });
    }
  }

  static const _pages = [
    HomeScreen(),
    CatchesScreen(),
    MapScreen(),
    WeatherScreen(),
    StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final navColor =
        Theme.of(context).navigationBarTheme.backgroundColor ?? scheme.surface;
    return Scaffold(
      // conținutul trece pe sub bannerul de jos (80% opacitate)
      extendBody: true,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: NavigationBar(
              height: 68,
              backgroundColor: navColor.withValues(alpha: 0.8),
              elevation: 0,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Acasă',
                ),
                NavigationDestination(
                  icon: Icon(Icons.set_meal_outlined),
                  selectedIcon: Icon(Icons.set_meal),
                  label: 'Jurnal',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Hartă',
                ),
                NavigationDestination(
                  icon: Icon(Icons.cloud_outlined),
                  selectedIcon: Icon(Icons.cloud),
                  label: 'Vreme',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Statistici',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
