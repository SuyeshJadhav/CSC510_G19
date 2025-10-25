// lib/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wolfbite/state/app_state.dart';

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
  // _selectedIndex will now map to the _screens list
  // 0 = BasketScreen
  // 1 = BalancesScreen
  int _selectedIndex = 0;

  // ScanScreen is removed from this list.
  // These are the persistent tabs.
  static const List<Widget> _screens = [BasketScreen() /*, BalancesScreen()*/];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        // The UI selectedIndex needs to map to our state.
        // Basket (index 1 in UI) maps to _selectedIndex 0
        // Benefits (index 2 in UI) maps to _selectedIndex 1
        // So, the UI index is _selectedIndex + 1
        selectedIndex: _selectedIndex + 1,

        onDestinationSelected: (index) {
          if (index == 0) {
            // SCAN button tapped (index 0)
            // We push the '/scan' route and wait for a result.
            context.push<String>('/scan').then((String? scannedCode) async {
              if (scannedCode != null) {
                // We got a code!
                final appState = Provider.of<AppState>(context, listen: false);

                // Call and AWAIT the new async addItem method.
                // The AppState's isLoading flag will be true during this.
                await appState.addItem(scannedCode);

                // After adding the item, switch to the Basket tab
                setState(() {
                  _selectedIndex = 0; // 0 is BasketScreen
                });
              }
            });
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
