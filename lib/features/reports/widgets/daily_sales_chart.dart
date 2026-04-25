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
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: widget.dates
                .map(
                  (d) => Expanded(
                    child: Text(
                      DateFormat('E').format(d).toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
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
    final widthPerItem = constraints.maxWidth / (widget.dailyTotals.length - 1);
    final index = (localPosition.dx / widthPerItem).round().clamp(
      0,
      widget.dailyTotals.length - 1,
    );
    if (index != _hoveredIndex) {
      setState(() => _hoveredIndex = index);
    }
  }

  Widget _buildTooltip(BoxConstraints constraints, double maxVal) {
    final widthPerItem = constraints.maxWidth / (widget.dailyTotals.length - 1);
    final x = _hoveredIndex! * widthPerItem;
    final val = widget.dailyTotals[_hoveredIndex!];
    final y =
        constraints.maxHeight -
        (constraints.maxHeight * (val / (maxVal == 0 ? 1 : maxVal)));

    return Positioned(
      left: x - 40,
      top: y - 50,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '₹${val.toStringAsFixed(0)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
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

    final path = Path();
    final areaPath = Path();

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = i * widthPerItem;
      final y = size.height - (size.height * (data[i] / effectiveMax));
      points.add(Offset(x, y));
    }

    // 1. Fill Area with Gradient
    areaPath.moveTo(points[0].dx, size.height);
    for (int i = 0; i < points.length; i++) {
      if (i == 0) {
        areaPath.lineTo(points[i].dx, points[i].dy);
      } else {
        // Smooth Cubic Bezier
        final prev = points[i - 1];
        final curr = points[i];
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
    areaPath.lineTo(points.last.dx, size.height);
    areaPath.close();

    final paintArea = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.3 * animationValue),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(areaPath, paintArea);

    // 2. Draw the Smooth Line
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final controlX = (prev.dx + curr.dx) / 2;
      path.cubicTo(controlX, prev.dy, controlX, curr.dy, curr.dx, curr.dy);
    }

    final paintLine = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Animate path reveal
    // Note: To truly animate the reveal length we'd need a bit more logic,
    // but opacity + scale usually looks great for custom paints.
    canvas.drawPath(path, paintLine);

    // 3. Draw Dots
    final dotPaint = Paint()..color = primaryColor;
    final whitePaint = Paint()..color = Colors.white;
    final glowPaint = Paint()..color = primaryColor.withValues(alpha: 0.2);

    for (int i = 0; i < points.length; i++) {
      final isHovered = hoveredIndex == i;
      final radius = isHovered ? 6.0 : 4.0;

      canvas.drawCircle(points[i], radius + 4, glowPaint);
      canvas.drawCircle(points[i], radius, dotPaint);
      canvas.drawCircle(points[i], radius - 2, whitePaint);
    }
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}
