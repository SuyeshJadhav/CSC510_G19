import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'app_router.dart';
import 'state/app_state.dart';

/// Main entry point for the WolfBite food delivery application.
///
/// Initializes [Firebase] and sets up the app's dependency injection layer
/// using [MultiProvider] from the `provider` package. This ensures:
/// - Real-time [FirebaseAuth] state changes are available to all widgets
/// - [AppState] is created once and persists across the widget tree
/// - User authentication changes automatically sync [AppState]
///
/// The app uses [MaterialApp.router] with [GoRouter] for navigation,
/// with auth guards configured in [router].
///
/// ## Initialization Steps:
/// 1. Ensures Flutter engine is fully initialized via [WidgetsFlutterBinding.ensureInitialized]
/// 2. Initializes Firebase with platform-specific options from [DefaultFirebaseOptions]
/// 3. Starts the Flutter app with [MyApp] as the root widget
///
/// ## Side Effects:
/// - Connects to Firebase project (Auth, Firestore)
/// - Enables platform-specific features (camera, storage)
/// - Configures dependency injection for the entire app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
/// ## Dependency Injection Structure
///
/// The provider hierarchy allows all descendant widgets to access:
/// - Current [User] via `context.watch<User?>()`
/// - [AppState] via `context.watch<AppState>()`
///
/// ## Provider Chain Details
///
/// ### StreamProvider<User?>
/// Streams [FirebaseAuth] user changes to the widget tree. Listens to
/// [FirebaseAuth.instance.authStateChanges()] which emits:
/// - A [User] object when login succeeds
/// - `null` when logout occurs
/// - Initial state on app startup
///
/// The `initialData: null` ensures the app shows login screen before
/// Firebase completes the first auth check.
///
/// ### ChangeNotifierProxyProvider<User?, AppState>
/// Syncs [User] changes into [AppState] for app-wide state management.
/// This creates a dependency relationship where [AppState] depends on
/// [StreamProvider<User?>].
///
/// When [User] changes:
/// 1. [AppState.updateUser] is called with the new [User]
/// 2. [AppState] clears or loads data based on login/logout
/// 3. All widgets watching [AppState] rebuild automatically
///
/// The `create` callback initializes [AppState] once on first build.
/// The `update` callback runs whenever [User] changes.
///
/// ## Theme Configuration
///
/// Uses Material 3 design with teal as the primary color seed. The theme
/// is automatically generated from [ColorScheme] based on the seed color.
///
/// ## Navigation Setup
///
/// Uses [MaterialApp.router] with [GoRouter] configured in [router] for:
/// - Deep linking support
/// - Auth-based route guards
/// - Declarative navigation
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
        /// - `null` when logout occurs
        /// - Initial state on app startup
        ///
        /// The `initialData: null` ensures proper loading state handling.
        StreamProvider<User?>(
          create: (_) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),

        /// Syncs [User] changes into [AppState] for app-wide state management.
        ///
        /// Creates a dependency relationship where [AppState] depends on
        /// [StreamProvider<User?>].
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
      child: MaterialApp.router(
        title: 'Smart WIC Cart',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
        routerConfig: router,
      ),
    );
  }
}
