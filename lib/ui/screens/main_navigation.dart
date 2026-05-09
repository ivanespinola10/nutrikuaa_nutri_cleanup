import 'package:flutter/material.dart';
import 'insumos_screen.dart';
import 'proyectos_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const InsumosScreen(),
    const ProyectosScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2),
            label: "Biblioteca",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: "Proyectos",
          ),
        ],
      ),
    );
  }
}
