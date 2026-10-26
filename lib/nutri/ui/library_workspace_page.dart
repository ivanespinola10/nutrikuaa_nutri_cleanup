import 'package:flutter/material.dart';

import 'nutri_catalog_workspace_page.dart';
import 'recipe_editor_page.dart';

class LibraryWorkspacePage extends StatelessWidget {
  const LibraryWorkspacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Biblioteca',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Alimentos'),
              Tab(icon: Icon(Icons.restaurant_menu_outlined), text: 'Recetas'),
            ],
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 18),
              child: Center(child: Text('PREVENTA · V0.6')),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            NutriCatalogWorkspacePage(embedded: true),
            RecipeEditorPage(embedded: true),
          ],
        ),
      ),
    );
  }
}
