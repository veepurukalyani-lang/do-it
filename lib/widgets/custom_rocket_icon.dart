import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../app_state.dart';
import 'auth_prompt_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CONSTANTS  (mirror the HTML demo exactly)
// ─────────────────────────────────────────────────────────────────────────────

// Total animation duration matches demo
const double _kTColor  = 220;   // ms – colour-change phase end
const double _kTLaunch = 1200;  // ms – launch phase end
const double _kTVanish = 1380;  // ms – vanish phase end
const double _kTDone   = 2250;  // ms – full animation end
const double _kTotalMs = _kTDone;

// Rocket travel
const double _kTravelPx = 140.0;

// Smoke
const double _kPuffLife         = 1600.0; // ms each puff survives
const double _kIntervalStart    = 105.0;  // ms between clusters (slow) - slowed down further
const double _kIntervalEnd      = 12.0;   // ms between clusters (fast) - slowed down further

// SVG size / icon
const double _kSvgSz  = 24.0;
const double _kIconPx = 38.0;

// ─────────────────────────────────────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────
double _lerp(double a, double b, double t) => a + (b - a) * t;
double _clamp(double v, double lo, double hi) => v.clamp(lo, hi) as double;
double _inv(double a, double b, double v) => _clamp((v - a) / (b - a), 0, 1);
double _easeInCubic(double t) => t * t * t;
double _easeInQuad(double t) => t * t;
double _easeOutQuad(double t) => 1 - (1 - t) * (1 - t);

class RocketColorTheme {
  final Color rocket;
  final Color smoke;
  const RocketColorTheme(this.rocket, this.smoke);
}

const List<RocketColorTheme> _kColorThemes = [
  RocketColorTheme(Color(0xFFFF2D8D), Color(0xFFFF6EAA)), // Magenta Pink (lighter smoke)
  RocketColorTheme(Color(0xFF50C878), Color(0xFF00FF7F)), // Emerald Green (lighter smoke)
  RocketColorTheme(Color(0xFF08E8DE), Color(0xFF65F2EB)), // Bright Turquoise (lighter smoke)
  RocketColorTheme(Color(0xFFED2939), Color(0xFFF46B76)), // Imperial Red (lighter smoke)
];

