import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_state_service.dart';
import '../services/notification_service.dart';

/// Shell screen with bottom navigation bar — role-aware
class ShellScreen extends StatefulWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  final _authState = AuthStateService();
  final _notiService = NotificationService();

  @override
  void initState() {
    super.initState();
    _authState.addListener(_onAuthChanged);
    _notiService.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authState.removeListener(_onAuthChanged);
    _notiService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  /// Build navigation destinations based on user role
  List<_NavItem> _getNavItems() {
    final isAdmin = _authState.isAdmin;

    final items = <_NavItem>[];

    if (isAdmin) {
      items.add(
        _NavItem(
          path: '/',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'แดชบอร์ด',
        ),
      );
    }

    // Work orders — visible to everyone
    items.add(
      _NavItem(
        path: '/work-orders',
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment,
        label: 'ใบงาน',
      ),
    );

    if (isAdmin) {
      items.add(
        _NavItem(
          path: '/properties',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'บ้าน',
        ),
      );

      items.add(
        _NavItem(
          path: '/expenses',
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'ค่าใช้จ่าย',
        ),
      );

      items.add(
        _NavItem(
          path: '/pm',
          icon: Icons.schedule_outlined,
          selectedIcon: Icons.schedule,
          label: 'PM',
        ),
      );
    }

    // Admin users get a roles tab
    if (isAdmin) {
      items.add(
        _NavItem(
          path: '/admin/roles',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          label: 'จัดการ Roles',
        ),
      );
    }

    return items;
  }

  int _currentIndex(BuildContext context, List<_NavItem> items) {
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < items.length; i++) {
      if (items[i].path == '/' && location == '/') return i;
      if (items[i].path != '/' && location.startsWith(items[i].path)) return i;
    }
    return 0;
  }

  Widget _buildNotificationBell(BuildContext context) {
    final unread = _notiService.unreadCount;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FloatingActionButton.small(
        heroTag: 'notiBell',
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 2,
        onPressed: () => context.push('/notifications'),
        child: Badge(
          isLabelVisible: unread > 0,
          label: Text(
            unread > 99 ? '99+' : '$unread',
            style: const TextStyle(fontSize: 10),
          ),
          child: Icon(
            unread > 0
                ? Icons.notifications_active
                : Icons.notifications_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navItems = _getNavItems();
    final currentIdx = _currentIndex(context, navItems);

    return Scaffold(
      body: widget.child,
      appBar: null,
      floatingActionButton: _buildNotificationBell(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIdx.clamp(0, navItems.length - 1),
        onDestinationSelected: (index) {
          context.go(navItems[index].path);
        },
        destinations: navItems
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavItem({
    required this.path,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}
