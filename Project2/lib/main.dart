import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '/app_router.dart'; // Import the router instance

import 'firebase_options.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // We must create the AppState here
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This MultiProvider combines the providers from BOTH of your branches
    return MultiProvider(
      providers: [
        // 1. Provides the Auth user stream (from your login branch)
        StreamProvider<User?>(
          create: (_) => FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
        // 2. Proxies the User to the AppState (from your scanner branch,
        //    but updated for multi-user)
        ChangeNotifierProxyProvider<User?, AppState>(
          create: (_) => _appState,
          update: (context, user, appState) {
            if (appState == null) throw Exception('AppState is null');
            appState.updateUser(user);
            return appState;
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'WolfBite',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        // Use the router instance directly
        routerConfig: router,
      ),
    );
  }
}
