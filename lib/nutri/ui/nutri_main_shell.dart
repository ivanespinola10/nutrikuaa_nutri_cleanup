import 'package:flutter/material.dart';

import 'document_workspace_page.dart';
import 'nutri_catalog_workspace_page.dart';
import 'patient_workspace_page.dart';
import 'recipe_editor_page.dart';
import 'settings_workspace_page.dart';
import 'weekly_planner_page.dart';

class NutriMainShell extends StatefulWidget {
  const NutriMainShell({super.key});

  @override
  State<NutriMainShell> createState() => _NutriMainShellState();
}

class _NutriMainShellState extends State<NutriMainShell> {
  int _index = 0;
  int _plannerRefreshToken = 0;
  int _patientRefreshToken = 0;
  int _documentRefreshToken = 0;
  int _dataEpoch = 0;

  void _selectPage(int value) {
    setState(() {
      _index = value;
      if (value == 0) {
        _plannerRefreshToken++;
      }
      if (value == 1) {
        _patientRefreshToken++;
      }
      if (value == 3) {
        _documentRefreshToken++;
      }
    });
  }

  void _handleDataRestored() {
    setState(() {
      _dataEpoch++;
      _plannerRefreshToken++;
      _patientRefreshToken++;
      _documentRefreshToken++;
    });
  }

  void _handleSettingsChanged() {
    setState(() {
      _dataEpoch++;
      _documentRefreshToken++;
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
                      icon: Icon(Icons.picture_as_pdf_outlined),
                      selectedIcon: Icon(Icons.picture_as_pdf),
                      label: Text('Documentos'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: Text('Biblioteca'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Configuración'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: [
                      WeeklyPlannerPage(
                        key: ValueKey('planner-$_dataEpoch'),
                        refreshToken: _plannerRefreshToken,
                      ),
                      PatientWorkspacePage(
                        key: ValueKey('patients-$_dataEpoch'),
                        refreshToken: _patientRefreshToken,
                      ),
                      RecipeEditorPage(
                        key: ValueKey('recipes-$_dataEpoch'),
                      ),
                      DocumentWorkspacePage(
                        key: ValueKey('documents-$_dataEpoch'),
                        refreshToken: _documentRefreshToken,
                      ),
                      NutriCatalogWorkspacePage(
                        key: ValueKey('library-$_dataEpoch'),
                      ),
                      SettingsWorkspacePage(
                        onDataRestored: _handleDataRestored,
                        onSettingsChanged: _handleSettingsChanged,
                      ),
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
                key: ValueKey('planner-$_dataEpoch'),
                refreshToken: _plannerRefreshToken,
              ),
              PatientWorkspacePage(
                key: ValueKey('patients-$_dataEpoch'),
                refreshToken: _patientRefreshToken,
              ),
              RecipeEditorPage(
                key: ValueKey('recipes-$_dataEpoch'),
              ),
              DocumentWorkspacePage(
                key: ValueKey('documents-$_dataEpoch'),
                refreshToken: _documentRefreshToken,
              ),
              NutriCatalogWorkspacePage(
                key: ValueKey('library-$_dataEpoch'),
              ),
              SettingsWorkspacePage(
                onDataRestored: _handleDataRestored,
                onSettingsChanged: _handleSettingsChanged,
              ),
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
                icon: Icon(Icons.picture_as_pdf_outlined),
                selectedIcon: Icon(Icons.picture_as_pdf),
                label: 'Documentos',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Biblioteca',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Configuración',
              ),
            ],
          ),
        );
      },
    );
  }
}
