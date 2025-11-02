import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/apl_service.dart';
import '../state/app_state.dart';

/// Main screen for scanning product barcodes and managing the shopping basket.
///
/// Displays a live camera feed via [MobileScannerController] to capture
/// UPC codes. When a barcode is detected, looks up the product in the APL
/// (Approved Product List) via [AplService] and either:
/// - Adds the item to the basket if eligible and within category limits
/// - Shows an error dialog if ineligible or exceeds limits
/// - Suggests substitutes if the category is at capacity
///
/// This screen also displays the current basket count and provides quick
/// access to basket management via the [_BasketSummaryCard].
///
/// Usage: Navigated to via `/scan` route in [GoRouter].
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  /// Controller for the barcode scanning camera.
  ///
  /// Configured with [MobileScannerController] to detect barcodes in real-time.
  /// Disposed in [dispose] to release camera resources.
  final MobileScannerController _controller = MobileScannerController();

  /// Service instance for querying the Approved Product List.
  ///
  /// Used to validate scanned UPCs and find substitute products.
  final AplService _apl = AplService();

  /// Controller for manual UPC input on web platforms.
  ///
  /// Used in the web fallback UI where camera scanning is not available.
  final TextEditingController _input = TextEditingController();

  /// Whether a scan result is currently being processed.
  ///
  /// Prevents multiple simultaneous dialogs or database calls when the
  /// scanner detects the same barcode in consecutive frames.
  bool _processing = false;

  /// The most recently scanned or checked UPC code.
  ///
  /// Used for the "Re-check" button functionality on mobile and to prevent
  /// duplicate scans of the same barcode.
  String? _lastScanned;

  /// Timestamp of the last barcode scan.
  ///
  /// Used to implement a cooldown period to prevent rapid duplicate scans
  /// of the same barcode. After scanning, the same barcode cannot be
  /// processed again for [_scanCooldownMs] milliseconds.
  DateTime? _lastScanTime;

  /// Cooldown period in milliseconds between scans of the same barcode.
  ///
  /// Prevents the scanner from adding the same item multiple times when
  /// the barcode remains in the camera view. Default: 3 seconds.
  static const int _scanCooldownMs = 3000;

  /// Product information from the last successful APL lookup.
  ///
  /// Contains keys: 'upc', 'name', 'category', 'eligible'.
  /// Null if no product has been checked yet.
  Map<String, dynamic>? _lastInfo;

  /// Whether the last checked product was WIC-eligible.
  ///
  /// Controls the enabled state of the "Add to Basket" button.
  bool _lastEligible = false;

  @override
  void dispose() {
    _controller.dispose();
    _input.dispose();
    super.dispose();
  }

  /// Handles detected barcode scan events from [MobileScannerController].
  ///
  /// When a barcode is successfully scanned:
  /// 1. Checks [_processing] flag to prevent duplicate handling
  /// 2. Implements cooldown check to prevent rapid re-scans of same barcode
  /// 3. Looks up the product in APL via [AplService.findByUpc]
  /// 4. Validates eligibility and category limits via [AppState.canAdd]
  /// 5. Either adds to basket or shows an error dialog
  ///
  /// The cooldown mechanism ensures that once a barcode is scanned, it cannot
  /// be processed again for [_scanCooldownMs] milliseconds (default 3 seconds).
  /// This prevents multiple adds when the barcode stays in camera view.
  ///
  /// Side effects:
  /// - Sets [_processing] to true during async operations
  /// - Updates [_lastScanned] and [_lastScanTime] for cooldown tracking
  /// - Calls [AppState.addItem] if product is valid and allowed
  /// - Shows [_showErrorDialog] or [_showSubstitutesDialog] on failure
  /// - Shows [_showSuccessSnackbar] on success
  ///
  /// Parameters:
  /// - [capture]: The scan result containing detected barcodes
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    // ✅ FIX: Implement cooldown to prevent duplicate scans
    final now = DateTime.now();
    if (_lastScanned == code && _lastScanTime != null) {
      final timeSinceLastScan = now.difference(_lastScanTime!).inMilliseconds;
      if (timeSinceLastScan < _scanCooldownMs) {
        // Same barcode scanned too quickly - ignore
        return;
      }
    }

    setState(() {
      _processing = true;
      _lastScanned = code;
      _lastScanTime = now;
    });

    try {
      final appState = context.read<AppState>();
      final product = await _apl.findByUpc(code);

      if (product == null) {
        if (mounted) _showErrorDialog('Product not found in WIC database');
        return;
      }

      final eligible = product['eligible'] == true;
      if (!eligible) {
        if (mounted) _showErrorDialog('This product is not WIC-eligible');
        return;
      }

      final category = product['category'] as String? ?? 'Unknown';
      final name = product['name'] as String? ?? 'Unknown Product';

      // Store for re-check functionality
      setState(() {
        _lastInfo = product;
        _lastEligible = eligible;
      });

      if (!appState.canAdd(category)) {
        if (mounted) {
          await _showSubstitutesDialog(category, name);
        }
        return;
      }

      appState.addItem(upc: code, name: name, category: category);
      if (mounted) _showSuccessSnackbar(name);
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  /// Checks the eligibility of a product by UPC code.
  ///
  /// Looks up the product in the APL via [AplService.findByUpc] and updates
  /// the UI with product information and eligibility status.
  ///
  /// Used for:
  /// - Manual UPC entry on web platforms
  /// - Re-checking a previously scanned product
  ///
  /// Parameters:
  /// - [upc]: The Universal Product Code to check
  ///
  /// Side effects:
  /// - Updates [_lastInfo] and [_lastEligible] state
  /// - Shows [_showErrorDialog] if product not found
  Future<void> _checkEligibility(String upc) async {
    if (upc.isEmpty) return;

    setState(() {
      _processing = true;
      _lastScanned = upc;
    });

    try {
      final product = await _apl.findByUpc(upc);

      if (product == null) {
        setState(() {
          _lastInfo = null;
          _lastEligible = false;
        });
        if (mounted) _showErrorDialog('Product not found in WIC database');
        return;
      }

      final eligible = product['eligible'] == true;

      setState(() {
        _lastInfo = product;
        _lastEligible = eligible;
      });

      if (!eligible && mounted) {
        _showErrorDialog('This product is not WIC-eligible');
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  /// Adds the currently checked product to the shopping basket.
  ///
  /// Uses [_lastInfo] to get product details and calls [AppState.addItem].
  /// Only enabled when [_lastEligible] is true.
  ///
  /// Side effects:
  /// - Calls [AppState.addItem] with product details
  /// - Shows [_showSuccessSnackbar] on success
  /// - Shows [_showSubstitutesDialog] if category limit reached
  Future<void> _addToBasket() async {
    if (_lastInfo == null || !_lastEligible) return;

    final appState = context.read<AppState>();
    final category = _lastInfo!['category'] as String? ?? 'Unknown';
    final name = _lastInfo!['name'] as String? ?? 'Unknown Product';
    final upc = _lastInfo!['upc'] as String? ?? '';

    if (!appState.canAdd(category)) {
      if (mounted) {
        await _showSubstitutesDialog(category, name);
      }
      return;
    }

    appState.addItem(upc: upc, name: name, category: category);
    if (mounted) _showSuccessSnackbar(name);

    // Clear last info after adding
    setState(() {
      _lastInfo = null;
      _lastEligible = false;
      _lastScanned = null;
      _lastScanTime = null; // ✅ Reset cooldown timer
      _input.clear();
    });
  }

  /// Runs diagnostic checks for debugging purposes.
  ///
  /// Shows a dialog with current state information including:
  /// - User authentication status
  /// - Balances loaded status
  /// - Current basket contents
  /// - Last scanned product info
  /// - Scan cooldown status
  ///
  /// Used for troubleshooting issues during development.
  void _diagnose() {
    final appState = context.read<AppState>();
    final user = FirebaseAuth.instance.currentUser;

    // Calculate time since last scan for diagnostics
    String scanCooldownStatus = 'N/A';
    if (_lastScanTime != null) {
      final timeSinceLastScan = DateTime.now()
          .difference(_lastScanTime!)
          .inMilliseconds;
      final cooldownRemaining = _scanCooldownMs - timeSinceLastScan;
      if (cooldownRemaining > 0) {
        scanCooldownStatus =
            'Cooldown: ${(cooldownRemaining / 1000).toStringAsFixed(1)}s';
      } else {
        scanCooldownStatus = 'Ready to scan';
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diagnostics'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('User: ${user?.email ?? "Not logged in"}'),
              Text('UID: ${user?.uid ?? "N/A"}'),
              const Divider(),
              Text('Balances loaded: ${appState.balancesLoaded}'),
              Text('Basket items: ${appState.basket.length}'),
              Text('Categories: ${appState.balances.keys.length}'),
              const Divider(),
              Text('Last scanned: ${_lastScanned ?? "None"}'),
              Text('Last eligible: $_lastEligible'),
              Text('Scan status: $scanCooldownStatus'),
              if (_lastInfo != null) ...[
                const Divider(),
                Text('Product: ${_lastInfo!['name']}'),
                Text('Category: ${_lastInfo!['category']}'),
                Text('UPC: ${_lastInfo!['upc']}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Displays a success message when a product is added to the basket.
  ///
  /// Shows a [SnackBar] at the bottom of the screen with the product [name]
  /// and a checkmark icon.
  void _showSuccessSnackbar(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Added: $name')),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows an error dialog with a custom [message].
  ///
  /// Displays an [AlertDialog] with an error icon and the provided message.
  /// User must tap "OK" to dismiss.
  ///
  /// Common messages:
  /// - "Product not found in WIC database"
  /// - "This product is not WIC-eligible"
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Cannot Add Item'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows a dialog with substitute product suggestions.
  ///
  /// When a [category] limit is reached, fetches up to 3 alternative products
  /// via [AplService.substitutes] and displays them in a dialog. User can
  /// tap on a substitute to add it instead of the originally scanned product.
  ///
  /// Parameters:
  /// - [category]: The product category at capacity
  /// - [originalName]: Name of the originally scanned product (for context)
  ///
  /// Side effects:
  /// - Calls [AppState.addItem] if user selects a substitute
  /// - Shows [_showSuccessSnackbar] after successful substitution
  Future<void> _showSubstitutesDialog(
    String category,
    String originalName,
  ) async {
    final subs = await _apl.substitutes(category, max: 3);

    if (!mounted) return;

    if (subs.isEmpty) {
      _showErrorDialog(
        'You have reached your limit for $category and no substitutes are available.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$category Limit Reached'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve reached your limit for $category.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Try these substitutes:'),
            const SizedBox(height: 8),
            ...subs.map(
              (sub) => ListTile(
                dense: true,
                leading: const Icon(Icons.swap_horiz, color: Colors.blue),
                title: Text(sub['name'] ?? 'Unknown'),
                subtitle: Text('UPC: ${sub['upc']}'),
                onTap: () {
                  Navigator.pop(ctx);
                  final appState = context.read<AppState>();
                  appState.addItem(
                    upc: sub['upc'] ?? '',
                    name: sub['name'] ?? 'Substitute',
                    category: category,
                  );
                  _showSuccessSnackbar(sub['name'] ?? 'Substitute');
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
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
