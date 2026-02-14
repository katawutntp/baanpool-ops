import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/auth_callback_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/properties/properties_list_screen.dart';
import '../screens/properties/property_detail_screen.dart';
import '../screens/assets/assets_list_screen.dart';
import '../screens/assets/asset_detail_screen.dart';
import '../screens/work_orders/work_orders_list_screen.dart';
import '../screens/work_orders/work_order_detail_screen.dart';
import '../screens/work_orders/work_order_form_screen.dart';
import '../screens/expenses/expenses_list_screen.dart';
import '../screens/expenses/expense_form_screen.dart';
import '../screens/pm/pm_schedule_screen.dart';
import '../screens/shell_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final isAuthRoute =
        state.uri.toString().startsWith('/login') ||
        state.uri.toString().startsWith('/auth');

    // Not logged in → go to login
    if (!isLoggedIn && !isAuthRoute) return '/login';
    // Logged in but on login page → go to dashboard
    if (isLoggedIn && isAuthRoute) return '/';
    return null;
  },
  routes: [
    // Auth
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/auth/callback',
      builder: (context, state) => const AuthCallbackScreen(),
    ),

    // Main shell with bottom navigation
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        // Dashboard
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),

        // Properties
        GoRoute(
          path: '/properties',
          builder: (context, state) => const PropertiesListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  PropertyDetailScreen(propertyId: state.pathParameters['id']!),
            ),
          ],
        ),

        // Assets
        GoRoute(
          path: '/assets',
          builder: (context, state) => const AssetsListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  AssetDetailScreen(assetId: state.pathParameters['id']!),
            ),
          ],
        ),

        // Work Orders
        GoRoute(
          path: '/work-orders',
          builder: (context, state) => const WorkOrdersListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const WorkOrderFormScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) => WorkOrderDetailScreen(
                workOrderId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),

        // Expenses
        GoRoute(
          path: '/expenses',
          builder: (context, state) => const ExpensesListScreen(),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => const ExpenseFormScreen(),
            ),
          ],
        ),

        // PM Schedules
        GoRoute(
          path: '/pm',
          builder: (context, state) => const PmScheduleScreen(),
        ),
      ],
    ),
  ],
);
