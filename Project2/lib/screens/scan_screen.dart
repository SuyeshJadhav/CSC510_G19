import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../services/apl_service.dart';

/// Barcode scanning screen for WIC eligibility checking.
///
/// Features:
/// - Live camera barcode scanning on mobile devices
/// - Manual UPC entry via text field on desktop
/// - WIC eligibility verification via [AplService]
/// - Add eligible items to shopping basket
/// - Diagnostic test for Firestore connectivity
///
/// Uses [MobileScanner] widget for camera-based scanning.
/// Falls back to text input on web/desktop platforms.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _input = TextEditingController();
  final _apl = AplService();

  String? _lastScanned;
  Map<String, dynamic>? _lastInfo;
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Shows a [SnackBar] with the provided message.
  ///
  /// Checks [mounted] before showing to prevent errors after disposal.
  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Tests Firestore connectivity by querying a known UPC.
  ///
  /// Uses test UPC `000000743266` to verify [AplService] can read from Firestore.
  /// Displays success or error message via [_snack].
  Future<void> _diagnose() async {
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

  /// Checks WIC eligibility for the scanned/entered barcode.
  ///
  /// Process:
  /// 1. Validates UPC format
  /// 2. Queries Firestore APL via [AplService.findByUpc]
  /// 3. Displays product info and eligibility status
  ///
  /// Does NOT add item to basket - use [_addToBasket] for that.
  /// Sets [_busy] to prevent concurrent scans.
  Future<void> _checkEligibility(String code) async {
    final upc = code.trim();
    if (upc.isEmpty || _busy) return;

    _busy = true;
    try {
      final info = await _apl.findByUpc(upc);
      if (!mounted) return;

      if (info == null) {
        _snack('UPC $upc not found in APL');
        setState(() {
          _lastScanned = upc;
          _lastInfo = null;
        });
        return;
      }

      setState(() {
        _lastScanned = upc;
        _lastInfo = info;
      });

      final name = info['name'] ?? 'Unknown';
      final cat = info['category'] ?? '?';
      _snack('$name ($cat) - Eligible!');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      _busy = false;
    }
  }

  /// Adds the currently scanned item to the shopping basket.
  ///
  /// Requires [_lastInfo] to be set (item must be scanned/checked first).
  /// Extracts [upc], [name], and [category] from [_lastInfo] and passes them
  /// to [AppState.addItem] as named parameters.
  ///
  /// Shows confirmation [SnackBar] after successful addition.
  void _addToBasket() {
    if (_lastInfo == null) {
      _snack('No item scanned yet');
      return;
    }

    final appState = context.read<AppState>();
    appState.addItem(
      upc: _lastScanned ?? '',
      name: _lastInfo!['name'] ?? 'Unknown',
      category: _lastInfo!['category'] ?? 'Unknown',
    );

    _snack('Added ${_lastInfo!['name']} to basket');
  }

  /// Handles barcode detection from [MobileScanner].
  ///
  /// Extracts first barcode from [capture] and calls [_checkEligibility].
  /// Prevents multiple concurrent scans via [_busy] flag.
  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      _checkEligibility(barcode!.rawValue!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Test Firestore',
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
                        FilledButton(
                          onPressed: _lastInfo != null ? _addToBasket : null,
                          child: const Text('Add to Cart'),
                        ),
                      ],
                    ),
                    if (_lastInfo != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _lastInfo!['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text('Category: ${_lastInfo!['category']}'),
                              Text('UPC: $_lastScanned'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Enter UPC manually',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _input,
                          decoration: const InputDecoration(
                            labelText: 'UPC Code',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: _checkEligibility,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _checkEligibility(_input.text),
                                child: const Text('Check'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _lastInfo != null
                                    ? _addToBasket
                                    : null,
                                child: const Text('Add'),
                              ),
                            ),
                          ],
                        ),
                        if (_lastInfo != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _lastInfo!['name'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('Category: ${_lastInfo!['category']}'),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
