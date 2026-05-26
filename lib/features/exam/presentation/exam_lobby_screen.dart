import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smashrite/core/constants/app_constants.dart';
import 'package:smashrite/core/network/network_service.dart';
import 'package:smashrite/core/storage/storage_service.dart';
import 'package:smashrite/core/theme/app_theme.dart';
import 'package:smashrite/features/exam/data/models/exam.dart';
import 'package:smashrite/features/exam/data/models/student.dart';
import 'package:smashrite/features/exam/data/services/exam_service.dart';
import 'package:smashrite/features/auth/data/services/auth_service.dart';
import 'package:smashrite/features/server_connection/data/models/exam_server.dart';
import 'package:smashrite/features/server_connection/data/services/server_connection_service.dart';
import 'package:smashrite/features/auth/presentation/widgets/server_info_modal.dart';
import 'package:smashrite/features/exam/presentation/widgets/student_info_modal.dart';
import 'package:smashrite/shared/utils/snackbar_helper.dart';

class ExamLobbyScreen extends StatefulWidget {
  const ExamLobbyScreen({super.key});

  @override
  State<ExamLobbyScreen> createState() => _ExamLobbyScreenState();
}

class _ExamLobbyScreenState extends State<ExamLobbyScreen> {
  // ── Brand colours ────────────────────────────────────────────────────
  static const _deepBlue  = Color(0xFF0F2B6D);
  static const _orange    = Color(0xFFFF7A00);
  static const _surface   = Color(0xFFF3F5F9);

  final ServerConnectionService _serverService = ServerConnectionService();

  ExamServer? _currentServer;
  Student?    _student;
  Exam?       _exam;
  bool        _agreedToPolicies  = false;
  bool        _isLoading         = true;
  bool        _isCheckingNetwork = true;
  String?     _networkError;

