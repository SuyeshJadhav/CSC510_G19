import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class BasketScreen extends StatelessWidget {
  const BasketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the AppState and watch for changes
    final app = context.watch<AppState>();

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
      body: app.basket.isEmpty
          ? Center(
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
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan an item to get started',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          // 2. The list of items
          : ListView.separated(
              itemCount: app.basket.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                // Get the item data from the basket
                final line = app.basket[i];
                final String upc = line['upc'] ?? '';
                final String name = line['name'] ?? 'Unknown';
                final String category = line['category'] ?? 'N/A';
                final int qty = line['qty'] ?? 0;

                // Check if the "Increase" button should be disabled
                final bool canIncrement = app.canAdd(category);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(category),

                  // 3. Quantity Editor
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min, // Keeps the Row compact
                    children: [
                      // "Remove" button
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: Theme.of(context).colorScheme.error,
                        onPressed: () => app.decrementItem(upc),
                      ),
                      // Quantity display
                      Text(
                        '$qty',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // "Add" button (disabled if limit is reached)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: canIncrement
                            ? () => app.incrementItem(upc)
                            : null,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