// ─────────────────────────────────────────────────────────────────────────────
//  PUFF DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────
class _Puff {
  final double x;       // canvas X
  final double y;       // canvas Y (nozzle position at birth)
  final double maxR;    // max radius
  final double alpha;   // base opacity cap
  final double born;    // ms from animation start when spawned
  const _Puff({
    required this.x,
    required this.y,
    required this.maxR,
    required this.alpha,
    required this.born,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  ROCKET PAINTER  (SVG icon, rotated –45°)
// ─────────────────────────────────────────────────────────────────────────────
class RocketPainter extends CustomPainter {
  final Color color;
  final bool isLiked;

  RocketPainter(this.color, {this.isLiked = false});

  @override
  void paint(Canvas canvas, Size size) {
    final String svgPath = isLiked
        ? 'M9.19,6.35c-2.04,2.29-3.44,5.58-3.57,5.89L2,10.69l4.05-4.05'
          'c0.47-0.47,1.15-0.68,1.81-0.55L9.19,6.35z'
          'M11.17,17c0,0,3.74-1.55,5.89-3.7c5.4-5.4,4.5-9.62,4.21-10.57'
          'c-0.95-0.3-5.17-1.19-10.57,4.21C8.55,9.09,7,12.83,7,12.83L11.17,17z'
          'M17.65,14.81c-2.29,2.04-5.58,3.44-5.89,3.57L13.31,22l4.05-4.05'
          'c0.47-0.47,0.68-1.15,0.55-1.81L17.65,14.81z'
          'M9,18c0,0.83-0.34,1.58-0.88,2.12C6.94,21.3,2,22,2,22'
          's0.7-4.94,1.88-6.12C4.42,15.34,5.17,15,6,15C7.66,15,9,16.34,9,18z'
        : 'M6,15c-0.83,0-1.58,0.34-2.12,0.88C2.7,17.06,2,22,2,22'
          's4.94-0.7,6.12-1.88C8.66,19.58,9,18.83,9,18C9,16.34,7.66,15,6,15z'
          'M6.71,18.71c-0.28,0.28-2.17,0.76-2.17,0.76s0.47-1.88,0.76-2.17'
          'C5.47,17.11,5.72,17,6,17c0.55,0,1,0.45,1,1C7,18.28,6.89,18.53,6.71,18.71z'
          'M17.42,13.65c6.36-6.36,4.24-11.31,4.24-11.31s-4.95-2.12-11.31,4.24'
          'l-2.49-0.5C7.21,5.95,6.53,6.16,6.05,6.63L2,10.69l5,2.14L11.17,17'
          'l2.14,5l4.05-4.05c0.47-0.47,0.68-1.15,0.55-1.81L17.42,13.65z'
          'M7.41,10.83L5.5,10.01l1.97-1.97l1.44,0.29C8.34,9.16,7.83,10.03,7.41,10.83z'
          'M13.99,18.5l-0.82-1.91c0.8-0.42,1.67-0.93,2.49-1.5l0.29,1.44L13.99,18.5z'
          'M16,12.24c-1.32,1.32-3.38,2.4-4.04,2.73l-2.93-2.93'
          'c0.32-0.65,1.4-2.71,2.73-4.04c4.68-4.68,8.23-3.99,8.23-3.99'
          'S20.68,7.56,16,12.24z';

    final Path rocketPath = parseSvgPathData(svgPath);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final double scaleRatio = size.width / _kSvgSz;
    canvas.save();
    canvas.scale(scaleRatio, scaleRatio);
    canvas.drawPath(rocketPath, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RocketPainter old) =>
      old.color != color || old.isLiked != isLiked;
}

// ─────────────────────────────────────────────────────────────────────────────
//  SMOKE PAINTER  – exact port of the HTML drawSmoke() function
// ─────────────────────────────────────────────────────────────────────────────
class _SmokePainter extends CustomPainter {
  final List<_Puff> puffs;
  final double elapsedMs;   // ms since animation started
  final double canvasW;
  final double canvasH;
  final double defaultCY;   // rocket centre Y at rest (canvas coords)
  final Color smokeBaseColor;

  const _SmokePainter({
    required this.puffs,
    required this.elapsedMs,
    required this.canvasW,
    required this.canvasH,
    required this.defaultCY,
    required this.smokeBaseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Return-phase progress (0→1), used for per-puff staggered vanish
    final double returnP = _clamp(
      (elapsedMs - _kTVanish) / (_kTDone - _kTVanish), 0, 1);

    // Draw oldest puffs first (big base behind, small trail on top)
    final sorted = puffs; // They are already added in chronological order

    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in sorted) {
      final double age = elapsedMs - p.born;
      if (age >= _kPuffLife) continue;

      final double life = age / _kPuffLife; // 0 → 1

      // Radius: fast expand then plateau
      final double r = p.maxR * math.pow(life, 0.45);

      // Opacity lifecycle
      double op;
      if      (life < 0.08) op = life / 0.08;
      else if (life < 0.60) op = 1.0;
      else                  op = 1 - (life - 0.60) / 0.40;
      op = _clamp(op, 0, 1) * p.alpha;

      // Physics vanish: first-born → fade first, last-born → linger longest
      if (returnP > 0) {
        final double birthRank = _clamp(
          (p.born - _kTColor) / (_kTLaunch - _kTColor), 0, 1);
        final double vanishStart = birthRank * 0.30;
        final double puffFade = _clamp(
          1 - (returnP - vanishStart) / 0.70, 0, 1);
        op *= puffFade;
      }

      if (op <= 0) continue;

      // Slight downward sag as smoke ages
      final double sag = life * 4;

      // Apply dynamic color with op opacity
      paint.color = smokeBaseColor.withOpacity(op.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(p.x, p.y + sag), math.max(r, 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmokePainter old) =>
      old.elapsedMs != elapsedMs || old.puffs.length != puffs.length;
}

// ─────────────────────────────────────────────────────────────────────────────
//  CustomRocketIcon – static icon (used wherever no animation is needed)
// ─────────────────────────────────────────────────────────────────────────────
class CustomRocketIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool isLiked;

  const CustomRocketIcon({
    super.key,
    this.size = 28.0,
    this.color = Colors.white,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color displayColor = isLiked ? const Color(0xFFFF2D8D) : color;
    return Transform.rotate(
      angle: -math.pi / 4,
      child: CustomPaint(
        size: Size(size, size),
        painter: RocketPainter(displayColor, isLiked: isLiked),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RocketLaunchButton
//  Exact Flutter port of rocket_demo/index.html animation logic.
// ─────────────────────────────────────────────────────────────────────────────
class RocketLaunchButton extends StatefulWidget {
  final int likeCount;
  final bool isLiked;
  final VoidCallback onTap;
  final double iconSize;
  final String? authTitle;
  final String? authSubtitle;
  final Color idleColor;
  final Color textColor;
  final Axis direction;

  const RocketLaunchButton({
    super.key,
    required this.likeCount,
    required this.isLiked,
    required this.onTap,
    this.iconSize = 32,
    this.authTitle,
    this.authSubtitle,
    this.idleColor = Colors.white,
    this.textColor = Colors.white,
    this.direction = Axis.vertical,
  });

  @override
  State<RocketLaunchButton> createState() => RocketLaunchButtonState();
}

class RocketLaunchButtonState extends State<RocketLaunchButton>
    with SingleTickerProviderStateMixin {

  late AnimationController _ctrl;

  // Live puff list – mutated each frame during launch
  final List<_Puff> _puffs = [];
  double _lastEmitT = 0;

  bool _animating = false;
  int _tickLikesCount = 0;

  late List<RocketColorTheme> _shuffledThemes;
  late RocketColorTheme _currentTheme;
  final math.Random _themeRng = math.Random();

  void _pickNextTheme() {
    if (_shuffledThemes.isEmpty) {
      _shuffledThemes = List.of(_kColorThemes)..shuffle(_themeRng);
      // Avoid repeating the same color backwards
      if (_shuffledThemes.first == _currentTheme && _kColorThemes.length > 1) {
        final first = _shuffledThemes.removeAt(0);
        _shuffledThemes.add(first);
      }
    }
    _currentTheme = _shuffledThemes.removeAt(0);
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  // Canvas dimensions (set in build, stable after first frame)
  double _canvasW = 110;
  double _canvasH = 380;
  double get _defaultCY => _canvasH - 80; // nozzle base Y (matches HTML)
  double get _nozzleOffsetY => (_kIconPx / 2) * 0.82;

  // RNG — reset to fixed seed 42 at start of every animation run
  // so the smoke pattern is IDENTICAL every single tap, no gaps ever.
  math.Random _rng = math.Random(42);

  @override
  void initState() {
    super.initState();
    _tickLikesCount = widget.likeCount;
    _shuffledThemes = List.of(_kColorThemes)..shuffle(_themeRng);
    _currentTheme = _shuffledThemes.removeAt(0);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _kTotalMs ~/ 1),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Emit cluster (exact port of HTML emitCluster) ─────────────────────────
  void _emitCluster(double nowMs, double nx, double ny, double progress) {
    final double baseR  = _lerp(30, 13, progress);
    final double spread = _lerp(9, 5, progress);

    // Fade outer rings symmetrically
    final double fadeOuter = _clamp(1 - (progress - 0.78) / 0.18, 0, 1);
    final double fadeWide  = _clamp(1 - (progress - 0.55) / 0.17, 0, 1);

    final double alpha = _lerp(0.72, 0.60, progress);

    // 4 base + 2 wide outer positions (same as HTML)
    // Added 'delay' to stagger them and adjusted 'dy' to lift side puffs
    final clusters = [
      (dx: 0.0,           dy: 0.0, rScale: 1.0,        delay: 0.0 ),
      (dx: -3.0,          dy: 8.0, rScale: 1.0,        delay: 5.0 ),
      (dx: -spread,       dy: 1.5, rScale: fadeOuter,  delay: 15.0),
      (dx: spread,        dy: 1.5, rScale: fadeOuter,  delay: 15.0),
      (dx: -spread * 1.7, dy: 3.5, rScale: fadeWide,   delay: 25.0),
      (dx: spread  * 1.7, dy: 3.5, rScale: fadeWide,   delay: 25.0),
    ];

    final double jMult = 1 - progress * 0.85;
    for (final c in clusters) {
      if (c.rScale <= 0.04) continue;
      // Fixed RNG matching JS exactly: (Math.random() * 5 - 2.5)
      final double effectiveR =
          (baseR + (_rng.nextDouble() * 5 - 2.5)) * c.rScale;
      if (effectiveR < 1) continue;
      _puffs.add(_Puff(
        // Fixed RNG matching JS exactly: (Math.random() * 4 - 2), (Math.random() * 3 - 1.5)
        x:     nx + c.dx + (_rng.nextDouble() * 4 - 2) * jMult,
        y:     ny + c.dy + (_rng.nextDouble() * 3 - 1.5) * jMult,
        maxR:  effectiveR,
        alpha: alpha,
        born:  nowMs + c.delay, // staggered birth
      ));
    }
  }

  // ── Main animation tick (mirrors HTML frame()) ────────────────────────────
  void _tick(double elapsedMs) {
    if (!_animating) return;

    double dy = 0, scale = 1, opacity = 0;
    Color color = _currentTheme.rocket;
    bool doEmit = false;
    double smokeProgress = 0;

    final double t = elapsedMs;

    if (t <= _kTColor) {
      // Phase 0 – turn to theme color
      final double p = t / _kTColor;
      color   = Color.lerp(widget.idleColor, _currentTheme.rocket, _clamp(p, 0, 1)) ?? widget.idleColor;
      dy      = 0; scale = 1; opacity = 1; doEmit = false;

    } else if (t <= _kTLaunch) {
      // Phase 1 – launch with smooth cubic acceleration
      final double p = _inv(_kTColor, _kTLaunch, t);
      dy             = _kTravelPx * _easeInCubic(p);
      scale          = _lerp(1.0, 0.88, p);
      opacity        = 1;
      smokeProgress  = _easeInCubic(p);
      doEmit         = p > 0.06;

    } else if (t <= _kTVanish) {
      // Phase 2 – rocket vanishes
      final double p = _inv(_kTLaunch, _kTVanish, t);
      dy      = _kTravelPx;
      scale   = _lerp(0.88, 0.15, _easeInQuad(p));
      opacity = 1 - _easeInQuad(p);
      doEmit  = false;

    } else if (t <= _kTDone) {
      // Phase 3 – rocket reappears at default; smoke fades out (per-puff)
      final double p = _inv(_kTVanish, _kTDone, t);
      dy      = 0;
      scale   = _lerp(0.45, 1.0, _easeOutQuad(p));
      opacity = _easeOutQuad(p);
      doEmit  = false;
    }

    // Nozzle world position (canvas coords, Y increases downward)
    final double cx      = _canvasW / 2;
    final double nozzleY = _defaultCY - dy + _nozzleOffsetY;

    // ── Emit clusters — catch up ALL missed intervals this frame ──────────
    // This prevents smoke gaps when frames drop (e.g. 16ms tick misses
    // multiple 9ms intervals). We emit one cluster per missed slot.
    if (doEmit) {
      final double currentInterval =
          _lerp(_kIntervalStart, _kIntervalEnd, smokeProgress);
      // Recompute nozzle position (dy unchanged in this frame)
      while ((elapsedMs - _lastEmitT) >= currentInterval) {
        _lastEmitT += currentInterval;
        _emitCluster(_lastEmitT, cx, _defaultCY - dy + _nozzleOffsetY, smokeProgress);
      }
    }

    // Prune dead puffs
    _puffs.removeWhere((p) => (elapsedMs - p.born) >= _kPuffLife);

    // Store tick data for the painter via setState (only forced once per frame
    // by AnimatedBuilder – no extra rebuilds)
    _tickDy      = dy;
    _tickScale   = scale;
    _tickOpacity = opacity;
    _tickColor   = color;
    _tickElapsed = elapsedMs;
  }

  // Frame data (written by _tick, read by AnimatedBuilder)
  double _tickDy      = 0;
  double _tickScale   = 1;
  double _tickOpacity = 1;
  Color  _tickColor   = Colors.white;
  double _tickElapsed = 0;

  // ── Handle tap / External trigger ─────────────────────────────────────────
  Future<void> launch({bool forceAnimate = false, bool isDoubleTap = false}) async {
    if (_animating) return;

    // Check auth before starting animation
    if (!appState.isLoggedIn) {
      AuthPromptDialog.show(
        context,
        title: widget.authTitle ?? 'Like this post?',
        subtitle: widget.authSubtitle ?? 'Sign in to make your opinion count.',
      );
      return;
    }

    // UNLIKE: only occurs via single-tap on the icon when already liked.
    // Double-tap should NEVER unlike (standard Instagram/YouTube behaviour).
    if (widget.isLiked && !forceAnimate && !isDoubleTap) {
      widget.onTap(); // This should trigger unlike in AppState
      setState(() {
        _tickLikesCount = widget.likeCount - 1;
        _tickColor = widget.idleColor;
      });
      return;
    }

    // LIKE or DOUBLE-TAP when already liked:
    // 1. If NOT liked: increment count + animate.
    // 2. If ALREADY liked + Double-tap: just animate (no count change).
    final bool shouldIncrement = !widget.isLiked;
    
    setState(() {
      _animating = true;
      _tickLikesCount = shouldIncrement ? widget.likeCount + 1 : widget.likeCount;
      _pickNextTheme();
    });
    
    // Only trigger the actual like change if we're not already liked
    if (shouldIncrement) {
      widget.onTap();
    }

    _puffs.clear();
    _lastEmitT = 0;
    _rng = math.Random(42); // reset RNG → identical smoke every run

    _ctrl.duration = const Duration(milliseconds: _kTotalMs ~/ 1);
    await _ctrl.forward(from: 0);
    if (!mounted) return;

    _ctrl.reset();
    setState(() {
      _animating   = false;
      _tickDy      = 0;
      _tickScale   = 1;
      _tickOpacity = 1;
      _tickColor   = _currentTheme.rocket; // stays theme color after like
      _tickLikesCount = widget.likeCount; // Sync back to real count
      _puffs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool liked       = widget.isLiked;
    final Color currentIdleColor  = liked ? _currentTheme.rocket : widget.idleColor;

    // Canvas size mirrors HTML zone: 110 × 380 logical pixels
    // Scale by iconSize/38 so it respects the widget's requested iconSize.
    final double scale     = widget.iconSize / _kIconPx;
    _canvasW = 110 * scale;
    _canvasH = 380 * scale;


    final iconWidget = SizedBox(
      width:  widget.iconSize * 1.3,
      height: widget.iconSize * 1.3,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (_animating) _tick(_ctrl.value * _kTotalMs);

          final Color rocketColor = _animating ? _tickColor : currentIdleColor;
          final double dy     = _animating ? _tickDy      : 0;
          final double rScale = _animating ? _tickScale   : 1;
          final double op     = _animating ? _tickOpacity : 1;

          final double boxSize = widget.iconSize * 1.3;

          // ── Smoke canvas offset in box coordinates ─────────────────
          // We want nozzle absolute Y matching:  boxSize/2 - defaultCY
          final double smokeLeft = (boxSize - _canvasW) / 2;
          final double smokeTop  = boxSize / 2 - _defaultCY;


          // ── Rocket position in box coordinates ─────────────────────
          // At rest: centred in box.  While flying: moves up by dy px.
          // (dy is in canvas coords; canvas & box share the same px scale)
          final double rocketLeft = (boxSize - widget.iconSize) / 2;
          final double rocketTop  = (boxSize - widget.iconSize) / 2 - dy;

          return Stack(
            clipBehavior: Clip.none,   // smoke & rocket travel beyond box
            children: [
              // ── Smoke layer (overflows downward + sideways) ───────
              if (_animating || _puffs.isNotEmpty)
                Positioned(
                  left:   smokeLeft,
                  top:    smokeTop,
                  width:  _canvasW,
                  height: _canvasH,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _SmokePainter(
                        puffs:     List.unmodifiable(_puffs),
                        elapsedMs: _tickElapsed,
                        canvasW:   _canvasW,
                        canvasH:   _canvasH,
                        defaultCY: _defaultCY,
                        smokeBaseColor: _currentTheme.smoke,
                      ),
                    ),
                  ),
                ),

              // ── Rocket icon (overflows upward while flying) ───────
              Positioned(
                left: rocketLeft,
                top:  rocketTop,
                child: Opacity(
                  opacity: op.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: rScale,
                    child: Transform.rotate(
                      angle: -math.pi / 4,
                      child: CustomPaint(
                        size: Size(widget.iconSize, widget.iconSize),
                        painter: RocketPainter(rocketColor, isLiked: liked),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final textWidget = Text(
      _formatCount(_animating ? _tickLikesCount : widget.likeCount),
      style: TextStyle(
        fontSize: widget.direction == Axis.horizontal ? 14 : 12,
        color: widget.textColor,
        fontWeight: FontWeight.bold,
      ),
    );

    return GestureDetector(
      onTap: launch,
      behavior: HitTestBehavior.opaque,
      child: widget.direction == Axis.vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                textWidget,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                const SizedBox(width: 4),
                textWidget,
              ],
            ),
    );
  }
}


