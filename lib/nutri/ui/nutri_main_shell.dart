import 'package:flutter/material.dart';

import 'nutri_catalog_workspace_page.dart';
import 'patient_workspace_page.dart';
import 'recipe_editor_page.dart';
import 'weekly_planner_page.dart';

class NutriMainShell extends StatefulWidget {
  const NutriMainShell({super.key});

  @override
  State<NutriMainShell> createState() => _NutriMainShellState();
}

class _NutriMainShellState extends State<NutriMainShell> {
  int _index = 0;
  int _plannerRefreshToken = 0;

  void _selectPage(int value) {
    setState(() {
      _index = value;
      if (value == 0) {
        _plannerRefreshToken++;
      }
    });
  }

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
                  onDestinationSelected: _selectPage,
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
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text('Pacientes'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.restaurant_menu_outlined),
                      selectedIcon: Icon(Icons.restaurant_menu),
                      label: Text('Recetas'),
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
                    children: [
                      WeeklyPlannerPage(
                        refreshToken: _plannerRefreshToken,
                      ),
                      const PatientWorkspacePage(),
                      const RecipeEditorPage(),
                      const NutriCatalogWorkspacePage(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              WeeklyPlannerPage(
                refreshToken: _plannerRefreshToken,
              ),
              const PatientWorkspacePage(),
              const RecipeEditorPage(),
              const NutriCatalogWorkspacePage(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _selectPage,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.calendar_view_week_outlined),
                selectedIcon: Icon(Icons.calendar_view_week),
                label: 'Planificador',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Pacientes',
              ),
              NavigationDestination(
                icon: Icon(Icons.restaurant_menu_outlined),
                selectedIcon: Icon(Icons.restaurant_menu),
                label: 'Recetas',
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
