import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailySalesChart extends StatefulWidget {
  final List<double> dailyTotals;
  final List<DateTime> dates;

  const DailySalesChart({
    super.key,
    required this.dailyTotals,
    required this.dates,
  });

  @override
  State<DailySalesChart> createState() => _DailySalesChartState();
}

class _DailySalesChartState extends State<DailySalesChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dailyTotals.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Not enough data for chart')),
      );
    }

    final maxVal = widget.dailyTotals.reduce((a, b) => a > b ? a : b);
    final theme = Theme.of(context);

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onPanUpdate: (details) =>
                      _updateHover(details.localPosition, constraints),
                  onTapDown: (details) =>
                      _updateHover(details.localPosition, constraints),
                  onPanEnd: (_) => setState(() => _hoveredIndex = null),
                  onTapUp: (_) => setState(() => _hoveredIndex = null),
                  child: Stack(
                    children: [
                      AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                            painter: LineChartPainter(
                              data: widget.dailyTotals,
                              maxVal: maxVal,
                              animationValue: _animation.value,
                              primaryColor: theme.colorScheme.primary,
                              hoveredIndex: _hoveredIndex,
                            ),
                          );
                        },
                      ),
                      if (_hoveredIndex != null &&
                          _hoveredIndex! < widget.dailyTotals.length)
                        _buildTooltip(constraints, maxVal),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: widget.dates
                .map(
                  (d) => Expanded(
                    child: Text(
                      DateFormat('E').format(d).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _updateHover(Offset localPosition, BoxConstraints constraints) {
    final widthPerItem =
        constraints.maxWidth / (widget.dailyTotals.length - 1);
    final index = (localPosition.dx / widthPerItem).round().clamp(
      0,
      widget.dailyTotals.length - 1,
    );
    if (index != _hoveredIndex) {
      setState(() => _hoveredIndex = index);
    }
  }

  Widget _buildTooltip(BoxConstraints constraints, double maxVal) {
    final widthPerItem =
        constraints.maxWidth / (widget.dailyTotals.length - 1);
    final x = _hoveredIndex! * widthPerItem;
    final val = widget.dailyTotals[_hoveredIndex!];
    final y = constraints.maxHeight -
        (constraints.maxHeight * (val / (maxVal == 0 ? 1 : maxVal)));

    final showLeft = x > constraints.maxWidth / 2;

    return Positioned(
      left: showLeft ? null : max(0, x - 36),
      right: showLeft ? max(0, constraints.maxWidth - x - 36) : null,
      top: max(0, y - 48),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('MMM dd').format(widget.dates[_hoveredIndex!]),
              style: TextStyle(
                fontSize: 8,
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '₹${val.toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final double maxVal;
  final double animationValue;
  final Color primaryColor;
  final int? hoveredIndex;

  LineChartPainter({
    required this.data,
    required this.maxVal,
    required this.animationValue,
    required this.primaryColor,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final double effectiveMax = maxVal == 0 ? 1 : maxVal;
    final double widthPerItem = size.width / (data.length - 1);

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * widthPerItem;
      final y = size.height - (size.height * (data[i] / effectiveMax));
      points.add(Offset(x, y));
    }

    final animatedLength = (data.length * animationValue).toInt();
    final visiblePoints = points.sublist(0, animatedLength);

    if (visiblePoints.isEmpty) return;

    final paintArea = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.25 * animationValue),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final areaPath = Path();
    areaPath.moveTo(visiblePoints.first.dx, size.height);
    for (int i = 0; i < visiblePoints.length; i++) {
      if (i == 0) {
        areaPath.lineTo(visiblePoints[i].dx, visiblePoints[i].dy);
      } else {
        final prev = visiblePoints[i - 1];
        final curr = visiblePoints[i];
        final controlX = (prev.dx + curr.dx) / 2;
        areaPath.cubicTo(
          controlX,
          prev.dy,
          controlX,
          curr.dy,
          curr.dx,
          curr.dy,
        );
      }
    }
    areaPath.lineTo(visiblePoints.last.dx, size.height);
    areaPath.close();
    canvas.drawPath(areaPath, paintArea);

    final linePath = Path();
    linePath.moveTo(visiblePoints.first.dx, visiblePoints.first.dy);
    for (int i = 1; i < visiblePoints.length; i++) {
      final prev = visiblePoints[i - 1];
      final curr = visiblePoints[i];
      final controlX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(
        controlX,
        prev.dy,
        controlX,
        curr.dy,
        curr.dx,
        curr.dy,
      );
    }

    final paintLine = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, paintLine);

    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final dotPaint = Paint()..color = primaryColor;
    final whitePaint = Paint()..color = Colors.white;

    for (int i = 0; i < visiblePoints.length; i++) {
      final isHovered = hoveredIndex == i;
      final radius = isHovered ? 6.0 : 3.5;

      if (isHovered) {
        canvas.drawCircle(visiblePoints[i], radius + 6, glowPaint);
      }
      canvas.drawCircle(visiblePoints[i], radius, dotPaint);
      canvas.drawCircle(visiblePoints[i], radius - 1.5, whitePaint);
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}
