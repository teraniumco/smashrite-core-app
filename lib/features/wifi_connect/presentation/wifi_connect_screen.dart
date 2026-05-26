import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:smashrite/core/network/network_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';

// ── Network status model ──────────────────────────────────────────────────────

class _NetworkStatus {
  final bool wifiConnected;
  final bool mobileDataOff;
  final bool internetBlocked;

  const _NetworkStatus({
    required this.wifiConnected,
    required this.mobileDataOff,
    required this.internetBlocked,
  });

  bool get allClear => wifiConnected && mobileDataOff && internetBlocked;

  /// Returns the single most important instruction to show as headline.
  String get primaryMessage {
    if (!wifiConnected) return 'Connect to the exam WiFi hotspot';
    if (!mobileDataOff) return 'Turn off mobile data';
    if (!internetBlocked) return 'No internet should be accessible';
    return 'All clear — continuing...';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WifiConnectScreen extends StatefulWidget {
  const WifiConnectScreen({super.key});

  @override
  State<WifiConnectScreen> createState() => _WifiConnectScreenState();
}

class _WifiConnectScreenState extends State<WifiConnectScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _settingsChannel = MethodChannel('com.smashrite.core/settings');
  static const _deepBlue = Color(0xFF0F2B6D);
  static const _orange = AppColors.error;

  _NetworkStatus? _status;
  bool _isChecking = false;
  bool _proceedingToNext = false;
  Timer? _pollTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _checkNetwork();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && !_proceedingToNext) _checkNetwork();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Student returns from WiFi / mobile data settings
    if (state == AppLifecycleState.resumed && !_proceedingToNext) {
      _checkNetwork();
    }
  }

  Future<void> _checkNetwork() async {
    if (_isChecking || !mounted) return;
    setState(() => _isChecking = true);

    try {
      // Run the three checks concurrently for speed
      final results = await Future.wait([
        NetworkService.isConnectedToWiFi(),
        _isMobileDataOff(),
        _isInternetBlocked(),
      ]);

      if (!mounted) return;

      final status = _NetworkStatus(
        wifiConnected: results[0],
        mobileDataOff: results[1],
        internetBlocked: results[2],
      );

      setState(() {
        _status = status;
        _isChecking = false;
      });

      if (status.allClear && !_proceedingToNext) {
        setState(() => _proceedingToNext = true);
        _pollTimer?.cancel();
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) context.go('/pre-flight-check');
      }
    } catch (_) {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  /// Mobile data is "off" when ConnectivityResult.mobile is absent.
  Future<bool> _isMobileDataOff() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return !results.contains(ConnectivityResult.mobile);
    } catch (_) {
      return true; // assume off if check fails
    }
  }

  /// Internet is "blocked" when socket check returns false.
  Future<bool> _isInternetBlocked() async {
    try {
      final hasInternet = await NetworkService.hasInternetAccessViaSocket();
      return !hasInternet;
    } catch (_) {
      return true; // assume blocked if check fails
    }
  }

  Future<void> _openWifiSettings() async {
    try {
      await _settingsChannel.invokeMethod('openWiFiSettings');
    } catch (e) {
      debugPrint('Could not open WiFi settings: $e');
    }
  }

  Future<void> _openMobileDataSettings() async {
    try {
      // Try dedicated mobile data settings first, fall back to general settings
      await _settingsChannel.invokeMethod('openMobileDataSettings');
    } catch (_) {
      try {
        await _settingsChannel.invokeMethod('openWiFiSettings');
      } catch (e) {
        debugPrint('Could not open settings: $e');
      }
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final allClear = status?.allClear ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Top icon ───────────────────────────────────────────
              _buildTopIcon(allClear),

              const SizedBox(height: 36),

              // ── Title ──────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  key: ValueKey(status?.primaryMessage),
                  allClear
                      ? 'All set — continuing...'
                      : 'Check your network',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: allClear ? Colors.green.shade700 : _deepBlue,
                    height: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Text(
                allClear
                    ? 'Your device meets all network requirements.'
                    : 'Fix the issues below to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // ── Checklist ──────────────────────────────────────────
              if (status == null)
                _buildChecklistSkeleton()
              else
                _buildChecklist(status),

              const Spacer(flex: 3),

              // ── CTA buttons ────────────────────────────────────────
              if (!allClear) ...[
                if (status != null && !status.wifiConnected)
                  _primaryButton(
                    label: 'Open WiFi Settings',
                    icon: Icons.wifi_rounded,
                    onTap: _openWifiSettings,
                  ),

                if (status != null &&
                    status.wifiConnected &&
                    !status.mobileDataOff)
                  _primaryButton(
                    label: 'Open Mobile Data Settings',
                    icon: Icons.signal_cellular_alt_rounded,
                    onTap: _openMobileDataSettings,
                  ),

                if (status != null &&
                    status.wifiConnected &&
                    status.mobileDataOff &&
                    !status.internetBlocked)
                  _primaryButton(
                    label: 'Open WiFi Settings',
                    icon: Icons.wifi_rounded,
                    onTap: _openWifiSettings,
                  ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isChecking ? null : _checkNetwork,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: _deepBlue, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: _deepBlue,
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(_deepBlue),
                            ),
                          )
                        : const Text(
                            "I've Fixed It — Check Again",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildTopIcon(bool allClear) {
    if (allClear) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.elasticOut,
        builder: (context, value, _) => Transform.scale(
          scale: value,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: Colors.green.shade600,
            ),
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) => Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFFE3EDF9),
            const Color(0xFFCCDEF5),
            _pulseController.value,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.wifi_off_rounded,
          size: 62,
          color: Color.lerp(
            _deepBlue.withOpacity(0.4),
            _deepBlue,
            _pulseController.value,
          ),
        ),
      ),
    );
  }

  Widget _buildChecklist(_NetworkStatus status) {
    return Column(
      children: [
        _ChecklistItem(
          icon: Icons.wifi_rounded,
          label: 'Connected to a WiFi',
          sublabel: status.wifiConnected
              ? 'WiFi connection detected'
              : 'Go to Settings and connect to the provided exam\'s hotspot',
          passed: status.wifiConnected,
          isChecking: _isChecking,
        ),
        const SizedBox(height: 10),
        _ChecklistItem(
          icon: Icons.signal_cellular_off_rounded,
          label: 'Mobile data is off',
          sublabel: status.mobileDataOff
              ? 'No mobile data activity detected'
              : 'Open Settings and turn off mobile data / cellular data',
          passed: status.mobileDataOff,
          isChecking: _isChecking,
        ),
        const SizedBox(height: 10),
        _ChecklistItem(
          icon: Icons.public_off_rounded,
          label: 'No external internet',
          sublabel: status.internetBlocked
              ? 'Internet access is blocked'
              : 'Internet is accessible — connect only to the local exam hotspot',
          passed: status.internetBlocked,
          isChecking: _isChecking,
        ),
      ],
    );
  }

  Widget _buildChecklistSkeleton() {
    return Column(
      children: List.generate(
        3,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _deepBlue,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}

// ── Checklist item ────────────────────────────────────────────────────────────

class _ChecklistItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final bool passed;
  final bool isChecking;

  const _ChecklistItem({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.passed,
    required this.isChecking,
  });

  @override
  Widget build(BuildContext context) {
    const deepBlue = Color(0xFF0F2B6D);

    final borderColor = passed
        ? Colors.green.shade200
        : Colors.orange.shade200;
    final bgColor = passed
        ? Colors.green.shade50
        : Colors.orange.shade50;
    final iconBg = passed
        ? Colors.green.shade100
        : Colors.orange.shade100;
    final iconColor = passed
        ? Colors.green.shade700
        : Colors.orange.shade700;
    final labelColor = passed ? Colors.green.shade800 : deepBlue;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon bubble
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),

          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sublabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: passed
                        ? Colors.green.shade600
                        : Colors.orange.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Status indicator
          if (isChecking)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(
                passed
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 22,
                color: iconColor,
              ),
            ),
        ],
      ),
    );
  }
}