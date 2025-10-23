import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class VisualizerScreen extends StatelessWidget {
  const VisualizerScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Category Usage')),
      body: Column(
        children: app.balances.entries.map((e) {
          final allowed = e.value['allowed'] ?? 0;
          final used = e.value['used'] ?? 0;
          return ListTile(
            title: Text(e.key),
            subtitle: LinearProgressIndicator(value: allowed == 0 ? 0 : used/allowed),
            trailing: Text('${(allowed==0?0:100*used/allowed).toStringAsFixed(0)}%'),
          );
        }).toList(),
      ),
    );
  }
}
