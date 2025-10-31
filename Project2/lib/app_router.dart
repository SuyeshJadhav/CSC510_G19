// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wolfbite/screens/balances_screen.dart';

// Import your screens
import 'screens/scan_screen.dart' show ScanScreen;
import 'screens/basket_screen.dart' show BasketScreen;
// import 'screens/balances_screen.dart' show BalancesScreen;

final GoRouter router = GoRouter(
  initialLocation: '/',
  routes: [
    // The main shell route with the navigation bar
    GoRoute(path: '/', builder: (context, state) => const _MainShell()),
    // A separate route for the ScanScreen that we can push
    GoRoute(path: '/scan', builder: (context, state) => const ScanScreen()),
  ],
);

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _selectedIndex = 0; // 0 = Basket, 1 = Balances

  static const List<Widget> _screens = [BasketScreen(), BalancesScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        // The UI index is _selectedIndex + 1 because "Scan" is at index 0
        selectedIndex: _selectedIndex + 1,
        onDestinationSelected: (index) {
          if (index == 0) {
            // --- THIS IS THE CHANGE ---
            // SCAN button tapped (index 0)
            // We just push the '/scan' route.
            // The ScanScreen itself now handles all logic.
            // We don't need to 'await' or '.then()' anything here.
            context.push('/scan');
          } else {
            // Basket (index 1) or Benefits (index 2) tapped
            setState(() {
              // We subtract 1 to map to our _screens list index
              _selectedIndex = index - 1;
            });
          }
        },
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
