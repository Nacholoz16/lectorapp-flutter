import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Loader de libro: varias páginas giran sobre el lomo, en cascada.
class BookLoader extends StatefulWidget {
  final Color color;
  final double size;

  const BookLoader({super.key, required this.color, this.size = 44});

  @override
  State<BookLoader> createState() => _BookLoaderState();
}

class _BookLoaderState extends State<BookLoader>
    with SingleTickerProviderStateMixin {
  // Cuántas páginas giran y cómo se solapan dentro del ciclo.
  static const int _pageCount = 3;
  static const double _flipSpan = 0.55; // duración de un giro (0..1)
  static const double _stagger = 0.15; // retraso entre páginas

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1600),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _flat => widget.color.withValues(alpha: 0.28);

  @override
  Widget build(BuildContext context) {
    final w = widget.size;
    final h = w * 0.74;
    final half = w / 2;
    final radius = w * 0.09;

    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              _cover(left: true, half: half, radius: radius),
              _cover(left: false, half: half, radius: radius),
              // Las últimas se dibujan debajo para que el orden de giro se lea bien.
              for (int i = _pageCount - 1; i >= 0; i--)
                _flippingPage(i, half: half, radius: radius),
              // Lomo
              Positioned(
                left: half - 0.5,
                top: 0,
                bottom: 0,
                width: 1,
                child: ColoredBox(color: widget.color.withValues(alpha: 0.55)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cover({
    required bool left,
    required double half,
    required double radius,
  }) {
    final r = Radius.circular(radius);
    return Positioned(
      left: left ? 0 : half,
      top: 0,
      bottom: 0,
      width: half,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _flat,
          borderRadius: left
              ? BorderRadius.horizontal(left: r)
              : BorderRadius.horizontal(right: r),
        ),
      ),
    );
  }

  Widget _flippingPage(int index, {required double half, required double radius}) {
    final raw = (_controller.value - index * _stagger) / _flipSpan;
    final t = Curves.easeInOutCubic.transform(raw.clamp(0.0, 1.0));
    final angle = t * math.pi;

    // 0 en reposo, 1 cuando la página está levantada: controla luz y sombra.
    final lift = math.sin(angle);

    return Positioned(
      left: half,
      top: 0,
      bottom: 0,
      width: half,
      child: Transform(
        alignment: Alignment.centerLeft,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0018) // perspectiva
          ..rotateY(-angle),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(radius)),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.color.withValues(alpha: 0.28 + 0.50 * lift),
                widget.color.withValues(alpha: 0.28 + 0.18 * lift),
              ],
            ),
            boxShadow: lift < 0.02
                ? null
                : [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.22 * lift),
                      blurRadius: 6 * lift,
                      offset: Offset(0, 2 * lift),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}