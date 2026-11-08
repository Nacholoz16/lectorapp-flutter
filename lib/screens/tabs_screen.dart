import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'library_screen.dart';

/// Contenedor principal: Inicio · Biblioteca · Perfil en un IndexedStack (conservan scroll
/// y datos). La búsqueda vive en Inicio, como barra (ver `openSearch`).
class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});

  static const int home = 0;
  static const int library = 1;
  static const int profile = 2;

  /// Cambia de pestaña desde cualquier pantalla hija (p. ej. el avatar de Inicio → Perfil).
  /// No hace nada si no hay un TabsScreen arriba.
  static void select(BuildContext context, int index) =>
      context.findAncestorStateOfType<_TabsScreenState>()?._select(index);

  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  int _currentIndex = TabsScreen.home;

  final List<Widget> _screens = const [
    HomeScreen(),
    LibraryScreen(),
    ProfileScreen(),
  ];

  void _select(int index) {
    if (index != _currentIndex) setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _select,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.collections_bookmark_outlined),
            activeIcon: Icon(Icons.collections_bookmark_rounded),
            label: 'Biblioteca',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
