import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// 1. Convert to a StatefulWidget to manage the controller and detection state
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // 2. Create a controller for the scanner
  final MobileScannerController controller = MobileScannerController(
    // We are scanning barcodes, not just QR codes
    formats: [BarcodeFormat.all],
  );

  // 3. Clean up the controller when the widget is removed
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () => controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
        ],
      ),
      // 1. Use SafeArea and Center to place everything in the middle
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Place barcode in the square',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // 2. Create a sized box to constrain the scanner
              SizedBox(
                width: 300, // You can change this size
                height: 300, // You can change this size
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    controller: controller,
                    onDetect: (BarcodeCapture capture) {
                      // Get the scanned barcode value
                      final String? code = capture.barcodes.first.rawValue;

                      if (code != null) {
                        // Stop the camera
                        controller.stop();

                        // 3. Show the result dialog (same as before)
                        showDialog<String>(
                          // Expect a String to be returned
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext dialogContext) {
                            return AlertDialog(
                              title: const Text('Barcode Scanned'),
                              content: Text('Scanned code: $code'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Scan Again'),
                                  onPressed: () {
                                    // 3. Pop the dialog, returning null
                                    Navigator.of(dialogContext).pop();
                                  },
                                ),
                                TextButton(
                                  child: const Text('Use Code'),
                                  onPressed: () {
                                    // 4. Pop the dialog, returning the code
                                    Navigator.of(dialogContext).pop(code);
                                  },
                                ),
                              ],
                            );
                          },
                        ).then((String? returnedCode) {
                          // 5. This code runs AFTER the dialog is closed.
                          if (returnedCode != null) {
                            // User pressed "Use Code".
                            // Now it's safe to pop the screen.
                            Navigator.of(context).pop(returnedCode);
                          } else {
                            // User pressed "Scan Again".
                            controller.start(); // Restart camera
                          }
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
