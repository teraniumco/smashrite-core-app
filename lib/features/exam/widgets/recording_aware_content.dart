// lib/features/exam/widgets/recording_aware_content.dart
import 'package:flutter/material.dart';
import 'dart:ui';

class RecordingAwareContent extends StatelessWidget {
  final Widget child;
  final bool isRecording;
  
  const RecordingAwareContent({
    super.key,
    required this.child,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    if (!isRecording) {
      return child;
    }
    
    // Blur content when recording
    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
        
        // Warning overlay
        Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.videocam_off,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Screen Recording Detected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Stop recording to continue exam',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}