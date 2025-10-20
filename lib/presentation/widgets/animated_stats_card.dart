import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class AnimatedStatsCard extends StatefulWidget {
  final String title;
  final int value;
  final Color color;
  final IconData icon;
  final Duration animationDuration;
  final int? maxValue; // القيمة القصوى لحساب النسبة

  const AnimatedStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.animationDuration = const Duration(milliseconds: 2000),
    this.maxValue, // إذا لم يتم تحديدها، ستكون الدائرة مكتملة
  });

  @override
  State<AnimatedStatsCard> createState() => _AnimatedStatsCardState();
}

class _AnimatedStatsCardState extends State<AnimatedStatsCard>
    with TickerProviderStateMixin {
  late AnimationController _circleController;
  late AnimationController _countController;
  late Animation<double> _circleAnimation;
  late Animation<int> _countAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animation controller for the circular progress
    _circleController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    // Animation controller for the counter
    _countController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    // Circular progress animation (0 to calculated percentage)
    double progressPercentage = 1.0; // Default to full circle
    if (widget.maxValue != null && widget.maxValue! > 0) {
      progressPercentage = (widget.value / widget.maxValue!).clamp(0.0, 1.0);
    }
    
    _circleAnimation = Tween<double>(
      begin: 0.0,
      end: progressPercentage,
    ).animate(CurvedAnimation(
      parent: _circleController,
      curve: Curves.easeInOutCubic,
    ));
    
    // Counter animation (0 to actual value)
    _countAnimation = IntTween(
      begin: 0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _countController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start animations
    _startAnimations();
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _circleController.forward();
        _countController.forward();
      }
    });
  }

  @override
  void dispose() {
    _circleController.dispose();
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _circleController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * _circleAnimation.value),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.1 + (0.1 * _circleAnimation.value)),
                  blurRadius: 20 + (10 * _circleAnimation.value),
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated circular progress with icon
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(0.1),
                  ),
                ),
                // Animated progress circle
                AnimatedBuilder(
                  animation: _circleAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(80, 80),
                      painter: CircularProgressPainter(
                        progress: _circleAnimation.value,
                        color: widget.color,
                        strokeWidth: 4.0,
                      ),
                    );
                  },
                ),
                // Icon in center
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(0.15),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.color,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Animated counter
          AnimatedBuilder(
            animation: _countAnimation,
            builder: (context, child) {
              return Text(
                _formatNumber(_countAnimation.value),
                style: GoogleFonts.cairo(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // Title
          Text(
            widget.title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
          ),
        );
      },
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}م';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}ك';
    }
    return number.toString();
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw the progress arc
    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * progress;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}
