import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  bool _busy = false;
  String? _lastScanned;
  Map<String, dynamic>? _lastInfo;
  bool _lastEligible = false;

  @override
  void initState() {
    super.initState();
    // Load user-scoped balances/basket once we have a context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().loadUserState();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _diagnose() async {
    // Put a UPC that exists in your Firestore APL for a quick ping test.
    const testUpc = '000000743266';
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

  /// Only checks eligibility; does NOT add to basket.
  Future<void> _checkEligibility(String code) async {
    final upc = code.trim();
    if (upc.isEmpty || _busy) return;

    _busy = true;
    try {
      final info = await _apl.findByUpc(upc);
      if (!mounted) return;

      if (info == null) {
        setState(() {
          _lastInfo = null;
          _lastEligible = false;
          _lastScanned = upc;
        });
        _snack('Not found in APL');
        return;
      }

      final ok = info['eligible'] == true;
      setState(() {
        _lastInfo = info;
        _lastEligible = ok;
        _lastScanned = upc;
      });

      if (ok) {
        _snack('✅ Eligible: ${info['name']}');
      } else {
        _snack('❌ Not WIC Approved');
        // Offer substitutes (optional)
        final subs = await _apl.substitutes(info['category'] as String);
        if (!mounted || subs.isEmpty) return;
        // Lightweight suggestion sheet
        // ignore: use_build_context_synchronously
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
                    title: Text((s['name'] ?? '') as String),
                    trailing: const Icon(Icons.add),
                    onTap: () {
                      context.read<AppState>().addItem(
                        upc: (s['upc'] ?? '') as String,
                        name: (s['name'] ?? '') as String,
                        category: (s['category'] ?? '') as String,
                      );
                      Navigator.pop(context);
                      context.go('/basket');
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

  /// Adds the last eligible item to basket and navigates to /basket.
  void _addToBasket() {
    if (!_lastEligible || _lastInfo == null) {
      _snack('Check eligibility first!');
      return;
    }
    final info = _lastInfo!;
    context.read<AppState>().addItem(
      upc: (info['upc'] ?? '') as String,
      name: (info['name'] ?? '') as String,
      category: (info['category'] ?? '') as String,
    );
    _snack('✅ Added: ${info['name']}');
    context.go('/basket');
  }

  // Mobile scanner handler (debounced)
  void _onDetect(BarcodeCapture cap) {
    if (_busy) return;
    final code = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue : null;
    if (code == null) return;
    if (code == _lastScanned) return; // debounce same code
    _checkEligibility(code);
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
      body: isMobile
          ? SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Place barcode inside the square',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: MobileScanner(onDetect: _onDetect),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: (_lastInfo != null)
                              ? () => _checkEligibility(_lastScanned ?? '')
                              : null,
                          child: const Text('Re-check'),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: _lastEligible ? _addToBasket : null,
                          child: const Text('Add to Basket'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              // Web fallback: manual UPC entry
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
                          onSubmitted: _checkEligibility,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _checkEligibility(_input.text),
                        child: const Text('Check Eligibility'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _lastEligible ? _addToBasket : null,
                        child: const Text('Add to Basket'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_lastInfo != null)
                    Card(
                      margin: const EdgeInsets.only(top: 4),
                      child: ListTile(
                        title: Text((_lastInfo!['name'] ?? '') as String),
                        subtitle: Text(
                          'UPC: ${_lastInfo!['upc'] ?? ''} • '
                          'Category: ${_lastInfo!['category'] ?? ''}',
                        ),
                        trailing: _lastEligible
                            ? const Icon(Icons.verified, color: Colors.green)
                            : const Icon(Icons.block, color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
