import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

/// Authentication screen for existing users to sign in.
///
/// Provides email and password input fields with validation and calls
/// [FirebaseAuth.signInWithEmailAndPassword] to authenticate. On successful
/// login, the user is automatically redirected to [ScanScreen] via the
/// [GoRouter] redirect logic in [app_router.dart].
///
/// Features:
/// - Email and password text fields with validation
/// - Error messages for invalid credentials
/// - Loading state during authentication
/// - Link to [SignupPage] for new users
///
/// Usage: Navigated to via `/login` route (initial route for logged-out users).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Form key for validation of email and password fields.
  final _formKey = GlobalKey<FormState>();

  /// Controller for the email input field.
  final _emailController = TextEditingController();

  /// Controller for the password input field.
  final _passwordController = TextEditingController();

  /// Whether an authentication request is in progress.
  ///
  /// Used to disable the login button and show a loading indicator
  /// during [FirebaseAuth.signInWithEmailAndPassword] calls.
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates form inputs and attempts to sign in via [FirebaseAuth].
  ///
  /// Steps:
  /// 1. Validates form fields via [_formKey]
  /// 2. Sets [_loading] to true and shows progress indicator
  /// 3. Calls [FirebaseAuth.instance.signInWithEmailAndPassword]
  /// 4. On success, user is redirected by [GoRouter] to `/scan`
  /// 5. On failure, shows [SnackBar] with error message
  ///
  /// Side effects:
  /// - Updates [_loading] state for UI feedback
  /// - Navigates to [ScanScreen] on successful authentication
  /// - Displays error messages via [ScaffoldMessenger]
  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      // GoRouter redirect handles navigation automatically
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email format';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App logo/icon
                  Icon(
                    Icons.shopping_cart,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'WIC Shopping Assistant',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  ElevatedButton(
                    onPressed: _loading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign In', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),

                  // Sign up link
                  TextButton(
                    onPressed: () => context.go('/signup'),
                    child: const Text('Don\'t have an account? Sign up'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
