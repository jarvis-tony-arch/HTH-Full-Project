import 'dart:math';
import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';

/// Animated circular confidence gauge with color transitions.
class ConfidenceMeter extends StatefulWidget {
  final double confidence;
  final double size;
  final double strokeWidth;
  final bool showLabel;
  final double? threshold;

  const ConfidenceMeter({
    super.key,
    required this.confidence,
    this.size = 100,
    this.strokeWidth = 8,
    this.showLabel = true,
    this.threshold,
  });

  @override
  State<ConfidenceMeter> createState() => _ConfidenceMeterState();
}

class _ConfidenceMeterState extends State<ConfidenceMeter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.confidence).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(ConfidenceMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.confidence != widget.confidence) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.confidence,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
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
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        final color = AppColors.getConfidenceColor(value);
        final percent = (value * 100).toStringAsFixed(0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _ConfidenceGaugePainter(
                  progress: value,
                  color: color,
                  strokeWidth: widget.strokeWidth,
                  threshold: widget.threshold,
                  isDark: Theme.of(context).brightness == Brightness.dark,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percent%',
                        style:
                            Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      if (widget.showLabel)
                        Text(
                          _getLabel(value),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: color.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getLabel(double value) {
    if (value >= 0.85) return 'Very High';
    if (value >= 0.75) return 'High';
    if (value >= 0.65) return 'Moderate';
    if (value >= 0.5) return 'Low';
    return 'Very Low';
  }
}

class _ConfidenceGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final double? threshold;
  final bool isDark;

  _ConfidenceGaugePainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    this.threshold,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -pi / 2;
    const sweepAngle = 2 * pi;

    // Background arc
    final bgPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      progressPaint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      glowPaint,
    );

    // Threshold marker
    if (threshold != null) {
      final thresholdAngle = startAngle + sweepAngle * threshold!;
      final markerRadius = radius + strokeWidth / 2 + 4;
      final markerStart = Offset(
        center.dx + (markerRadius - 8) * cos(thresholdAngle),
        center.dy + (markerRadius - 8) * sin(thresholdAngle),
      );
      final markerEnd = Offset(
        center.dx + (markerRadius + 4) * cos(thresholdAngle),
        center.dy + (markerRadius + 4) * sin(thresholdAngle),
      );

      final markerPaint = Paint()
        ..color = AppColors.warning
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(markerStart, markerEnd, markerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfidenceGaugePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.threshold != threshold;
}
