import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // 1. IMPORT GOROUTER
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().loadBalances();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _diagnose() async {
    const testUpc = '000000743266'; // change to one that exists
    try {
      final info = await _apl.findByUpc(testUpc);
      if (!mounted) return;
      _snack(
        info == null
            ? 'Firestore MISSING: $testUpc'
            : 'Firestore OK: $testUpc → ${info['name']}',
      );
    } catch (e) {
      _snack('Firestore ERROR: $e');
    }
  }

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
        final bool isNewItem = context.read<AppState>().addItem(
          upc: upc,
          name: info['name'] as String,
          category: info['category'] as String,
        );

        if (isNewItem) {
          _snack('WIC Approved ✅ ${info['name']}');
        } else {
          final appState = context.read<AppState>();
          final canAdd = appState.canAdd(info['category'] as String);
          if (!canAdd) {
            _snack('Limit reached for ${info['category']}');
          } else {
            // _snack('Quantity updated ✅ ${info['name']}');
          }
        }

        if (mounted) context.pop(true);
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
                const Text(
                  'Try these substitutes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...subs.map(
                  (s) => ListTile(
                    title: Text(s['name'] as String),
                    trailing: const Icon(Icons.add),
                    onTap: () {
                      context.read<AppState>().addItem(
                        upc: s['upc'] as String? ?? '',
                        name: s['name'] as String,
                        category: s['category'] as String,
                      );
                      Navigator.pop(context);

                      // Also pop the scan screen itself, using GoRouter
                      if (mounted) context.pop(true);
                    },
                  ),
                ),
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
    final isMobile = !kIsWeb;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Item'),
        actions: [
          IconButton(
            tooltip: 'Run diagnostics',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: _diagnose,
          ),
        ],
      ),
      body: isMobile
          ? SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Place barcode in the square',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MobileScanner(
                          onDetect: (cap) {
                            final code = cap.barcodes.isNotEmpty
                                ? cap.barcodes.first.rawValue
                                : null;
                            if (code != null) _check(code);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
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
                            hintText: '000000743266',
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
