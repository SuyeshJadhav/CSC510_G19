import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// Removed auth/provider imports as they are no longer needed here

// Import your screens
import 'screens/scan_screen.dart';
import 'screens/basket_screen.dart';
import 'screens/balances_screen.dart';
// Removed login/signup imports

// 1. Reverted back to a simple 'final' router.
// The 'AppRouter' class and 'refreshListenable' are no longer needed
// because we don't need to listen to login state changes.
final GoRouter router = GoRouter(
  // 2. Set initial location to the '/scan' tab
  initialLocation: '/scan',
  routes: [
    // 3. Removed the '/login' and '/signup' routes

    // Main shell with bottom navigation (Scan, Basket, Benefits)
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
        // TODO: Add your VisualizeScreen route here
      ],
    ),
  ],

  // 4. Removed the entire 'redirect' function.
  // We no longer need an "Auth Gate".
);

// THE REST OF THE FILE IS UNCHANGED
// This ShellRoute logic is perfect for a tabbed layout.
class _MainShell extends StatefulWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
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
          // TODO: Add your VisualizeScreen destination here
        ],
      ),
    );
  }
}
