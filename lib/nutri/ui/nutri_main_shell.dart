import 'package:flutter/material.dart';

import 'nutri_catalog_workspace_page.dart';
import 'weekly_planner_page.dart';

class NutriMainShell extends StatefulWidget {
  const NutriMainShell({super.key});

  @override
  State<NutriMainShell> createState() => _NutriMainShellState();
}

class _NutriMainShellState extends State<NutriMainShell> {
  int _index = 0;

  static const _pages = [
    WeeklyPlannerPage(),
    NutriCatalogWorkspacePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (value) {
                    setState(() => _index = value);
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 14, bottom: 18),
                    child: Column(
                      children: [
                        Icon(Icons.eco_outlined, size: 30),
                        SizedBox(height: 6),
                        Text(
                          'Nutrikuaa',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.calendar_view_week_outlined),
                      selectedIcon: Icon(Icons.calendar_view_week),
                      label: Text('Planificador'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: Text('Biblioteca'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: _pages,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: _pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) {
              setState(() => _index = value);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.calendar_view_week_outlined),
                selectedIcon: Icon(Icons.calendar_view_week),
                label: 'Planificador',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Biblioteca',
              ),
            ],
          ),
        );
      },
    );
  }
}
