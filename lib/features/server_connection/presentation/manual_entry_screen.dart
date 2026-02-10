import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart' as package_info;
import 'package:smashrite/core/network/network_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';
import 'package:smashrite/core/services/version_check_service.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController(text: '');
  final _portController = TextEditingController(text: '');
  final _authCodeController = TextEditingController();
  final ServerConnectionService _connectionService = ServerConnectionService();

  bool _isConnecting = false;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _authCodeController.dispose();
    super.dispose();
  }


  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate IP is local
    final ip = _ipController.text.trim();
    if (!NetworkService.isLocalIP(ip)) {
      _showError('Please enter a valid local IP address (e.g., 192.168.x.x)');
      return;
    }

    setState(() => _isConnecting = true);

    try {
      final server = ExamServer(
        name: 'Smashrite Unknown Server',
        ipAddress: ip,
        port: int.parse(_portController.text.trim()),
        authCode: _authCodeController.text.trim(),
      );

      // Test connection
      final result = await _connectionService.testConnection(server);

      if (!mounted) return;

      if (result['success'] == true) {
        // Update server with branding data from backend
        final updatedServer = server.copyWith(
          name: result['server_name'] ?? server.name,
          institutionName: result['institution_name'],
          institutionLogoUrl: result['institution_logo_url'],
          requiredAppVersion: result['required_app_version'],
        );

        // Save server details
        await _connectionService.saveServerDetails(updatedServer);
        
        if (!mounted) return;
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Connected successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Check if version update is required
        final requiredVersion = result['required_app_version'] ?? '1.0.0';
        final needsUpdate = await VersionCheckService.shouldShowVersionCheck(
          requiredVersion,
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        
        if (needsUpdate) {
          context.go('/app-version-check', extra: requiredVersion);
        } else {
          context.go('/login');
        }
      } else {
        _showError(result['message'] ?? 'Connection failed. Please check your details.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 120,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Connect to Server'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        'Enter Server Details',
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Provide the IP address and port of the Smashrite exam server',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Form Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // IP Address
                            Text(
                              'Server IP Address',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _ipController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '192.168.1.100',
                                prefixIcon: Icon(
                                  Icons.settings_ethernet,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter server IP address';
                                }
                                if (!NetworkService.isLocalIP(value)) {
                                  return 'Please enter a valid local IP';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Format: xxx.xxx.xxx.xxx (e.g., 192.168.1.100)',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textPrimary),
                            ),

                            const SizedBox(height: 20),

                            // Port Number
                            Text(
                              'Port Number',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _portController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                hintText: '8000',
                                prefixIcon: Icon(
                                  Icons.lan,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter port number';
                                }
                                final port = int.tryParse(value);
                                if (port == null || port < 1 || port > 65535) {
                                  return 'Please enter a valid port (1-65535)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Default: 8000 (ask your administrator if different)',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textPrimary),
                            ),

                            const SizedBox(height: 20),

                            // Auth Code
                            Text(
                              'Server Auth Code',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _authCodeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                hintText: '123456',
                                prefixIcon: Icon(
                                  Icons.vpn_key_rounded,
                                  color: AppColors.textSecondary,
                                ),
                                counterText: '',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter auth code';
                                }
                                if (value.length != 6) {
                                  return 'Auth code must be 6 digits';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '6-digit code provided by your exam administrator',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Help Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.info.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.info,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Need help?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.info,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ask your exam administrator for the server IP address, port number, and auth code. You can also use the Auto-Discover option if the server is on the same network.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Test Connection button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isConnecting ? null : _testConnection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          child:
                              _isConnecting
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
                                  : const Text(
                                    'Start Connection',
                                      style: TextStyle(
                                        fontSize: 20,
                                      ),
                                    ),
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
