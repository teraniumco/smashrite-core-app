import 'package:flutter/material.dart';
import 'dart:async';

class ConnectionStatusBadge extends StatelessWidget {
  final bool isConnected;

  const ConnectionStatusBadge({
    super.key,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connected' : 'Disconnected',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Exam Timer - countdown timer for exam duration
class ExamTimer extends StatefulWidget {
  final Duration duration;
  final Function(Duration)? onTimeUpdate;

  const ExamTimer({
    super.key,
    required this.duration,
    this.onTimeUpdate,
  });

  @override
  State<ExamTimer> createState() => _ExamTimerState();
}

class _ExamTimerState extends State<ExamTimer> {
  late Duration _remainingTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.duration;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
        });
        widget.onTimeUpdate?.call(_remainingTime);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime() {
    final hours = _remainingTime.inHours.toString().padLeft(2, '0');
    final minutes = (_remainingTime.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (_remainingTime.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Color _getTimerColor() {
    if (_remainingTime.inMinutes < 1) {
      return Colors.red; // Critical - less than 1 minute
    } else if (_remainingTime.inMinutes < 5) {
      return Colors.orange; // Warning - less than 5 minutes
    } else {
      return Colors.blue; // Normal
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getTimerColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getTimerColor().withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: 16,
            color: _getTimerColor(),
          ),
          const SizedBox(width: 6),
          Text(
            _formatTime(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _getTimerColor(),
              fontFeatures: const [
                FontFeature.tabularFigures(), // Monospaced numbers
              ],
            ),
          ),
        ],
      ),
    );
  }
}
