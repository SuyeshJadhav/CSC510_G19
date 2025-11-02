import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wolfbite/screens/login_screen.dart';
import 'package:wolfbite/screens/signup_page.dart';

import 'screens/scan_screen.dart';
import 'screens/basket_screen.dart';
import 'screens/balances_screen.dart';

/// Listenable wrapper for Firebase auth state changes.
///
/// This class converts [FirebaseAuth.authStateChanges] stream into a
/// [ChangeNotifier] that [GoRouter] can listen to for automatic route
/// refresh when authentication state changes.
///
/// When [FirebaseAuth] emits a new user state (login/logout), this
/// notifies [GoRouter] to re-run the [redirect] callback.
class GoRouterRefreshStream extends ChangeNotifier {
  /// Creates a refresh notifier for [FirebaseAuth] state changes.
  ///
  /// Listens to [stream] and calls [notifyListeners] whenever a new
  /// event is emitted (user logs in or out).
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Main application router using [GoRouter] for navigation.
///
/// Defines the app's complete route structure with auth guards:
/// - `/login` and `/signup`: Authentication screens (unauthenticated only)
/// - `/scan`, `/basket`, `/benefits`: Main app screens (authenticated only)
///
/// The [redirect] callback enforces authentication rules:
/// - Logged-out users can only access auth routes
/// - Logged-in users are redirected from auth routes to `/scan`
///
/// Main screens are wrapped in [_MainShell] which provides the bottom
/// navigation bar for seamless tab switching between [ScanScreen],
/// [BasketScreen], and [BalancesScreen].
///
/// Usage: Configure in [MaterialApp.router] via `routerConfig: router`
final GoRouter router = GoRouter(
  /// Initial route shown when the app starts.
  ///
  /// Set to `/login` to show authentication screen first. The [redirect]
  /// callback will immediately redirect authenticated users to `/scan`.
  initialLocation: '/login',

  routes: [
    // ---------- Auth routes (unauthenticated only) ----------

    /// Login screen for existing users.
    ///
    /// Route: `/login`
    /// Access: Unauthenticated users only
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

    /// Registration screen for new users.
    ///
    /// Route: `/signup`
    /// Access: Unauthenticated users only
    GoRoute(path: '/signup', builder: (context, state) => const SignupPage()),

    // ---------- Main app shell with bottom navigation ----------

    /// Shell route that wraps all authenticated screens.
    ///
    /// Provides a persistent [NavigationBar] at the bottom for tab switching.
    /// All nested routes share this shell without re-rendering the nav bar.
    ///
    /// Access: Authenticated users only (via [redirect])
    ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        /// Barcode scanning and product lookup screen.
        ///
        /// Route: `/scan`
        /// Purpose: Main entry point for adding products to basket
        /// Features:
        /// - Live barcode scanning
        /// - Product eligibility checking
        /// - WIC category limit enforcement
        /// - Substitute product suggestions
        GoRoute(
          path: '/scan',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ScanScreen()),
        ),

        /// Shopping basket management screen.
        ///
        /// Route: `/basket`
        /// Purpose: View and modify items in the shopping basket
        /// Features:
        /// - Item quantity adjustment
        /// - Category usage display
        /// - Quick access to basket summary
        GoRoute(
          path: '/basket',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BasketScreen()),
        ),

