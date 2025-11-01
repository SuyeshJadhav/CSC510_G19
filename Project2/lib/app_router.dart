import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';

// Import your screens
import 'screens/scan_screen.dart';
import 'screens/basket_screen.dart';
import 'screens/balances_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/login', // Start with login
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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

  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final String path = state.uri.path; // <- use this

    // Not logged in, force to login
    if (user == null && path != '/login') return '/login';

    // Logged in and on login page, go to scan
    if (user != null && path == '/login') return '/scan';

    return null; // no redirect
  },
);

class _MainShell extends StatefulWidget {
  final Widget child;
  const _MainShell({required this.child});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _calculateSelectedIndex(BuildContext context) {
    // use uri.toString() from GoRouterState to get current path
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/scan')) return 0;
    if (location.startsWith('/basket')) return 1;
    if (location.startsWith('/benefits')) return 2;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
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
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _onItemTapped(context, index),
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
