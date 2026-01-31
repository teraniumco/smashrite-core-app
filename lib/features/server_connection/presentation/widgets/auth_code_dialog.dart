import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';

class AuthCodeDialog extends StatefulWidget {
  final ExamServer server;
  final VoidCallback onSuccess;

  const AuthCodeDialog({
    super.key,
    required this.server,
    required this.onSuccess,
  });

  @override
  State<AuthCodeDialog> createState() => _AuthCodeDialogState();
}

class _AuthCodeDialogState extends State<AuthCodeDialog> {
  final _authCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ServerConnectionService _connectionService = ServerConnectionService();
  bool _isConnecting = false;
  String? _error;

  @override
  void dispose() {
    _authCodeController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndConnect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      // Create server with auth code
      final serverWithAuth = widget.server.copyWith(
        authCode: _authCodeController.text.trim(),
      );

      // Test connection
      final result = await _connectionService.testConnection(serverWithAuth);

      if (!mounted) return;

      if (result['success'] == true) {
        // Update server with branding data from backend
        final updatedServer = serverWithAuth.copyWith(
          name: result['server_name'] ?? serverWithAuth.name,
          institutionName: result['institution_name'],
          institutionLogoUrl: result['institution_logo_url'],
          primaryColor: result['primary_color'],
          secondaryColor: result['secondary_color'],
        );

        // Save server details
        await _connectionService.saveServerDetails(updatedServer);

        // Close dialog and navigate to login
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        setState(() {
          _error = result['message'] ?? 'Connection failed. Please try again.';
          _isConnecting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Connection error: $e';
        _isConnecting = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.vpn_key_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'Enter Auth Code',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),

                // Server info
                Text(
                  'Server: ${widget.server.name} via ${widget.server.ipAddress}:${widget.server.port}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 8),

                Text(
                  'Enter the 6-digit authentication code',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 24),

                // Auth code input
                TextFormField(
                  controller: _authCodeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    errorText: _error,
                    errorMaxLines: 2,
                    filled: true,
                    fillColor: AppColors.surfaceLight,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.error,
                        width: 2,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.error,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter auth code';
                    }
                    if (value.length != 6) {
                      return 'Code must be 6 digits';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (_error != null) {
                      setState(() => _error = null);
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Connect button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : _verifyAndConnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                    ),
                    child: _isConnecting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          )
                        : const Text('Connect'),
                  ),
                ),
                const SizedBox(height: 8),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isConnecting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}