import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class BasketScreen extends StatelessWidget {
  const BasketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Basket')),
      body: app.basket.isEmpty
          ? const Center(child: Text('No items yet'))
          : ListView.separated(
              itemCount: app.basket.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final line = app.basket[i];
                return ListTile(
                  title: Text(line['name']),
                  subtitle: Text('${line['category']} • qty ${line['qty']}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => app.removeItem(line['upc']),
                  ),
                );
              },
            ),
    );
  }
}
