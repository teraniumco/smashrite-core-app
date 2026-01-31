import 'package:flutter/material.dart';

class WatermarkedContent extends StatelessWidget {
  final Widget child;
  final String studentId;
  final String examId;
  
  const WatermarkedContent({
    super.key,
    required this.child,
    required this.studentId,
    required this.examId,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        
        // Watermark overlay
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: WatermarkPainter(
                text: 'Student: $studentId\nExam: $examId\n${DateTime.now()}',
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WatermarkPainter extends CustomPainter {
  final String text;
  
  WatermarkPainter({required this.text});
  
  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.grey.withOpacity(0.15),
          fontSize: 12,
          fontWeight: FontWeight.w300,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // Draw watermark in multiple positions (grid pattern)
    for (double y = 0; y < size.height; y += 150) {
      for (double x = 0; x < size.width; x += 200) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-0.3); // Slight rotation
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}