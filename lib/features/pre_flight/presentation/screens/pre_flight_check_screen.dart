import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/features/pre_flight/data/models/pre_flight_models.dart';
import 'package:smashrite/features/pre_flight/data/services/pre_flight_check_service.dart';
import 'package:smashrite/core/services/version_check_service.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';

class PreFlightCheckScreen extends StatefulWidget {
  const PreFlightCheckScreen({super.key});

  @override
  State<PreFlightCheckScreen> createState() => _PreFlightCheckScreenState();
}

class _PreFlightCheckScreenState extends State<PreFlightCheckScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  PreFlightResult? _result;
  bool _isChecking = true;
  String _currentCheckName = 'Initializing...';
  
  // Track individual check progress
  final Map<CheckType, CheckResult> _checkProgress = {};
  CheckType? _currentCheck;
  int _completedChecks = 0;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for icons
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    
    // Rotation animation for loading
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() {
      _isChecking = true;
      _result = null;
      _checkProgress.clear();
      _completedChecks = 0;
    });

    final result = await PreFlightCheckService.runAllChecks(
      onProgress: (type, status, message) {
        if (mounted) {
          setState(() {
            _currentCheck = type;
            _currentCheckName = type.name;
            _checkProgress[type] = CheckResult(
              type: type,
              status: status,
              message: message,
            );
            
            // Count completed checks
            if (status != CheckStatus.checking && status != CheckStatus.pending) {
              _completedChecks = _checkProgress.values
                  .where((c) => c.status != CheckStatus.checking && 
                               c.status != CheckStatus.pending)
                  .length;
            }
          });
        }
        debugPrint('📊 ${type.name}: $message');
      },
    );

    if (mounted) {
      setState(() {
        _result = result;
        _isChecking = false;
      });

      // Auto-navigate if all passed
      if (result.canProceed && result.failures.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _navigateToNextScreen();
        }
      }
    }
  }

  void _navigateToNextScreen() {
    final isFirstLaunch = StorageService.get<bool>(
      AppConstants.isFirstLaunch,
      defaultValue: true,
    );

    final hasConnectedToServer = StorageService.get<bool>(
      AppConstants.hasConnectedToServer,
      defaultValue: false,
    );

    final accessToken = StorageService.get<String>(AppConstants.accessToken);
    final isAuthenticated = accessToken != null && accessToken.isNotEmpty;

    if (isFirstLaunch == true || !hasConnectedToServer!) {
      context.go('/onboarding');
    } else if (!isAuthenticated) {
      context.go('/login');
    } else {
      context.go('/dashboard');
    }
  }


  Future<void> _handleCheckAction(CheckResult check) async {
    if (check.action == null) return;

    // Special handling for app version check
    if (check.type == CheckType.appVersion) {
      if (check.status == CheckStatus.warning || check.status == CheckStatus.failed) {
        await _navigateToVersionCheck();
      }
      return;
    }

    // For all other actions, just call the onTap
    check.action!.onTap!();
  }

  Future<void> _navigateToVersionCheck() async {
    try {
      final connectionService = ServerConnectionService();
      final savedServer = await connectionService.getSavedServer();
      
      if (savedServer?.requiredAppVersion != null) {
        if (!mounted) return;
        
        // Navigate and wait for result
        final result = await context.push<bool>(
          '/app-version-check',
          extra: savedServer!.requiredAppVersion,
        );
        
        // If user completed the update or skipped, re-run checks
        if (result == true && mounted) {
          _runChecks();
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Version information not available'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }


  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking || _result == null) {
      return _buildCheckingScreen();
    }

    if (_result!.canProceed && _result!.failures.isEmpty) {
      return _buildSuccessScreen();
    }

    return _buildResultsScreen();
  }

  // ============================================================================
  // CHECKING SCREEN - Modern split layout
  // ============================================================================
  Widget _buildCheckingScreen() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final totalChecks = CheckType.values.length;
    final progress = _completedChecks / totalChecks;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.05),
              Colors.white,
              AppColors.primary.withOpacity(0.03),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                // Desktop/Tablet landscape - Side by side layout
                return Row(
                  children: [
                    // Left side - Visual
                    Expanded(
                      flex: 5,
                      child: _buildCheckingVisual(isTablet: true),
                    ),
                    // Right side - Checks list
                    Expanded(
                      flex: 5,
                      child: _buildChecksList(),
                    ),
                  ],
                );
              } else {
                // Mobile/Portrait - Stacked layout
                return Column(
                  children: [
                    // Top - Visual (smaller on mobile)
                    SizedBox(
                      height: screenHeight * 0.4,
                      child: _buildCheckingVisual(isTablet: isTablet),
                    ),
                    // Bottom - Checks list
                    Expanded(
                      child: _buildChecksList(),
                    ),
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCheckingVisual({required bool isTablet}) {
    final totalChecks = CheckType.values.length;
    final progress = _completedChecks / totalChecks;
    
    return Container(
      padding: EdgeInsets.all(isTablet ? 48 : 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Dynamic spacing based on available height
          final availableHeight = constraints.maxHeight;
          final spacing = availableHeight > 400 ? 24.0 : 12.0;
          final iconSize = isTablet ? 160.0 : (availableHeight > 350 ? 120.0 : 80.0);
          final titleSize = isTablet ? 32.0 : (availableHeight > 350 ? 24.0 : 20.0);
          
          return SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated security shield
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating ring
                    AnimatedBuilder(
                      animation: _rotateController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotateController.value * 2 * 3.14159,
                          child: Container(
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: CustomPaint(
                              painter: _CircularProgressPainter(
                                progress: progress,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    // Pulsing center icon
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final innerSize = iconSize * 0.625;
                        return Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.15),
                          child: Container(
                            width: innerSize,
                            height: innerSize,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: _pulseController.value * 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.security_rounded,
                              size: innerSize * 0.5,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                SizedBox(height: spacing),
                
                // Title
                Text(
                  'Device Check',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                
                SizedBox(height: spacing * 0.5),
                
                // Subtitle
                Text(
                  'Verifying device security and readiness',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: spacing),
                
                // Progress indicator
                Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Column(
                    children: [
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Progress text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_completedChecks of $totalChecks checks',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: spacing * 0.8),
                
                // Current check name
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(_currentCheckName),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _currentCheckName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChecksList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Running Checks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This will only take a moment',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Checks list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: CheckType.values.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final checkType = CheckType.values[index];
                final checkResult = _checkProgress[checkType];
                final isCurrent = _currentCheck == checkType;
                
                return _buildCompactCheckItem(
                  checkType: checkType,
                  result: checkResult,
                  isCurrent: isCurrent,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCheckItem({
    required CheckType checkType,
    CheckResult? result,
    required bool isCurrent,
  }) {
    final status = result?.status ?? CheckStatus.pending;
    
    Color iconColor;
    IconData statusIcon;
    
    switch (status) {
      case CheckStatus.passed:
        iconColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case CheckStatus.warning:
        iconColor = Colors.orange;
        statusIcon = Icons.warning_rounded;
        break;
      case CheckStatus.failed:
        iconColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case CheckStatus.checking:
        iconColor = AppColors.primary;
        statusIcon = Icons.sync;
        break;
      case CheckStatus.pending:
      default:
        iconColor = Colors.grey.shade400;
        statusIcon = Icons.radio_button_unchecked;
    }
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent 
            ? AppColors.primary.withOpacity(0.08)
            : status == CheckStatus.pending
                ? Colors.grey.shade50
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent 
              ? AppColors.primary.withOpacity(0.3)
              : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          // Check icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              result?.icon ?? Icons.help_outline,
              color: iconColor,
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Check name
          Expanded(
            child: Text(
              checkType.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                color: status == CheckStatus.pending 
                    ? AppColors.textSecondary 
                    : AppColors.textPrimary,
              ),
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Status indicator
          if (status == CheckStatus.checking)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            )
          else
            Icon(
              statusIcon,
              color: iconColor,
              size: 22,
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // SUCCESS SCREEN - Modern celebration
  // ============================================================================
  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Success animation
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.green.shade100,
                                Colors.green.shade50,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.check_circle_rounded,
                            size: 90,
                            color: Colors.green,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    'All Checks Passed!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Your device is ready for exams',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Summary cards
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSuccessStat(
                        icon: Icons.security_rounded,
                        label: 'Security',
                        value: 'Verified',
                        color: Colors.green,
                      ),
                      _buildSuccessStat(
                        icon: Icons.wifi_rounded,
                        label: 'Network',
                        value: 'Connected',
                        color: Colors.blue,
                      ),
                      _buildSuccessStat(
                        icon: Icons.verified_user_rounded,
                        label: 'Status',
                        value: 'Ready',
                        color: AppColors.primary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Auto-continuing
                  Column(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.green.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Continuing to next steps...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // RESULTS SCREEN - Modern grid layout
  // ============================================================================
  Widget _buildResultsScreen() {
    final failures = _result!.failures;
    final warnings = _result!.warnings;
    final passed = _result!.passed;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 32 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: failures.isNotEmpty
                      ? [Colors.red.shade400, Colors.red.shade600]
                      : [Colors.orange.shade400, Colors.orange.shade600],
                ),
              ),
              child: Column(
                children: [
                  // Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      failures.isNotEmpty 
                          ? Icons.error_outline_rounded 
                          : Icons.warning_amber_rounded,
                      size: 48,
                      color: failures.isNotEmpty ? Colors.red : Colors.orange,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    failures.isNotEmpty 
                        ? 'Action Required'
                        : 'Review Warnings',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    failures.isNotEmpty
                        ? '${failures.length} ${failures.length == 1 ? 'issue' : 'issues'} must be resolved before continuing'
                        : '${warnings.length} ${warnings.length == 1 ? 'warning' : 'warnings'} detected but you can proceed',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeaderStat(
                        icon: Icons.error,
                        count: failures.length,
                        label: 'Critical',
                      ),
                      const SizedBox(width: 20),
                      _buildHeaderStat(
                        icon: Icons.warning,
                        count: warnings.length,
                        label: 'Warnings',
                      ),
                      const SizedBox(width: 20),
                      _buildHeaderStat(
                        icon: Icons.check_circle,
                        count: passed.length,
                        label: 'Passed',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Results grid
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(isTablet ? 32 : 16),
                children: [
                  // Failures
                  if (failures.isNotEmpty) ...[
                    _buildModernSectionHeader('Critical Issues', Colors.red, failures.length),
                    const SizedBox(height: 16),
                    _buildChecksGrid(failures, isTablet),
                    const SizedBox(height: 24),
                  ],

                  // Warnings
                  if (warnings.isNotEmpty) ...[
                    _buildModernSectionHeader('Warnings', Colors.orange, warnings.length),
                    const SizedBox(height: 16),
                    _buildChecksGrid(warnings, isTablet),
                    const SizedBox(height: 24),
                  ],

                  // Passed
                  if (passed.isNotEmpty) ...[
                    _buildModernSectionHeader('Passed Checks', Colors.green, passed.length),
                    const SizedBox(height: 16),
                    _buildChecksGrid(passed, isTablet),
                  ],
                  
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // Bottom action bar
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _runChecks,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text('Retry'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: AppColors.primary, 
                            width: 2,
                          ),
                          foregroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (_result!.canProceed) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _navigateToNextScreen,
                          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                          label: const Text('Continue'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: AppColors.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildModernSectionHeader(String title, Color color, int count) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            title.contains('Critical') 
                ? Icons.error 
                : title.contains('Warning')
                    ? Icons.warning
                    : Icons.check_circle,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChecksGrid(List<CheckResult> checks, bool isTablet) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns: 1 for mobile, 2 for tablet
        final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
        final spacing = isTablet ? 16.0 : 12.0;
        
        // Better aspect ratio for more compact cards
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: crossAxisCount == 2 ? 1.4 : 2.8, // More compact
          ),
          itemCount: checks.length,
          itemBuilder: (context, index) {
            return _buildModernCheckCard(checks[index]);
          },
        );
      },
    );
  }

  Widget _buildModernCheckCard(CheckResult check) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: check.statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: check.statusColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - More compact
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: check.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    check.icon,
                    size: 18,
                    color: check.statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    check.type.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  check.statusIcon,
                  size: 18,
                  color: check.statusColor,
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Message
            Text(
              check.message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.3,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Details - Compact
            if (check.details != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: check.statusColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: check.statusColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        check.details!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action button - Only if action exists
            if (check.action != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _handleCheckAction(check), // CHANGED THIS LINE
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    foregroundColor: check.statusColor,
                    side: BorderSide(color: check.statusColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(
                    check.action!.label,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CUSTOM PAINTER for circular progress
// ============================================================================
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2; // Start from top
    final sweepAngle = 2 * 3.14159 * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}