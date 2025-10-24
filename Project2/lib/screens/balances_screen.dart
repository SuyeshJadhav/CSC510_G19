import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class BalancesScreen extends StatelessWidget {
  const BalancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (!app.balancesLoaded) {
      // ignore: discarded_futures
      context.read<AppState>().loadBalances(docId: 'default');
      return Scaffold(
        appBar: AppBar(title: const Text('Benefits')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final entries = app.balances.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      appBar: AppBar(title: const Text('Benefits')),
      body: entries.isEmpty
          ? const Center(child: Text('No category caps configured'))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (_, i) {
                final cat = entries[i].key;
                final allowed = entries[i].value['allowed'] ?? 0;
                final used = entries[i].value['used'] ?? 0;
                final pct = allowed == 0 ? 0.0 : used / allowed;
                return ListTile(
                  title: Text(cat),
                  subtitle: LinearProgressIndicator(value: pct),
                  trailing: Text('$used/$allowed'),
                );
              },
            ),
    );
  }
}
