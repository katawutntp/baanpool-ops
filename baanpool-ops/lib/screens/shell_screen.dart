import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shell screen with bottom navigation bar
class ShellScreen extends StatelessWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/properties')) return 1;
    if (location.startsWith('/work-orders')) return 2;
    if (location.startsWith('/expenses')) return 3;
    if (location.startsWith('/pm') || location.startsWith('/assets')) return 4;
    return 0; // dashboard
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/properties');
              break;
            case 2:
              context.go('/work-orders');
              break;
            case 3:
              context.go('/expenses');
              break;
            case 4:
              context.go('/pm');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'แดชบอร์ด',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'บ้าน',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'ใบงาน',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'ค่าใช้จ่าย',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'PM',
          ),
        ],
      ),
    );
  }
}
