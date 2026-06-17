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
      duration: const Duration(milliseconds: 1000),
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
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    final widthPerItem = constraints.maxWidth / widget.dailyTotals.length;
                    final index = (details.localPosition.dx / widthPerItem).floor().clamp(
                      0,
                      widget.dailyTotals.length - 1,
                    );
                    if (index != _hoveredIndex) {
                      setState(() => _hoveredIndex = index);
                    }
                  },
                  onTapDown: (details) {
                    final widthPerItem = constraints.maxWidth / widget.dailyTotals.length;
                    final index = (details.localPosition.dx / widthPerItem).floor().clamp(
                      0,
                      widget.dailyTotals.length - 1,
                    );
                    setState(() {
                      if (_hoveredIndex == index) {
                        _hoveredIndex = null;
                      } else {
                        _hoveredIndex = index;
                      }
                    });
                  },
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
                            painter: BarChartPainter(
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

  Widget _buildTooltip(BoxConstraints constraints, double maxVal) {
    final widthPerItem = constraints.maxWidth / widget.dailyTotals.length;
    final x = _hoveredIndex! * widthPerItem + (widthPerItem / 2);
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

class BarChartPainter extends CustomPainter {
  final List<double> data;
  final double maxVal;
  final double animationValue;
  final Color primaryColor;
  final int? hoveredIndex;

  BarChartPainter({
    required this.data,
    required this.maxVal,
    required this.animationValue,
    required this.primaryColor,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final double effectiveMax = maxVal == 0 ? 1 : maxVal;
    final double totalWidth = size.width;
    final double numBars = data.length.toDouble();

    // Calculate width of each bar and spacing
    final double barWidth = (totalWidth / numBars) * 0.6; // 60% of slot width
    final double spacing = (totalWidth / numBars) * 0.4; // 40% of slot width

    for (int i = 0; i < data.length; i++) {
      final double val = data[i];
      final double barHeight = size.height * (val / effectiveMax) * animationValue;

      final double left = i * (barWidth + spacing) + (spacing / 2);
      final double top = size.height - barHeight;
      final double right = left + barWidth;
      final double bottom = size.height;

      final rect = Rect.fromLTRB(left, top, right, bottom);
      // Give the bar rounded top corners
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      );

      final isHovered = hoveredIndex == i;

      // Paint with a beautiful vertical gradient
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            isHovered ? primaryColor : primaryColor.withValues(alpha: 0.85),
            primaryColor.withValues(alpha: isHovered ? 0.4 : 0.15),
          ],
        ).createShader(rect);

      canvas.drawRRect(rrect, paint);

      // If hovered, draw a subtle highlight border/glow
      if (isHovered) {
        final borderPaint = Paint()
          ..color = primaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRRect(rrect, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BarChartPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}
