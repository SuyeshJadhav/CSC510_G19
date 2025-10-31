import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        // Listen to the user's authentication state
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. If the snapshot has user data, they are logged in
          if (snapshot.hasData) {
            return const HomeScreen();
          }
          // 2. If the snapshot has no data, they are logged out
          else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}