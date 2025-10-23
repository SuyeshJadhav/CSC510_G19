import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/scan_screen.dart';
import 'screens/basket_screen.dart';
import 'screens/balances_screen.dart';
import 'screens/visualizer_screen.dart';

final GoRouter router = GoRouter(
  routes: [
    ShellRoute(
      builder: (context, state, child) => _Shell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const ScanScreen()),
        GoRoute(path: '/basket', builder: (_, __) => const BasketScreen()),
        GoRoute(path: '/balances', builder: (_, __) => const BalancesScreen()),
        GoRoute(path: '/viz', builder: (_, __) => const VisualizerScreen()),
      ],
    ),
  ],
);

class _Shell extends StatefulWidget {
  const _Shell({required this.child});
  final Widget child;
  @override State<_Shell> createState() => _ShellState();
}
class _ShellState extends State<_Shell> {
  int idx = 0;
  final tabs = ['/', '/basket', '/balances', '/viz'];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) { setState(()=>idx=i); GoRouter.of(context).go(tabs[i]); },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.shopping_basket_outlined), label: 'Basket'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Benefits'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Viz'),
        ],
      ),
    );
  }
}
