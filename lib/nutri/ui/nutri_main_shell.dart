import 'package:flutter/material.dart';

import '../localization/nutri_i18n.dart';

import 'document_workspace_page.dart';
import 'library_workspace_page.dart';
import 'patient_workspace_page.dart';
import 'recipe_editor_page.dart';
import 'settings_workspace_page.dart';
import 'weekly_planner_page.dart';
import 'tester_access_gate.dart';

class NutriMainShell extends StatefulWidget {
  const NutriMainShell({super.key, this.onSignOut});

  final Future<void> Function()? onSignOut;

  @override
  State<NutriMainShell> createState() => _NutriMainShellState();
}

class _NutriMainShellState extends State<NutriMainShell> {
  int _index = 0;
  int _plannerRefreshToken = 0;
  int _patientRefreshToken = 0;
  int _documentRefreshToken = 0;
  int _dataEpoch = 0;
  int? _plannerPatientId;
  int? _plannerPlanId;
  int? _documentPatientId;
  int? _documentPlanId;

  void _planForPatient(int patientId) {
    _plannerPatientId = patientId;
    _plannerPlanId = null;
    _selectPage(0);
  }

  void _editDocumentPlan(int patientId, int planId) {
    _plannerPatientId = patientId;
    _plannerPlanId = planId;
    _selectPage(0);
  }

  void _reviewDocument(int patientId, int planId) {
    _documentPatientId = patientId;
    _documentPlanId = planId;
    _selectPage(3);
  }

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

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(NutriI18n.t('Biblioteca')),
              onTap: () {
                Navigator.pop(sheetContext);
                _selectPage(4);
              },
            ),
            ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Privacidad y condiciones'),
              onTap: () {
                Navigator.pop(sheetContext);
                showTesterPolicy(context);
              },
            ),
            if (widget.onSignOut != null)
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesión'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  widget.onSignOut!();
                },
              ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(NutriI18n.t('Configuración')),
              onTap: () {
                Navigator.pop(sheetContext);
                _selectPage(5);
              },
            ),
          ],
        ),
      ),
    );
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
                  trailing: widget.onSignOut == null
                      ? null
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Privacidad y condiciones',
                              icon: const Icon(Icons.policy_outlined),
                              onPressed: () => showTesterPolicy(context),
                            ),
                            IconButton(
                              tooltip: 'Cerrar sesión',
                              icon: const Icon(Icons.logout),
                              onPressed: () => widget.onSignOut!(),
                            ),
                          ],
                        ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.calendar_view_week_outlined),
                      selectedIcon: const Icon(Icons.calendar_view_week),
                      label: Text(NutriI18n.t('Planificador')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.people_outline),
                      selectedIcon: const Icon(Icons.people),
                      label: Text(NutriI18n.t('Pacientes')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.restaurant_menu_outlined),
                      selectedIcon: const Icon(Icons.restaurant_menu),
                      label: Text(NutriI18n.t('Recetas')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      selectedIcon: const Icon(Icons.picture_as_pdf),
                      label: Text(NutriI18n.t('Documentos')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.inventory_2_outlined),
                      selectedIcon: const Icon(Icons.inventory_2),
                      label: Text(NutriI18n.t('Biblioteca')),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: Text(NutriI18n.t('Configuración')),
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
                        preferredPatientId: _plannerPatientId,
                        preferredPlanId: _plannerPlanId,
                        onCreatePatient: () => _selectPage(1),
                        onReviewDocument: _reviewDocument,
                      ),
                      PatientWorkspacePage(
                        key: ValueKey('patients-$_dataEpoch'),
                        refreshToken: _patientRefreshToken,
                        onPlanForPatient: _planForPatient,
                      ),
                      RecipeEditorPage(key: ValueKey('recipes-$_dataEpoch')),
                      DocumentWorkspacePage(
                        key: ValueKey('documents-$_dataEpoch'),
                        refreshToken: _documentRefreshToken,
                        preferredPatientId: _documentPatientId,
                        preferredPlanId: _documentPlanId,
                        onEditPlan: _editDocumentPlan,
                      ),
                      LibraryWorkspacePage(
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
                preferredPatientId: _plannerPatientId,
                preferredPlanId: _plannerPlanId,
                onCreatePatient: () => _selectPage(1),
                onReviewDocument: _reviewDocument,
              ),
              PatientWorkspacePage(
                key: ValueKey('patients-$_dataEpoch'),
                refreshToken: _patientRefreshToken,
                onPlanForPatient: _planForPatient,
              ),
              RecipeEditorPage(key: ValueKey('recipes-$_dataEpoch')),
              DocumentWorkspacePage(
                key: ValueKey('documents-$_dataEpoch'),
                refreshToken: _documentRefreshToken,
                preferredPatientId: _documentPatientId,
                preferredPlanId: _documentPlanId,
                onEditPlan: _editDocumentPlan,
              ),
              LibraryWorkspacePage(key: ValueKey('library-$_dataEpoch')),
              SettingsWorkspacePage(
                onDataRestored: _handleDataRestored,
                onSettingsChanged: _handleSettingsChanged,
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index < 4 ? _index : 4,
            onDestinationSelected: (value) =>
                value == 4 ? _showMore(context) : _selectPage(value),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.calendar_view_week_outlined),
                selectedIcon: const Icon(Icons.calendar_view_week),
                label: NutriI18n.t('Planificador'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: NutriI18n.t('Pacientes'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.restaurant_menu_outlined),
                selectedIcon: const Icon(Icons.restaurant_menu),
                label: NutriI18n.t('Recetas'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                selectedIcon: const Icon(Icons.picture_as_pdf),
                label: NutriI18n.t('Documentos'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.more_horiz_outlined),
                selectedIcon: const Icon(Icons.more_horiz),
                label: NutriI18n.t('Más'),
              ),
            ],
          ),
        );
      },
    );
  }
}