  // ── Lifecycle ────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadData();
    _validateNetwork();
  }

  Future<void> _validateNetwork() async {
    setState(() { _isCheckingNetwork = true; _networkError = null; });
    final error = await NetworkService.validateNetworkForExam();
    if (mounted) setState(() { _isCheckingNetwork = false; _networkError = error; });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final server    = await _serverService.getSavedServer();
      final sJson     = StorageService.get<String>(AppConstants.studentData);
      final eJson     = StorageService.get<String>(AppConstants.currentExamData);
      if (mounted) {
        setState(() {
          _currentServer = server;
          _student = sJson != null ? Student.fromJson(jsonDecode(sJson)) : null;
          _exam    = eJson  != null ? Exam.fromJson(jsonDecode(eJson))   : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Modal helpers (unchanged) ────────────────────────────────────────

  void _showServerInfo() {
    if (_currentServer == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ServerInfoModal(
        server: _currentServer!,
        onDisconnect: _handleDisconnect,
      ),
    );
  }

  void _showStudentInfo() {
    if (_student == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentInfoModal(student: _student!, onLogout: _handleLogout),
    );
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout? You will need to login again.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final token = StorageService.get<String>(AppConstants.accessToken) ?? '';
      AuthService.initialize(_currentServer!.url, authToken: token);
      await AuthService.logout();
    } catch (e) { debugPrint('[!! WARNING !!] Logout error: $e'); }
    if (mounted) Navigator.pop(context);
    await StorageService.remove(AppConstants.accessCodeId);
    await StorageService.remove(AppConstants.accessToken);
    await StorageService.remove(AppConstants.studentData);
    await StorageService.remove(AppConstants.currentExamData);
    if (mounted) context.go('/login');
  }

  Future<void> _handleDisconnect() async {
    Navigator.pop(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect from Server?'),
        content: const Text('You will be logged out and need to reconnect. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _serverService.clearServerDetails();
    await StorageService.remove(AppConstants.accessCodeId);
    await StorageService.remove(AppConstants.accessToken);
    await StorageService.remove(AppConstants.studentData);
    await StorageService.remove(AppConstants.currentExamData);
    if (mounted) context.go('/server-connection');
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Network Issue'),
        content: Text(
          _networkError ?? 'Network validation failed',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _validateNetwork(); },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _startExam() {
    if (_isCheckingNetwork) {
      showTopSnackBar(context,
        message: 'Please wait while we validate the network...',
        backgroundColor: AppColors.info);
      return;
    }
    if (_networkError != null) { _showNetworkErrorDialog(); return; }
    if (!_agreedToPolicies) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please agree to the exam policies to continue'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final token = StorageService.get<String>(AppConstants.accessToken) ?? '';
    ExamService.initialize(_currentServer!.url, authToken: token);
    context.go('/exam');
  }

  String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : '';
  }

  String _initials(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts.isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();
    if (_exam == null || _student == null) return _buildErrorScreen();

    final canStart = !_isCheckingNetwork && _networkError == null && _agreedToPolicies;

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNetworkCard(),
                  const SizedBox(height: 14),
                  _buildInstructionsCard(),
                  const SizedBox(height: 14),
                  _buildPolicyCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildBottomBar(canStart),
        ],
      ),
    );
  }

  // ── Loading & Error screens ──────────────────────────────────────────

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: _deepBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text('Loading exam...',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: _surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error_outline_rounded, size: 52, color: Colors.red.shade400),
              ),
              const SizedBox(height: 24),
              const Text('Failed to load exam',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _deepBlue)),
              const SizedBox(height: 8),
              Text('Please go back and try again.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _deepBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero header ──────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2260), Color(0xFF1A3F9A)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: student pill + server pill ──────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Student pill
                  GestureDetector(
                    onTap: _showStudentInfo,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: _orange,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _initials(_student!.fullName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _firstName(_student!.fullName),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: Colors.white.withOpacity(0.7)),
                        ],
                      ),
                    ),
                  ),

                  // Server pill
                  if (_currentServer != null)
                    GestureDetector(
                      onTap: _showServerInfo,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentServer!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Exam label ───────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _orange.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'EXAM SESSION',
                  style: TextStyle(
                    color: Colors.orange.shade200,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // ── Exam title ───────────────────────────────────────
              Text(
                _exam!.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 18),

              // ── Stats row ────────────────────────────────────────
              Row(
                children: [
                  _headerStat(Icons.timer_rounded,
                    '${_exam!.durationMinutes}', 'min'),
                  _headerDivider(),
                  _headerStat(Icons.help_outline_rounded,
                    '${_exam!.totalQuestions}', 'questions'),
                  _headerDivider(),
                  _headerStat(Icons.star_rounded,
                    '${_exam!.totalMarks}', 'marks'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerStat(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white.withOpacity(0.7), size: 18),
          const SizedBox(height: 4),
          Text(value,
            style: const TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6), fontSize: 13,
              fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _headerDivider() {
    return Container(
      width: 1, height: 36,
      color: Colors.white.withOpacity(0.15),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  // ── Network status card ──────────────────────────────────────────────

  Widget _buildNetworkCard() {
    final Color  color;
    final IconData icon;
    final String title;
    final String subtitle;
    final Widget? trailing;

    if (_isCheckingNetwork) {
      color    = Colors.blue.shade600;
      icon     = Icons.wifi_find_rounded;
      title    = 'Checking Network';
      subtitle = 'Validating exam network requirements...';
      trailing = SizedBox(
        width: 20, height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2, color: Colors.blue.shade600),
      );
    } else if (_networkError != null) {
      color    = Colors.red.shade600;
      icon     = Icons.wifi_off_rounded;
      title    = 'Network Issue';
      subtitle = _networkError!;
      trailing = GestureDetector(
        onTap: _validateNetwork,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('Retry',
            style: TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      );
    } else {
      color    = Colors.green.shade600;
      icon     = Icons.wifi_rounded;
      title    = 'Network Ready';
      subtitle = 'No internet detected — local exam network is configured correctly.';
      trailing = Icon(Icons.check_circle_rounded,
        color: Colors.green.shade500, size: 26);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.08),
            blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  )),
                const SizedBox(height: 2),
                Text(subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade600,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  )),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing,
          ],
        ],
      ),
    );
  }

  // ── Instructions card ────────────────────────────────────────────────

  Widget _buildInstructionsCard() {
    final items = [
      (Icons.timer_rounded,               Colors.blue.shade600,
       'Time Limit',
       'You have ${_exam!.durationMinutes} minutes to complete the exam.'),
      (Icons.flag_rounded,                Colors.orange.shade600,
       'Flag Questions',
       'Mark uncertain questions with the flag button and revisit before submitting.'),
      (Icons.battery_charging_full_rounded, Colors.green.shade600,
       'Battery',
       'Ensure your device is sufficiently charged to avoid interruptions.'),
      (Icons.stay_primary_portrait_rounded, Colors.purple.shade600,
       'Stay in the App',
       'Do not close or leave the app during the exam. Violations will result in consequences.'),
      (Icons.cloud_done_rounded,           Colors.teal.shade600,
       'Auto-Save',
       'Your answers are automatically saved to the exam server in real time.'),
      (Icons.verified_user_rounded,        Colors.red.shade600,
       'Academic Integrity',
       'Screen activity is monitored. Violations will result in consequences.'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _deepBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.checklist_rounded,
                    color: _deepBlue, size: 17),
                ),
                const SizedBox(width: 10),
                const Text('Exam Instructions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _deepBlue,
                  )),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),

          // Instruction items
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            final (icon, color, title, body) = entry.value;
            return _instructionItem(icon, color, title, body, isLast);
          }),
        ],
      ),
    );
  }

  Widget _instructionItem(
    IconData icon, Color color,
    String title, String body, bool isLast,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                      )),
                    const SizedBox(height: 2),
                    Text(body,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      )),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 62, color: Colors.grey.shade100),
      ],
    );
  }

  // ── Policy agreement card ────────────────────────────────────────────

  Widget _buildPolicyCard() {
    return GestureDetector(
      onTap: () => setState(() => _agreedToPolicies = !_agreedToPolicies),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _agreedToPolicies
              ? _deepBlue.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _agreedToPolicies
                ? _deepBlue.withOpacity(0.4)
                : Colors.grey.shade200,
            width: _agreedToPolicies ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: _agreedToPolicies ? _deepBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _agreedToPolicies ? _deepBlue : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: _agreedToPolicies
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'I agree to the Exam Policies & Integrity Code',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _agreedToPolicies ? _deepBlue : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'I understand that my screen activity may be monitored and that any violation of the integrity code will be recorded and may result in consequences.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────

  Widget _buildBottomBar(bool canStart) {
    // Determine hint message for disabled state
    String? hint;
    if (_isCheckingNetwork) {
      hint = 'Checking network requirements...';
    } else if (_networkError != null) {
      hint = 'Fix the network issue above to continue.';
    } else if (!_agreedToPolicies) {
      hint = 'Agree to the exam policies above to continue.';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07),
            blurRadius: 20, offset: const Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hint text when disabled
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: hint != null
                  ? Padding(
                      key: ValueKey(hint),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded,
                            size: 13, color: AppColors.textPrimary),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(hint,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Start button
            SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  gradient: canStart
                      ? const LinearGradient(
                          colors: [Color(0xFF0F2B6D), Color(0xFF1A3F9A)],
                        )
                      : null,
                  color: canStart ? null : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: canStart
                      ? [BoxShadow(
                          color: _deepBlue.withOpacity(0.35),
                          blurRadius: 16, offset: const Offset(0, 4))]
                      : [],
                ),
                child: ElevatedButton.icon(
                  onPressed: canStart ? _startExam : null,
                  icon: Icon(
                    Icons.play_circle_rounded,
                    color: canStart ? Colors.white : Colors.grey.shade400,
                    size: 22,
                  ),
                  label: Text(
                    'Start Exam',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: canStart ? Colors.white : Colors.grey.shade400,
                      letterSpacing: 0.3,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}