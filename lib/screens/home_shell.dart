import 'package:flutter/material.dart';

import 'catches_screen.dart';
import 'map_screen.dart';
import 'seasons_screen.dart';
import 'stats_screen.dart';
import 'weather_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    SeasonsScreen(),
    CatchesScreen(),
    MapScreen(),
    WeatherScreen(),
    StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.event_note_outlined),
            selectedIcon: Icon(Icons.event_note),
            label: 'Sezoane',
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
    );
  }
}
