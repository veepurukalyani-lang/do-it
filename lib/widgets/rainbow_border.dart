import 'package:flutter/material.dart';

class RainbowBorderContainer extends StatefulWidget {
  final Widget child;
  const RainbowBorderContainer({Key? key, required this.child}) : super(key: key);

  @override
  _RainbowBorderContainerState createState() => _RainbowBorderContainerState();
}

class _RainbowBorderContainerState extends State<RainbowBorderContainer> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    // Rotation animation for the rainbow gradient
    _rotationController = AnimationController(
       duration: const Duration(seconds: 5),
       vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: SweepGradient(
              center: FractionalOffset.center,
              startAngle: 0.0,
              endAngle: 3.14 * 2,
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
              stops: const [
                0.0, 0.14, 0.28, 0.42, 0.57, 0.71, 0.85, 1.0,
              ],
              transform: GradientRotation(_rotationController.value * 2 * 3.14),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3.5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: Container(
                color: Colors.black,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

