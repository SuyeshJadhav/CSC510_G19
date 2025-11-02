import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'app_router.dart';
import 'state/app_state.dart';

/// Main entry point for the WIC Shopping Assistant application.
///
/// Initializes [Firebase] and sets up the app's dependency injection layer
/// using [MultiProvider] from the `provider` package. This ensures:
/// - Real-time [FirebaseAuth] state changes are available to all widgets
/// - [AppState] is created once and persists across the widget tree
/// - User authentication changes automatically sync [AppState]
///
/// The app uses [MaterialApp.router] with [GoRouter] for navigation,
/// with auth guards configured in [router].
Future<void> main() async {
  /// Ensures Flutter engine is fully initialized before Firebase setup.
  ///
  /// Required for async operations in [main] and to access platform-specific
  /// features (camera permissions, Firestore, etc.).
  WidgetsFlutterBinding.ensureInitialized();

  /// Initializes Firebase with platform-specific options from [firebase_options.dart].
  ///
  /// This connects the app to your Firebase project and enables:
  /// - [FirebaseAuth] for user authentication
  /// - [FirebaseFirestore] for user balances and basket data
  /// - [CloudStorage] if needed in future
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  /// Starts the Flutter app.
  runApp(const MyApp());
}

/// Root widget that configures the app's theme and dependency injection.
///
/// Sets up a [MultiProvider] chain that:
/// 1. Listens to [FirebaseAuth.authStateChanges] via [StreamProvider]
/// 2. Wires [User] changes into [AppState] via [ChangeNotifierProxyProvider]
/// 3. Configures Material 3 theme with teal color scheme
/// 4. Sets up [GoRouter] for navigation with auth guards
///
/// All descendant widgets can access:
/// - Current [User] via `context.watch<User?>()`
/// - [AppState] via `context.watch<AppState>()`
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        /// Streams [FirebaseAuth] user changes to the widget tree.
        ///
        /// Listens to [FirebaseAuth.instance.authStateChanges()] which emits:
        /// - A [User] object when login succeeds
        /// - null when logout occurs
        /// - Initial state on app startup
        ///
        /// The [initialData: null] ensures the app shows login screen
        /// before Firebase completes the first auth check.
        ///
        /// Widgets can access this via:
        /// ```dart
        /// final user = context.watch<User?>();
        /// ```
        StreamProvider<User?>(
          create: (_) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),

        /// Syncs [User] changes into [AppState] for app-wide state management.
        ///
        /// This [ChangeNotifierProxyProvider] creates a dependency relationship:
        /// - Depends on: [StreamProvider<User?>] (the current user)
        /// - Manages: [AppState] instance (user-scoped state)
        ///
        /// When [User] changes:
        /// 1. [AppState.updateUser] is called with the new [User]
        /// 2. [AppState] clears or loads data based on login/logout
        /// 3. All widgets watching [AppState] rebuild automatically
        ///
        /// Widgets access this via:
        /// ```dart
        /// final appState = context.watch<AppState>();
        /// ```
        ///
        /// The [create] callback initializes [AppState] once on first build.
        /// The [update] callback runs whenever [User] changes.
        ChangeNotifierProxyProvider<User?, AppState>(
          create: (_) => AppState(),
          update: (_, user, appState) {
            appState!.updateUser(user);
            return appState;
          },
        ),
      ],

      /// Builds the app UI with Material 3 theme and GoRouter navigation.
      ///
      /// Uses [MaterialApp.router] instead of [MaterialApp] to integrate
      /// [GoRouter] for deep linking and auth-based route guards.
      child: MaterialApp.router(
        title: 'Smart WIC Cart',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
        routerConfig: router,
      ),
    );
  }
}
