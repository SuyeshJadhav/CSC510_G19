import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../services/apl_service.dart';
import '../state/app_state.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _apl = AplService();
  final _input = TextEditingController();
  String? _last;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _check(String code) async {
    final upc = code.trim();
    if (upc.isEmpty || upc == _last || _busy) return;
    _last = upc;
    _busy = true;
    try {
      final info = await _apl.findByUpc(upc);
      if (!mounted) return;
      if (info == null) {
        _snack('Not found in APL');
        return;
      }
      final eligible = info['eligible'] == true;
      if (eligible) {
        context.read<AppState>().addItem(
              upc: upc,
              name: info['name'] as String,
              category: info['category'] as String,
            );
        _snack('WIC Approved ✅ ${info['name']}');
      } else {
        _snack('Not WIC Approved ❌');
        final subs = await _apl.substitutes(info['category'] as String);
        if (!mounted || subs.isEmpty) return;
        showModalBottomSheet(
          context: context,
          builder: (_) => SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('Try these substitutes:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...subs.map((s) => ListTile(
                      title: Text(s['name'] as String),
                      trailing: const Icon(Icons.add),
                      onTap: () {
                        context.read<AppState>().addItem(
                              upc: s['upc'] as String? ?? '',
                              name: s['name'] as String,
                              category: s['category'] as String,
                            );
                        Navigator.pop(context);
                      },
                    )),
              ],
            ),
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Item')),
      body: isMobile
          ? MobileScanner(onDetect: (cap) {
              final code = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue : null;
              if (code != null) _check(code);
            })
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Web demo: enter UPC'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          decoration: const InputDecoration(
                            hintText: '041196910045',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: _check,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _check(_input.text),
                        child: const Text('Check'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
