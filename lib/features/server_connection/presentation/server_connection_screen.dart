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

  void _navigateToMethod(String route) {
    if (_isCheckingNetwork) return;
    
    if (_networkError != null) {
      _showNetworkErrorDialog();
      return;
    }
    context.push(route);
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
              fontSize: 17 
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 45, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      'Connect to Server',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Choose how you want to connect to the exam network.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 18
                          ),
                    ),
                    const SizedBox(height: 32),

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

                    // Connection Methods
                    

                    _ConnectionMethodCard(
                      icon: Icons.wifi_find_rounded,
                      title: 'Auto-Discover',
                      description: 'Search for exam servers on the local network',
                      isRecommended: true,
                      onTap: () => _navigateToMethod('/server-connection/auto-discover'),
                    ),
                    const SizedBox(height: 16),

                    _ConnectionMethodCard(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Scan QR Code',
                      description: 'Scan the QR code provided by the Digital Exam administrator',
                      onTap: () => _navigateToMethod('/server-connection/qr-scanner'),
                    ),
                    const SizedBox(height: 16),

                    _ConnectionMethodCard(
                      icon: Icons.keyboard_outlined,
                      title: 'Manual Entry',
                      description: 'Enter exam server connection details',
                      onTap: () => _navigateToMethod('/server-connection/manual-entry'),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
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

class _ConnectionMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isRecommended;
  final VoidCallback onTap;

  const _ConnectionMethodCard({
    required this.icon,
    required this.title,
    required this.description,
    this.isRecommended = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 17,
                            ),
                      ),
                      if (isRecommended) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Arrow
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
