import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/presentation/widgets/auth_code_dialog.dart';
import 'package:smashrite/core/network/network_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanning = false;
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _hasScanned = true;
      _isScanning = false;
    });

    _controller.stop();
    _handleQRCodeScanned(code);
  }

  Future<void> _handleQRCodeScanned(String qrData) async {
    try {
      // Parse QR code data (expected format: "192.168.1.100:8000:ServerName")
      final parts = qrData.trim().split(':');

      if (parts.length != 3) {
        _showErrorDialog(
          'Invalid QR code format. Expected: IP:PORT:SERVER_NAME',
        );
        return;
      }

      final ipAddress = parts[0];
      final port = int.tryParse(parts[1]);
      final serverName =
          parts.length > 2 && parts[2].isNotEmpty
              ? parts[2]
              : 'Smashrite Unknown Server';

      if (port == null || port < 1 || port > 65535) {
        _showErrorDialog('Invalid port number in QR code');
        return;
      }

      // Validate IP is local
      if (!NetworkService.isLocalIP(ipAddress)) {
        _showErrorDialog('QR code must contain a local IP address');
        return;
      }

      final server = ExamServer(
        name: serverName,
        ipAddress: ipAddress,
        port: port,
      );

      // Show success dialog and prompt for auth code
      if (!mounted) return;
      _showSuccessDialog(server);
    } catch (e) {
      _showErrorDialog('Failed to parse QR code: $e');
    }
  }

  void _showSuccessDialog(ExamServer server) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'QR Code Scanned',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),

                  // Server info
                  Text(
                    'Server: ${server.name} via ${server.ipAddress}:${server.port}\nProceed to login?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _promptForAuthCode(server);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Scan Again button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _scanAgain();
                      },
                      child: const Text('Scan Again'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _promptForAuthCode(ExamServer server) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AuthCodeDialog(
            server: server,
            onSuccess: () {
              context.go('/login');
            },
          ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _scanAgain();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
    );
  }

  void _scanAgain() {
    setState(() {
      _hasScanned = false;
      _isScanning = false;
    });
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // Camera view
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Scanning frame overlay
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.orange, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Bottom instruction banner
          Positioned(
            left: 24,
            right: 24,
            bottom: 80,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_isScanning)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.orange,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.orange,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isScanning ? 'Scanning...' : 'Ready to Scan',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isScanning
                              ? 'Keep the QR code steady'
                              : 'Position the QR code within the frame',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
