import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/network/udp_discovery_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';
import 'package:smashrite/features/server_connection/presentation/widgets/auth_code_dialog.dart';

class AutoDiscoverScreen extends StatefulWidget {
  const AutoDiscoverScreen({super.key});

  @override
  State<AutoDiscoverScreen> createState() => _AutoDiscoverScreenState();
}

class _AutoDiscoverScreenState extends State<AutoDiscoverScreen> {
  final ServerConnectionService _connectionService = ServerConnectionService();
  UdpDiscoveryService? _discoveryService;
  List<ExamServer> _servers = [];
  bool _isSearching = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _discoverServers();
  }

  Future<void> _discoverServers() async {
    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      // Create new discovery service instance
      _discoveryService = UdpDiscoveryService(); // STORE INSTANCE

      final servers = await _discoveryService!.discoverServers();

      if (mounted) {
        setState(() {
          _servers =
              servers.map((discovered) {
                return ExamServer(
                  name: discovered.serverName,
                  ipAddress: discovered.serverIp,
                  port: discovered.port,
                  signalStrength: _calculateSignalStrength(
                    discovered.timestamp,
                  ),
                );
              }).toList();

          _isSearching = false;

          // Show helpful message if no servers found
          if (_servers.isEmpty) {
            _error =
                'No exam server found on your network.\n\n'
                'Make sure:\n'
                '• You\'re connected to the exam network\n'
                '• The exam server is running and broadcasting\n'
                'You can Try QR Code or Manual Entry instead.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Discovery failed: $e\n\nPlease use QR Code or Manual Entry.';
          _isSearching = false;
        });
      }
    } finally {
      _discoveryService = null; // CLEAR REFERENCE
    }
  }

  /// Calculate signal strength based on broadcast freshness
  int _calculateSignalStrength(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final age = now - timestamp;

    if (age < 10) return 95;
    if (age < 30) return 80;
    if (age < 60) return 65;
    return 50;
  }

  @override
  void dispose() {
    // Stop discovery if still running
    if (_discoveryService != null) {
      debugPrint('🛑 Stopping discovery - screen disposed');
      _discoveryService!.stop();
      _discoveryService = null;
    }
    super.dispose();
  }

  void _selectServer(ExamServer server) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Auto-Discover Exam Server',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        titleTextStyle: Theme.of(context).textTheme.bodyLarge,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _isSearching
                      ? _buildSearchingView()
                      : _error != null
                      ? _buildErrorView()
                      : _servers.isEmpty
                      ? _buildEmptyView()
                      : _buildServerList(),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildSearchingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Searching for exam servers...',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we scan your network',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.warning),
            const SizedBox(height: 24),
            Text(
              'Discovery Failed',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _discoverServers,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 24),
            Text(
              'No Servers Found',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure you\'re connected to the exam WiFi network',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _discoverServers,
              icon: const Icon(Icons.refresh),
              label: const Text('Search Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Available Servers',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Select a server to connect.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 24),

          // Server cards
          ..._servers.map(
            (server) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ServerCard(
                server: server,
                onTap: () => _selectServer(server),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Refresh button
          Center(
            child: TextButton.icon(
              onPressed: _discoverServers,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  final ExamServer server;
  final VoidCallback onTap;

  const _ServerCard({required this.server, required this.onTap});

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
            // Server icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.dns_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Server info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.name,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${server.ipAddress}:${server.port}",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ],
              ),
            ),

            // Signal strength
            if (server.signalStrength != null) ...[
              const SizedBox(width: 12),
              Row(
                children: [
                  Icon(
                    Icons.signal_wifi_4_bar_rounded,
                    color: AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${server.signalStrength}%',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
