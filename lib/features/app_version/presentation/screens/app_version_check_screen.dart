import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/core/utils/app_store_utils.dart';
import 'package:smashrite/core/utils/version_utils.dart';
import 'package:url_launcher/url_launcher.dart';

class AppVersionCheckScreen extends StatefulWidget {
  final String requiredVersion;
  
  const AppVersionCheckScreen({
    super.key,
    required this.requiredVersion,
  });

  @override
  State<AppVersionCheckScreen> createState() => _AppVersionCheckScreenState();
}

class _AppVersionCheckScreenState extends State<AppVersionCheckScreen> {
  String _currentVersion = '';
  int _skipCount = 0;
  bool _canSkip = true;
  bool _isLoading = true;

  // Platform-specific store info
  String get _storeName => Platform.isIOS ? 'App Store' : 'Play Store';
  String get _storeButtonText => Platform.isIOS ? 'Update from App Store' : 'Update from Play Store';

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final lastSkipped = StorageService.get<String>(
        AppConstants.lastSkippedVersion,
      );
      
      // Reset skip count if this is a different version
      if (lastSkipped != widget.requiredVersion) {
        await StorageService.save(AppConstants.versionSkipCount, 0);
        await StorageService.save(
          AppConstants.lastSkippedVersion,
          widget.requiredVersion,
        );
      }
      
      final skipCount = StorageService.get<int>(
        AppConstants.versionSkipCount,
      ) ?? 0;
      
      setState(() {
        _currentVersion = packageInfo.version;
        _skipCount = skipCount;
        _canSkip = skipCount < AppConstants.maxVersionSkips;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading version info: $e');
      setState(() => _isLoading = false);
    }
  }

  // Update _updateApp method in app_version_check_screen.dart

Future<void> _updateApp() async {
  try {
    // Check if iOS App Store ID is configured
    if (Platform.isIOS && !AppStoreUtils.isAppStoreIdConfigured()) {
      _showError('App Store ID not configured. Please contact support.');
      return;
    }
    
    final storeUrl = await AppStoreUtils.getStoreUrl(useNativeApp: false);
    final uri = Uri.parse(storeUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      if (!mounted) return;
      _showError('Could not open ${AppStoreUtils.storeName}');
    }
  } catch (e) {
    if (!mounted) return;
    _showError('Error opening ${AppStoreUtils.storeName}: $e');
  }
}

  Future<void> _skipUpdate() async {
    if (!_canSkip) return;
    
    final newSkipCount = _skipCount + 1;
    await StorageService.save(AppConstants.versionSkipCount, newSkipCount);
    
    if (!mounted) return;
    Navigator.pop(context, true); // Return true to indicate action taken
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final skipsRemaining = AppConstants.maxVersionSkips - _skipCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  size: 64,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Update Required',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                'A newer version of Smashrite Core is required to connect to this exam server',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Version info card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildVersionRow(
                      'Current Version',
                      _currentVersion,
                      AppColors.error,
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 16),
                    Divider(color: AppColors.border),
                    const SizedBox(height: 16),
                    _buildVersionRow(
                      'Required Version',
                      widget.requiredVersion,
                      AppColors.success,
                      Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Update button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _updateApp,
                  icon: Icon(
                    Platform.isIOS 
                        ? Icons.apple 
                        : Icons.shop_rounded,
                  ),
                  label: Text(_storeButtonText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              // Skip button (if available)
              if (_canSkip) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _skipUpdate,
                    child: Text(
                      'Skip ($skipsRemaining remaining)',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You can skip this update $skipsRemaining more time${skipsRemaining != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.block_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Update required to continue.\nNo skips remaining.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              
              // Platform info
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
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppStoreUtils.getUpdateHelpText(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionRow(
    String label,
    String version,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'v$version',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}