import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smashrite/core/theme/app_theme.dart';

class VivaCameraScreen extends StatefulWidget {
  final String questionLabel;
  final String displayCode;
  final String code;

  const VivaCameraScreen({
    super.key,
    required this.questionLabel,
    required this.displayCode,
    required this.code,
  });

  /// Push the camera screen and return captured bytes, or null if cancelled.
  static Future<Uint8List?> capture(
    BuildContext context, {
    required String questionLabel,
    required String displayCode,
    required String code,
  }) {
    return Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VivaCameraScreen(
          questionLabel: questionLabel,
          displayCode: displayCode,
          code: code,
        ),
      ),
    );
  }

  @override
  State<VivaCameraScreen> createState() => _VivaCameraScreenState();
}

class _VivaCameraScreenState extends State<VivaCameraScreen>
    with WidgetsBindingObserver {
  static const _deepBlue = Color(0xFF0F2B6D);
  static const _orange   = Color(0xFFFF7A00);

  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitializing = true;
  bool _isCapturing    = false;
  String? _error;

  // Preview state after capture
  Uint8List? _capturedBytes;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _isInitializing = false;
          _error = 'No camera found on this device.';
        });
        return;
      }

      // Prefer back camera
      final camera = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) return;

      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _error = 'Camera error: $e';
      });
    }
  }

  Future<void> _capture() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      final file  = await _controller!.takePicture();
      final bytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        _capturedBytes = bytes;
        _showPreview   = true;
        _isCapturing   = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Capture failed: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  void _confirmCapture() {
    if (_capturedBytes != null) {
      Navigator.pop(context, _capturedBytes);
    }
  }

  void _retake() {
    setState(() {
      _capturedBytes = null;
      _showPreview   = false;
    });
  }

  void _cancel() => Navigator.pop(context, null);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _showPreview && _capturedBytes != null
            ? _buildPreview()
            : _buildViewfinder(),
      ),
    );
  }

  // ── Viewfinder ────────────────────────────────────────────────────────────

  Widget _buildViewfinder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        if (_isInitializing)
          const Center(
            child: CircularProgressIndicator(color: Colors.white))
        else if (_error != null)
          _buildCameraError()
        else if (_controller != null && _controller!.value.isInitialized)
          _buildCameraPreview(),

        // Top bar — code reminder + cancel
        _buildViewfinderTopBar(),

        // Bottom — capture button
        _buildCaptureButton(),

        // Corner guide overlay
        if (!_isInitializing && _error == null)
          const _CameraGuideOverlay(),
      ],
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;

    var scale = size.aspectRatio * _controller!.value.aspectRatio;

    // Always scale UP — never shrink below 1.0
    if (scale < 1) scale = 1 / scale;

    return Transform.scale(
      scale: scale,
      child: Center(
        child: CameraPreview(_controller!),
      ),
    );
  }

  Widget _buildViewfinderTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _cancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Cancel',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Code reminder
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _orange.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: _orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your paper must show:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.displayCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
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
    );
  }

  Widget _buildCaptureButton() {
    return Positioned(
      bottom: 48,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Text(
            'Position your workings clearly, then capture',
            style: TextStyle(
              color: Colors.black.withOpacity(0.75),
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _isCapturing ? null : _capture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isCapturing
                    ? Colors.white.withOpacity(0.5)
                    : Colors.white,
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _isCapturing
                  ? const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.black45,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white54, size: 52),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Camera unavailable',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Preview ───────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Captured image
        Image.memory(_capturedBytes!, fit: BoxFit.cover),

        // Darken slightly
        Container(color: Colors.black.withOpacity(0.3)),

        // Bottom action bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.85),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Check that your student ID, question label, and code are clearly visible before confirming.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.bold
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _retake,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retake'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _confirmCapture,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Use This Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _deepBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Top cancel
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          child: GestureDetector(
            onTap: _retake,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Back',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Camera guide overlay (corner brackets) ────────────────────────────────────

class _CameraGuideOverlay extends StatelessWidget {
  const _CameraGuideOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _GuideLinePainter(),
        child: Container(),
      ),
    );
  }
}

class _GuideLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const margin = 40.0;
    const length = 30.0;

    // Top-left
    canvas.drawLine(
      const Offset(margin, margin), Offset(margin + length, margin), paint);
    canvas.drawLine(
      const Offset(margin, margin), Offset(margin, margin + length), paint);

    // Top-right
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin - length, margin), paint);
    canvas.drawLine(
      Offset(size.width - margin, margin),
      Offset(size.width - margin, margin + length), paint);

    // Bottom-left
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin + length, size.height - margin), paint);
    canvas.drawLine(
      Offset(margin, size.height - margin),
      Offset(margin, size.height - margin - length), paint);

    // Bottom-right
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin - length, size.height - margin), paint);
    canvas.drawLine(
      Offset(size.width - margin, size.height - margin),
      Offset(size.width - margin, size.height - margin - length), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