        /// WIC benefit balance display screen.
        ///
        /// Route: `/benefits`
        /// Purpose: View current WIC category balances and limits
        /// Features:
        /// - Category-by-category balance view
        /// - Usage progress bars
        /// - Account management (sign out)
        GoRoute(
          path: '/balances',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: BalancesScreen()),
        ),
      ],
    ),
  ],

  /// Guards routes based on [FirebaseAuth] state and prevents unauthorized access.
  ///
  /// This callback runs before every route transition and determines if the
  /// user is allowed to navigate to the requested route.
  ///
  /// **IMPORTANT:** This uses [FirebaseAuth.instance.currentUser] which may be
  /// null immediately after sign-in while Firebase completes internal state
  /// updates. The [StreamProvider<User?>] in [main.dart] provides more reliable
  /// real-time updates. This redirect is primarily for initial app startup.
  ///
  /// Rules:
  /// 1. **Logged-out users** (no [FirebaseAuth.currentUser]):
  ///    - Can only access `/login` and `/signup`
  ///    - Are redirected to `/login` if they try protected routes
  ///
  /// 2. **Logged-in users** (has [FirebaseAuth.currentUser]):
  ///    - Cannot access `/login` or `/signup`
  ///    - Are redirected to `/scan` if they try auth routes
  ///
  /// Returns:
  /// - `null`: Navigation is allowed (user can access route)
  /// - `/login`: User is redirected to login screen
  /// - `/scan`: User is redirected to main screen
  /// - Other paths: User is redirected to that path
  ///
  /// Side effects:
  /// - Called on every route change
  /// - Does NOT require [BuildContext], just accesses [FirebaseAuth]
  /// - Safe to call multiple times
  redirect: (context, state) {
    /// Get current user from [FirebaseAuth].
    ///
    /// null = logged out
    /// non-null = logged in with email/UID available
    final user = FirebaseAuth.instance.currentUser;

    /// Extract requested route path.
    ///
    /// Example: state.uri.path returns '/login', '/scan', etc.
    final path = state.uri.path;

    /// Check if the requested route is an authentication route.
    ///
    /// Auth routes are routes that should only be accessed by logged-out users.
    final isAuthRoute = path == '/login' || path == '/signup';

    // Logged out → restrict to auth routes only
    if (user == null) {
      /// If trying to access auth route (login/signup), allow it.
      /// Otherwise, redirect to login.
      return isAuthRoute ? null : '/login';
    }

    // Logged in → prevent auth routes, redirect to main screen
    if (isAuthRoute) return '/scan';

    /// User is authenticated and trying to access a valid route.
    /// Allow navigation.
    return null;
  },

  /// Refreshes the route state when auth changes.
  ///
  /// This [GoRouterRefreshStream] listens to [FirebaseAuth.authStateChanges]
  /// and notifies [GoRouter] whenever the authentication state changes.
  /// This triggers the [redirect] callback to re-evaluate with the new auth state.
  ///
  /// When a user signs in or out, this ensures [GoRouter] immediately checks
  /// if the current route is still valid and redirects if necessary.
  refreshListenable: GoRouterRefreshStream(
    FirebaseAuth.instance.authStateChanges(),
  ),
);

/// Shell widget that provides a persistent bottom navigation bar.
///
/// Wraps [ScanScreen], [BasketScreen], and [BalancesScreen] in a [Scaffold]
/// with a [NavigationBar] at the bottom. This allows seamless tab switching
/// without losing state or rebuilding the entire screen.
///
/// The selected tab is determined by the current route path via [_selectedIndexFor].
/// Tapping a nav item uses [GoRouter.go] to navigate without page transitions.
class _MainShell extends StatelessWidget {
  const _MainShell({required this.child});

  /// The current screen to display in the [Scaffold] body.
  ///
  /// This is the screen corresponding to the current route.
  /// Example: If route is `/scan`, [child] is [ScanScreen].
  final Widget child;

  /// Determines which bottom nav tab should be highlighted based on route path.
  ///
  /// Maps route paths to tab indices:
  /// - `/scan` → 0 (scanner icon)
  /// - `/basket` → 1 (basket icon)
  /// - `/benefits` → 2 (wallet icon)
  ///
  /// Parameters:
  /// - [path]: The current route path from [GoRouterState.uri.path]
  ///
  /// Returns: Tab index (0, 1, or 2)
  ///
  /// Used by [NavigationBar.selectedIndex] to highlight the active tab.
  int _selectedIndexFor(String path) {
    if (path.startsWith('/scan')) return 0;
    if (path.startsWith('/basket')) return 1;
    if (path.startsWith('/balances')) return 2;
    return 0; // Default to scan screen
  }

  /// Handles bottom navigation bar tap events.
  ///
  /// When user taps a nav destination, this method uses [GoRouter.go]
  /// to navigate to the corresponding route. The [NoTransitionPage]
  /// builders in the routes prevent page transition animations.
  ///
  /// Parameters:
  /// - [context]: Build context for accessing [GoRouter]
  /// - [index]: Tab index (0, 1, or 2)
  ///
  /// Navigation map:
  /// - Index 0 → `/scan` (barcode scanner)
  /// - Index 1 → `/basket` (shopping basket)
  /// - Index 2 → `/benefits` (WIC balances)
  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/scan');
        break;
      case 1:
        context.go('/basket');
        break;
      case 2:
        context.go('/balances');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Get current route path for tab highlighting.
    final path = GoRouterState.of(context).uri.path;

    /// Determine which tab should be selected.
    final selected = _selectedIndexFor(path);

    return Scaffold(
      /// Display the current screen (ScanScreen, BasketScreen, or BalancesScreen).
      body: child,

      /// Bottom navigation bar with three tabs.
      ///
      /// Includes:
      /// - Scan tab: [Icons.qr_code_scanner] (for barcode scanning)
      /// - Basket tab: [Icons.shopping_basket_outlined] (for shopping basket)
      /// - Benefits tab: [Icons.account_balance_wallet_outlined] (for WIC balances)
      ///
      /// The [selectedIndex] syncs with current route, and [onDestinationSelected]
      /// triggers navigation via [_onTap].
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner),
            label: 'Scan',
          ),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Benefits',
          ),
        ],
      ),
    );
  }
}
