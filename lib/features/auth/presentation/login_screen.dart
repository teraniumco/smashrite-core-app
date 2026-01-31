import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/network/network_service.dart';
import 'package:smashrite/core/services/security_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/auth/data/services/auth_service.dart';
import 'package:smashrite/features/auth/presentation/widgets/server_info_modal.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';
import 'package:smashrite/shared/utils/snackbar_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  final _accessCodeController = TextEditingController();
  final AuthService _authService = AuthService();
  final ServerConnectionService _serverService = ServerConnectionService();

  bool _isLoading = false;
  ExamServer? _currentServer;

  // Network validation states
  bool _isCheckingNetwork = true;
  String? _networkError;

  @override
  void initState() {
    super.initState();
    _loadServerInfo();
    _validateNetwork();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _accessCodeController.dispose();
    super.dispose();
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

  Future<void> _loadServerInfo() async {
    final server = await _serverService.getSavedServer();
    if (mounted) {
      setState(() {
        _currentServer = server;
      });

      if (server != null) {
        AuthService.initialize(
          server.url,
        );
      }
    }
  }

  void _showServerInfo() {
    if (_currentServer == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ServerInfoModal(
        server: _currentServer!,
        onDisconnect: _handleDisconnect,
      ),
    );
  }

  Future<void> _handleDisconnect() async {
    // Close modal
    Navigator.pop(context);

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect from Server?'),
        content: const Text(
          'You will need to reconnect to access exams. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Clear server details
      await _serverService.clearServerDetails();

      if (!mounted) return;

      // Navigate back to server connection
      context.go('/server-connection');
    }
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Network Error'),
        content: Text(
          _networkError ?? 'Network validation failed',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _validateNetwork();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Handle device verification errors
  void _handleDeviceVerificationError(Map<String, dynamic> result) {
    final reason = result['reason'];
    final requiresAction = result['requires_action'] ?? false;

    if (reason == 'active_session_different_device') {
      // Show dialog with option to force logout other device
      _showActiveSessionDialog(result);
    } else if (reason == 'device_consistency_failed') {
      _showDeviceConsistencyDialog(result);
    } else if (reason == 'device_limit_reached') {
      _showDeviceLimitDialog(result);
    } else {
      // Generic error
      showTopSnackBar(
        context,
        message: result['message'] ?? 'Device verification failed',
        backgroundColor: AppColors.error,
      );
    }
  }

  /// Show dialog for active session on different device
  void _showActiveSessionDialog(Map<String, dynamic> result) {
    final activeSession = result['active_session'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.warning),
            const SizedBox(width: 12),
            const Expanded(child: Text('Active Session Found')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result['message'] ?? 'You have an active session on another device',
              style: const TextStyle(fontSize: 15),
            ),
            if (activeSession != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.textSecondary.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Test', activeSession['test_title'] ?? 'Unknown'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Device', activeSession['device_model'] ?? 'Unknown'),
                    const SizedBox(height: 8),
                    _buildInfoRow('Started', activeSession['started_at'] ?? 'Unknown'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'You can force logout from that device to continue here.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _forceLogoutOtherDevices();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
            ),
            child: const Text('Force Logout & Continue'),
          ),
        ],
      ),
    );
  }

  /// Show dialog for device consistency issues
  void _showDeviceConsistencyDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.security, color: AppColors.error),
            const SizedBox(width: 12),
            const Text('Device Verification Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result['message'] ?? 'Device hardware verification failed',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Text(
              'Your device hardware characteristics have changed. Please contact support for assistance.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show dialog for device limit reached
  void _showDeviceLimitDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.devices, color: AppColors.warning),
            const SizedBox(width: 12),
            const Text('Device Limit Reached'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              result['message'] ?? 'Maximum device limit reached',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Text(
              'You can register up to 2 devices. Please contact your administrator to remove a device before registering this one.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Force logout from other devices
  Future<void> _forceLogoutOtherDevices() async {
    setState(() => _isLoading = true);

    try {
      final result = await AuthService.forceLogoutOtherDevices();

      if (!mounted) return;

      if (result['success'] == true) {
        showTopSnackBar(
          context,
          message: 'Logged out from ${result['sessions_ended']} other device(s)',
          backgroundColor: AppColors.success,
        );

        // Wait a moment then retry login
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          await _login();
        }
      } else {
        showTopSnackBar(
          context,
          message: result['message'] ?? 'Failed to logout other devices',
          backgroundColor: AppColors.error,
        );
      }
    } catch (e) {
      if (mounted) {
        showTopSnackBar(
          context,
          message: 'Failed to logout other devices',
          backgroundColor: AppColors.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _login() async {
    // Check network first
    if (_isCheckingNetwork) {
      showTopSnackBar(
        context,
        message: 'Please wait while we validate the network...',
        backgroundColor: AppColors.info,
      );
      return;
    }

    if (_networkError != null) {
      _showNetworkErrorDialog();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_currentServer == null) {
      showTopSnackBar(
        context,
        message: 'No server connected. Please connect to a server first.',
        backgroundColor: AppColors.error,
      );
      return;
    }

    // Verify SecurityService is initialized with device fingerprinting
    if (!SecurityService.isInitialized) {
      showTopSnackBar(
        context,
        message: 'Security service not initialized. Please restart the app.',
        backgroundColor: AppColors.error,
      );
      return;
    }

    if (SecurityService.installationId == null || 
        SecurityService.compositeFingerprint == null) {
      showTopSnackBar(
        context,
        message: 'Device fingerprinting not available. Please restart the app.',
        backgroundColor: AppColors.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Login with device fingerprinting data
      debugPrint('🔐 Attempting login with device verification...');
      
      final result = await AuthService.login(
        server: _currentServer!,
        studentId: _studentIdController.text.trim(),
        accessCode: _accessCodeController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        // Step 2: Configure security service with server
        await SecurityService.configureServer(_currentServer!);
        
        // Step 3: Extract student ID from response
        final responseData = result['data'] as Map<String, dynamic>;
        final student = responseData['student'] as Map<String, dynamic>;
        final studentId = student['id'] as int;
        
        // Step 4: Check device registration status from backend response
        final deviceRegistered = responseData['device_registered'] ?? false;
        final requiresRegistration = responseData['requires_registration'] ?? false;
        
        if (!deviceRegistered || requiresRegistration) {
          // Device not registered - register it now
          debugPrint('📱 Device not registered, registering now...');
          
          final registrationResult = await SecurityService.registerDevice(
            studentId: studentId,
          );
          
          if (registrationResult['success'] != true) {
            // Handle registration failure
            showTopSnackBar(
              context,
              message: registrationResult['message'] ?? 'Device registration failed',
              backgroundColor: AppColors.error,
            );
            setState(() => _isLoading = false);
            return;
          }
          
          // Show device registered successfully
          showTopSnackBar(
            context,
            message: 'Device registered successfully!',
            backgroundColor: AppColors.success,
          );
        } else {
          debugPrint('✅ Device already registered');
        }
        
        // Step 5: Show success message
        showTopSnackBar(
          context,
          message: result['message'] ?? 'Login successful!',
          backgroundColor: AppColors.success,
        );

        // Step 6: Navigate to dashboard
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        context.go('/dashboard');
        
      } else {
        // Login failed - check if it's a device verification issue
        final reason = result['reason'];
        final requiresAction = result['requires_action'] ?? false;

        if (requiresAction) {
          // Handle device verification errors with dialogs
          _handleDeviceVerificationError(result);
        } else {
          // Standard login error
          showTopSnackBar(
            context,
            message: result['message'] ?? 'Login failed. Please check your credentials.',
            backgroundColor: AppColors.error,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      if (!mounted) return;
      showTopSnackBar(
        context,
        message: 'An unexpected error occurred. Please try again.',
        backgroundColor: AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canLogin = !_isCheckingNetwork && _networkError == null && !_isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
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
                      const SizedBox(height: 20),

                      // Logo Section - Dual Logo Display
                      _buildDualLogoSection(),
                      const SizedBox(height: 50),

                      // Title and Server Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Sign In',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                          ),

                          // Server Status Button
                          if (_currentServer != null)
                            InkWell(
                              onTap: _showServerInfo,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.success.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.dns,
                                      color: AppColors.success,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _currentServer!.name,
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Enter your credentials to access the exam.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 24),

                      // Network Status Banner
                      if (_isCheckingNetwork)
                        _buildStatusBanner(
                          icon: Icons.wifi_find,
                          text: 'Checking network...',
                          color: AppColors.info,
                        )
                      else if (_networkError != null)
                        _buildStatusBanner(
                          icon: Icons.warning_rounded,
                          text: _networkError!,
                          color: AppColors.error,
                          action: TextButton(
                            onPressed: _validateNetwork,
                            child: const Text('Retry'),
                          ),
                        )
                      else
                        _buildStatusBanner(
                          icon: Icons.check_circle_rounded,
                          text: 'No Internet and device is ready!',
                          color: AppColors.success,
                        ),

                      const SizedBox(height: 24),

                      // Student ID
                      Text(
                        'Student ID',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _studentIdController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          hintText: 'Enter your ID number',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your student ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Access Code
                      Text(
                        'Access Code',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _accessCodeController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 14, // 12 digits + 2 hyphens
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Z0-9-]'),
                          ),
                          _AccessCodeFormatter(),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'XXXX-XXXX-XXXX',
                          prefixIcon: Icon(Icons.vpn_key_rounded),
                          counterText: '',
                          labelStyle: TextStyle(fontSize: 25),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter access code';
                          }
                          final cleanCode = value.replaceAll('-', '');
                          if (cleanCode.length != 12) {
                            return 'Access code must be 12 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canLogin ? _login : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.textPrimary,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Enter Exam Lobby',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: canLogin ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Help Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFFCD34D),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Need Help?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'If you encounter persistent issues, please contact your Digital Exam Administrator or Smashrite support using the information below.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textPrimary,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Phone: +234 902 682 9282',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Email: support@smashrite.com',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
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
          ],
        ),
      ),
    );
  }

  /// Build responsive dual logo section
  Widget _buildDualLogoSection() {
    // If no server or no institution logo, show only Smashrite logo
    if (_currentServer == null || _currentServer!.institutionLogoUrl == null) {
      return Center(
        child: Image.asset(
          'assets/images/smashrite-logo.png',
          height: 40,
          fit: BoxFit.contain,
        ),
      );
    }

    // Dual logo layout with responsive sizing
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Smashrite Logo
            Flexible(
              flex: 1,
              child: Image.asset(
                'assets/images/smashrite-logo.png',
                height: 40,
                fit: BoxFit.contain,
              ),
            ),

            // Vertical Divider
            Container(
              height: 70,
              width: 2,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.textSecondary.withOpacity(0.1),
                    AppColors.textSecondary.withOpacity(0.4),
                    AppColors.textSecondary.withOpacity(0.1),
                  ],
                ),
              ),
            ),

            // Institution Logo
            Flexible(
              flex: 1,
              child: _buildInstitutionLogo(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build institution logo with loading and error states
  Widget _buildInstitutionLogo() {
    return Image.network(
      _currentServer!.institutionLogoUrl!,
      height: 50,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        
        // Show loading indicator while image loads
        return SizedBox(
          height: 80,
          child: Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary.withOpacity(0.6),
                ),
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        // Show institution name or fallback icon on error
        return SizedBox(
          height: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance,
                size: 40,
                color: AppColors.textSecondary.withOpacity(0.4),
              ),
              if (_currentServer?.institutionName != null) ...[
                const SizedBox(height: 4),
                Text(
                  _currentServer!.institutionName!,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner({
    required IconData icon,
    required String text,
    required Color color,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}

/// Custom formatter for access code (XXXX-XXXX-XXXX)
class _AccessCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.toUpperCase().replaceAll('-', '');
    
    if (text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length && i < 12; i++) {
      if (i == 4 || i == 8) {
        buffer.write('-');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}