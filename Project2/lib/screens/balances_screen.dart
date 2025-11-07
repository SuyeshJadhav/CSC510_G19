import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../state/app_state.dart';

/// Screen displaying WIC benefit balances and account management.
///
/// Shows the user's current benefit usage for each WIC category, with
/// visual progress indicators. Each category displays:
/// - Items used vs. allowed limit
/// - Progress bar with color-coded status (green/orange/red)
/// - "Unlimited" badge for uncapped categories (CVB, produce)
///
/// Also provides account management features:
/// - Sign out button that clears state and returns to [LoginScreen]
/// - Loading state while [AppState.loadUserState] completes
///
/// This screen watches [AppState.balancesLoaded] to determine when to
/// show data vs. loading spinner.
///
/// Usage: Navigated to via `/benefits` route in bottom navigation.
class BalancesScreen extends StatelessWidget {
  const BalancesScreen({super.key, this.auth});
  final FirebaseAuth? auth;

  /// Signs the user out of [FirebaseAuth] and navigates to login screen.
  ///
  /// Clears all local state in [AppState] automatically via the auth
  /// listener wired in [main.dart].
  ///
  /// Side effects:
  /// - Calls [FirebaseAuth.instance.signOut]
  /// - Navigates to `/login` via [GoRouter]
  Future<void> _signOut(BuildContext context) async {
    await (auth ?? FirebaseAuth.instance).signOut();
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final balances = appState.balances;
    final loaded = appState.balancesLoaded;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WIC Benefits'),
        actions: [
          // Sign out button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : balances.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                ...balances.entries.map(
                  (entry) =>
                      _BalanceCard(category: entry.key, data: entry.value),
                ),
              ],
            ),
    );
  }

  /// Builds the header section explaining benefit balances.
  ///
  /// Shows an informational card at the top of the screen with an icon
  /// and description text.
  Widget _buildHeader() {
    return Card(
      color: Colors.blue.shade50,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 32),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your WIC benefit balances update as you add items to your basket.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the UI shown when no benefit data exists yet.
  ///
  /// Displays a centered message encouraging the user to start scanning
  /// products. This typically shows for new accounts before any items
  /// have been added.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No benefit data yet',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan products to see your balances',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

/// Individual benefit category balance card.
///
/// Displays usage information for a single WIC category with a visual
/// progress indicator. The [data] map from [AppState.balances] contains:
/// - `'allowed'`: [int]? - Max items (null = unlimited)
/// - `'used'`: [int] - Current usage count
///
/// The progress bar changes color based on usage percentage:
/// - Green: 0-60% used
/// - Orange: 60-85% used
/// - Red: 85-100% used
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.category, required this.data});

  final String category;
  final Map<String, dynamic> data;

  /// Calculates the color for the progress bar based on usage percentage.
  ///
  /// Returns:
  /// - [Colors.green]: Less than 60% used
  /// - [Colors.orange]: 60-85% used
  /// - [Colors.red]: 85% or more used
  ///
  /// For unlimited categories (allowed is null), always returns green.
  Color _getProgressColor(int? allowed, int used) {
    if (allowed == null) return const Color(0xFFD1001C);
    final pct = used / allowed;
    if (pct < 0.6) return const Color(0xFFD1001C);
    if (pct < 0.85) return Colors.orange.shade600;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final allowed = data['allowed'] as int?;
    final used = data['used'] as int? ?? 0;
    final isUnlimited = allowed == null;
    final progress = isUnlimited ? 0.0 : (used / allowed).clamp(0.0, 1.0);
    final color = _getProgressColor(allowed, used);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category name and status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD1001C),
                    ),
                  ),
                ),
                if (isUnlimited)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1001C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Unlimited',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD1001C),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Usage text
            Text(
              isUnlimited
                  ? 'Used: $used items'
                  : 'Used: $used of $allowed items',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
            if (!isUnlimited) ...[
              const SizedBox(height: 8),
              // Progress bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
