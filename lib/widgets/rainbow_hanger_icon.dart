import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

class RainbowHangerIcon extends StatefulWidget {
  final double size;
  final bool animate;
  const RainbowHangerIcon({
    super.key,
    this.size = 32,
    this.animate = true,
  });

  @override
  State<RainbowHangerIcon> createState() => _RainbowHangerIconState();
}

class _RainbowHangerIconState extends State<RainbowHangerIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(RainbowHangerIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _controller.repeat();
    } else if (!widget.animate && oldWidget.animate) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: HangerPainter(
            animationValue: _controller.value,
          ),
        );
      },
    );
  }
}

class HangerPainter extends CustomPainter {
  final double animationValue;

  HangerPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // A mathematically flawless continuous figure-8 hanger with an upwards head
    const String hangerPathData = 
        'M 12 21 L 21 21 A 1.5 1.5 0 0 0 22.5 19.5 L 10.5 8.5 A 3.5 3.5 0 1 1 13.5 8.5 L 1.5 19.5 A 1.5 1.5 0 0 0 3 21 Z';
    
    final Path hangerPath = parseSvgPathData(hangerPathData);
    
    // Scale and center the path
    final double scale = size.width / 24.0;
    final Matrix4 matrix = Matrix4.identity()..scale(scale, scale);
    
    // Center logic: path is ~ 19.2 wide and ~ 13.4 tall.
    // Offsets to center it within the 'size' box.
    final double offsetX = (size.width - (18.26 * scale)) / 2 - (2.87 * scale);
    final double offsetY = (size.height - (13.4 * scale)) / 2 - (5.1 * scale);
    
    // Actually, scaling is enough if we just move it to center.
    // Let's just scale and apply a simple translation if needed.
    final Path scaledPath = hangerPath.transform(matrix.storage);
    
    final Rect currentBounds = scaledPath.getBounds();
    final double dx = (size.width - currentBounds.width) / 2 - currentBounds.left;
    final double dy = (size.height - currentBounds.height) / 2 - currentBounds.top;
    final Path centeredPath = scaledPath.shift(Offset(dx, dy));

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale 
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Rect bounds = centeredPath.getBounds();
    paint.shader = SweepGradient(
      center: Alignment.center,
      colors: const [
        Colors.purple,
        Colors.pink,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.cyan,
        Colors.blue,
        Colors.purple,
      ],
      stops: const [0.0, 0.14, 0.28, 0.42, 0.57, 0.71, 0.85, 1.0],
      transform: GradientRotation(animationValue * 2 * math.pi),
    ).createShader(bounds);

    canvas.drawPath(centeredPath, paint);
  }

  @override
  bool shouldRepaint(covariant HangerPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
