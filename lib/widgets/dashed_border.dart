import 'package:flutter/material.dart';

class DashedDivider extends StatelessWidget {
  final double height;
  final double thickness;  // إضافة متغير جديد لسُمك الخط
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    this.height = 1,
    this.thickness = 1,  // السُمك الافتراضي للخط
    this.color = Colors.black,
    this.dashWidth = 5,
    this.dashSpace = 3,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(  // لتوسيط الخط عموديًا
        child: CustomPaint(
          size: Size(double.infinity, thickness),
          painter: _DashedLinePainter(
            color: color,
            dashWidth: dashWidth,
            dashSpace: dashSpace,
            thickness: thickness,
          ),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final double dashWidth;
  final double dashSpace;
  final double thickness;
  final Color color;

  _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.dashSpace,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;  // استخدام thickness بدلاً من size.height

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),  // رسم الخط في المنتصف
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}