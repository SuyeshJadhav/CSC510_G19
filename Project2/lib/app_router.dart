import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Feature tabs
import 'screens/scan_screen.dart';
import 'screens/basket_screen.dart';
import 'screens/balances_screen.dart';

// Auth screens (note the subfolder)
import 'screens/login screens/login_screen.dart';
import 'screens/login screens/signup_page.dart';

final GoRouter router = GoRouter(
  initialLocation: '/login',
  routes: [
    // Auth routes
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupPage(),
    ),

    // Main shell with bottom nav (signed-in area)
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(
          path: '/scan',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ScanScreen()),
        ),
        GoRoute(
          path: '/basket',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BasketScreen()),
        ),
        GoRoute(
          path: '/benefits',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BalancesScreen()),
        ),
      ],
    ),
  ],

  // OPTION A: When logged out, allow only /login and /signup
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final path = state.uri.path;
    final isAuthRoute = path == '/login' || path == '/signup';

    if (user == null) {
      // Logged out → only allow auth routes
      return isAuthRoute ? null : '/login';
    }

    // Logged in → don't let them stay on auth routes
    if (isAuthRoute) return '/scan';

    return null;
  },
);

class _MainShell extends StatelessWidget {
  const _MainShell({required this.child});
  final Widget child;

  int _selectedIndexFor(String path) {
    if (path.startsWith('/scan')) return 0;
    if (path.startsWith('/basket')) return 1;
    if (path.startsWith('/benefits')) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/scan');
        break;
      case 1:
        context.go('/basket');
        break;
      case 2:
        context.go('/benefits');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final selected = _selectedIndexFor(path);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            label: 'Basket',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Benefits',
          ),
        ],
      ),
    );
  }
}
