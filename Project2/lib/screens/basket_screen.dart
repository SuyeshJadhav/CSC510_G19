import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

/// Screen displaying the user's current shopping basket with item management.
///
/// Shows all products added via [ScanScreen] with their quantities and
/// provides controls to:
/// - Increment quantity ([AppState.incrementItem])
/// - Decrement quantity ([AppState.decrementItem])
/// - View total item count
///
/// Items are grouped by product (UPC) with quantity controls. When quantity
/// reaches zero, the item is automatically removed from [AppState.basket].
///
/// This screen watches [AppState] for real-time updates when items are
/// modified from other screens or when barcode scanning adds new products.
///
/// Usage: Navigated to via `/basket` route or the basket summary card
/// in [ScanScreen].
class BasketScreen extends StatelessWidget {
  const BasketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the AppState and watch for changes
    final app = context.watch<AppState>();
    final basket = app.basket;
    final totalItems = basket.fold<int>(
      0,
      (sum, item) => sum + (item['qty'] as int? ?? 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Basket'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: basket.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                // Total items header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Items:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$totalItems',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                // Basket items list
                Expanded(
                  child: ListView.builder(
                    itemCount: basket.length,
                    itemBuilder: (context, index) {
                      final item = basket[index];
                      return _BasketItemTile(item: item);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  /// Builds the UI shown when the basket is empty.
  ///
  /// Displays a centered message with an icon encouraging the user to
  /// scan products. Provides a button to navigate back to [ScanScreen].
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_basket_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Your basket is empty',
            style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan products to add them here',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/scan'),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Start Scanning'),
          ),
        ],
      ),
    );
  }
}

/// Individual basket item tile with quantity controls.
///
/// Displays product information from [item] map:
/// - Name
/// - Category
/// - Current quantity
///
/// Provides increment/decrement buttons that call [AppState.incrementItem]
/// and [AppState.decrementItem] respectively. Buttons are styled with
/// visual feedback and disabled states based on category limits.
class _BasketItemTile extends StatelessWidget {
  const _BasketItemTile({required this.item});

  /// The basket item data map containing 'upc', 'name', 'category', and 'qty'.
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final upc = item['upc'] as String? ?? '';
    final name = item['name'] as String? ?? 'Unknown';
    final category = item['category'] as String? ?? 'Unknown';
    final qty = item['qty'] as int? ?? 0;
    final canAdd = appState.canAdd(category);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            qty.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(category, style: TextStyle(color: Colors.grey.shade600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decrement button
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.red.shade400,
              onPressed: () => appState.decrementItem(upc),
              tooltip: 'Remove one',
            ),
            // Increment button
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: canAdd ? Colors.green.shade400 : Colors.grey.shade300,
              ),
              onPressed: canAdd ? () => appState.incrementItem(upc) : null,
              tooltip: canAdd ? 'Add one' : 'Category limit reached',
            ),
          ],
        ),
      ),
    );
  }
}
