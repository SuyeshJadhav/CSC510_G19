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
  const ScanScreen({super.key, this.aplService, this.auth});
  final AplService? aplService;
  final FirebaseAuth? auth;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _input = TextEditingController();
  late final AplService _apl;
  late final FirebaseAuth _auth;

  String? _lastScanned;
  Map<String, dynamic>? _lastInfo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _apl = widget.aplService ?? AplService();
    _auth = widget.auth ?? FirebaseAuth.instance;
  }

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
  // Future<void> _diagnose() async {
  //   const testUpc = '000000743266';
  //   try {
  //     final info = await _apl.findByUpc(testUpc);
  //     if (!mounted) return;
  //     _snack(
  //       info == null
  //           ? 'Firestore MISSING: $testUpc'
  //           : 'Firestore OK: $testUpc → ${info['name']}',
  //     );
  //   } catch (e) {
  //     _snack('Firestore ERROR: $e');
  //   }
  // }

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
    final category = _lastInfo!['category'] ?? 'Unknown';

    // Check if item can be added
    if (!appState.canAdd(category)) {
      _snack('Cannot add: Category limit reached');
      return;
    }

    appState.addItem(
      upc: _lastScanned ?? '',
      name: _lastInfo!['name'] ?? 'Unknown',
      category: category,
    );

    _snack('Added ${_lastInfo!['name']} to basket');

    // Clear the scanned item after adding
    setState(() {
      _lastScanned = null;
      _lastInfo = null;
      _input.clear();
    });
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
    final appState = context.watch<AppState>();
    final isMobile = MediaQuery.of(context).size.width < 600;
    final canAdd =
        _lastInfo != null && appState.canAdd(_lastInfo!['category'] ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // await FirebaseAuth.instance.signOut();
              await _auth.signOut();
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
                        color: Color(0xFFD1001C),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFD1001C),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: MobileScanner(onDetect: _onDetect),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: (_lastInfo != null)
                                  ? () => _checkEligibility(_lastScanned ?? '')
                                  : null,
                              child: const Text('Re-check'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: canAdd ? _addToBasket : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: canAdd
                                    ? const Color(0xFFD1001C)
                                    : Colors.grey.shade300,
                              ),
                              child: const Text('Add to Basket'),
                            ),
                          ),
                        ],
                      ),
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
                                  color: Color(0xFFD1001C),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Category: ${_lastInfo!['category']}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              Text(
                                'UPC: $_lastScanned',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              if (!canAdd) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 16,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Category limit reached',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 4,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_scanner,
                            size: 64,
                            color: const Color(0xFFD1001C),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Enter UPC Code',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD1001C),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Type the barcode number manually',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextField(
                            controller: _input,
                            decoration: InputDecoration(
                              labelText: 'UPC Code',
                              hintText: '000000000000',
                              prefixIcon: const Icon(
                                Icons.numbers,
                                color: Color(0xFFD1001C),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD1001C),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFD1001C),
                                  width: 2,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 13,
                            onSubmitted: (value) {
                              if (value.isNotEmpty) {
                                _checkEligibility(value);
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    final upc = _input.text.trim();
                                    if (upc.isNotEmpty) {
                                      _checkEligibility(upc);
                                    }
                                  },
                                  icon: const Icon(Icons.search),
                                  label: const Text('Check'),
                                ),
                              ),
                              if (_lastInfo != null) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: canAdd ? _addToBasket : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: canAdd
                                          ? const Color(0xFFD1001C)
                                          : Colors.grey.shade300,
                                    ),
                                    icon: const Icon(Icons.add_shopping_cart),
                                    label: const Text('Add'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_lastInfo != null) ...[
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFD1001C,
                                ).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFFD1001C,
                                  ).withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _lastInfo!['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFFD1001C),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Category: ${_lastInfo!['category']}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  Text(
                                    'UPC: $_lastScanned',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (!canAdd) ...[
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                          color: Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Category limit reached',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
