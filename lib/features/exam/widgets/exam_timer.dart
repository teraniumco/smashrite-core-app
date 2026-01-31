import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smashrite/core/theme/app_theme.dart';

class ExamTimer extends StatefulWidget {
  final Duration duration;
  final Function(Duration)? onTimeUpdate;
  final bool compact;

  const ExamTimer({
    super.key,
    required this.duration,
    this.onTimeUpdate,
    this.compact = false,
  });

  @override
  State<ExamTimer> createState() => _ExamTimerState();
}

class _ExamTimerState extends State<ExamTimer> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.duration;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining.inSeconds <= 0) {
        timer.cancel();
        return;
      }

      setState(() {
        _remaining = Duration(seconds: _remaining.inSeconds - 1);
      });

      widget.onTimeUpdate?.call(_remaining);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _getTimerColor() {
    final minutes = _remaining.inMinutes;
    if (minutes <= 1) return Colors.red;
    if (minutes <= 5) return Colors.orange;
    return AppColors.success;
  }

  String _formatTime() {
    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes.remainder(60);
    final seconds = _remaining.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getTimerColor();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 6 : 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            color: color,
            size: widget.compact ? 18 : 20,
          ),
          const SizedBox(width: 4),
          Text(
            _formatTime(),
            style: TextStyle(
              color: color,
              fontSize: widget.compact ? 17 : 19,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}