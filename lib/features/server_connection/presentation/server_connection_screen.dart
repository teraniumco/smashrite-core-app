import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/network/network_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';

class ServerConnectionScreen extends StatefulWidget {
  const ServerConnectionScreen({super.key});

  @override
  State<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends State<ServerConnectionScreen> {
  bool _isCheckingNetwork = true;
  String? _networkError;

  @override
  void initState() {
    super.initState();
    _validateNetwork();
  }

  Future<void> _validateNetwork() async {
    setState(() {
      _isCheckingNetwork = true;
      _networkError = null;
    });

    final error = await NetworkService.validateNetworkForExam();

    if (mounted) {
      setState(() {
        _isCheckingNetwork = false;
        _networkError = error;
      });
    }
  }

  void _onScanTap() {
    if (_isCheckingNetwork) return;

    if (_networkError != null) {
      _showNetworkErrorDialog();
      return;
    }

    context.push('/server-connection/qr-scanner');
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Network Issue'),
        content: Text(_networkError ?? 'Validation failed'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _validateNetwork();
            },
            child: const Text('Retry'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // 🔥 Full-width CTA anchored at bottom
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: _PrimaryPillButton(
          label: 'Scan QR Code',
          onTap: _onScanTap,
          disabled: _isCheckingNetwork,
          fullWidth: true, // 👈 NEW
        ),
      ),

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           
            // 🔥 FULL-WIDTH SECTION
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                child: Column(
                  children: [
                    Text(
                      'Connect to Exam Server',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 25,
                          ),
                    ),

                    const Spacer(),


                    // QR VISUAL
                    const _QRPreview(),

                    const SizedBox(height: 32),

                    // STATUS
                    _buildStatus(),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }




  Widget _buildStatus() {
    if (_isCheckingNetwork) {
      return const CircularProgressIndicator();
    }

    final isError = _networkError != null;

    return Text(
      isError ? 'Network not ready' : 'Ready to scan',
      style: TextStyle(
        color: isError ? AppColors.error : AppColors.success,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

  class _QRPreview extends StatelessWidget {
    const _QRPreview();

    @override
    Widget build(BuildContext context) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color.fromARGB(255, 105, 108, 112)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2_rounded,
              size: 200, // slightly bigger = more premium
              color: AppColors.primary,
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Scan the QR code on your exam access slip provided by your exam administrator',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      );
    }
  }

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool disabled;
  final bool fullWidth;

  const _PrimaryPillButton({
    required this.label,
    required this.onTap,
    required this.disabled,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disabled ? 0.5 : 1,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16), 
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize:
                fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}