// lib/app_router.dart
import 'package:go_router/go_router.dart';
import 'screens/scan_screen.dart';

final GoRouter router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const ScanScreen()),
  ],
);
