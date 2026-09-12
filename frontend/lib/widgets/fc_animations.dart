import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared motion helpers.
///
/// Every animated widget in this file honours the platform "reduce motion"
/// setting: when `MediaQuery.disableAnimations` is true the final value is
/// painted immediately with no tween. That keeps the UI accessible and stops
/// counters from being unreadable for motion-sensitive users.
bool _reducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// A number that counts up to [value] once, then stays put.
///
/// Uses a fixed duration and a decelerating curve so the last digits settle
/// rather than ticking mechanically.
class AnimatedCounter extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final Duration duration;
  final String Function(num)? formatter;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 900),
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final target = value;
    final text = formatter ?? _defaultFormat;

    if (_reducedMotion(context)) {
      return Text(text(target), style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) {
        // Snap to the exact value at the end so we never render 41.99999.
        final shown = (animated - target).abs() < 0.005 ? target : animated;
        return Text(text(shown), style: style);
      },
    );
  }

  static String _defaultFormat(num v) {
    if (v is double && v != v.roundToDouble()) return v.toStringAsFixed(1);
    return v.toInt().toString();
  }
}

/// A circular progress ring that fills from 0 to [percent] (0–100).
class ProgressRing extends StatelessWidget {
  final double percent;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color trackColor;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.percent,
    this.size = 64,
    this.strokeWidth = 6,
    this.color = FCColors.accent,
    this.trackColor = FCColors.white10,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100).toDouble();

    if (_reducedMotion(context)) {
      return _paint(clamped);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: clamped),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => _paint(value),
    );
  }

  Widget _paint(double value) {
    final children = <Widget>[
      CustomPaint(
        size: Size(size, size),
        painter: _RingPainter(
          percent: value,
          strokeWidth: strokeWidth,
          color: color,
          trackColor: trackColor,
        ),
      ),
    ];
    final centre = child;
    if (centre != null) children.add(centre);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: children,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double percent;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.percent,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (percent <= 0) return;

    final sweep = (percent / 100) * 2 * math.pi;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // A soft glow underneath the arc gives the ring some depth on dark cards.
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, glow);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [color, Color.lerp(color, Colors.white, 0.35)!],
      ).createShader(arcRect);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.percent != percent || old.color != color;
}

/// Recent-results strip: W / D / L pills, oldest → newest left to right.
class FormStrip extends StatelessWidget {
  final List<String> form;
  final double size;

  const FormStrip({super.key, required this.form, this.size = 22});

  static Color colorFor(String result) {
    switch (result.toUpperCase()) {
      case 'W': return FCColors.accent;
      case 'D': return FCColors.amber;
      case 'L': return FCColors.red;
      default: return FCColors.white30;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (form.isEmpty) {
      return Text(
        'No results yet',
        style: TextStyle(fontSize: 11, color: FCColors.white30),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: form.map((r) {
        final color = colorFor(r);
        return Container(
          width: size,
          height: size,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Text(
            r.toUpperCase(),
            style: TextStyle(
              fontSize: size * 0.45,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Two-sided comparison bar — used for head-to-head and team-vs-team panels.
///
/// [leftValue] and [rightValue] are raw numbers; the bar normalises them. When
/// both are zero it renders an honest empty track rather than a 50/50 split.
class ComparisonBar extends StatelessWidget {
  final String leftLabel;
  final num leftValue;
  final String rightLabel;
  final num rightValue;
  final Color leftColor;
  final Color rightColor;
  final String Function(num)? formatter;

  const ComparisonBar({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
    this.leftColor = FCColors.accent,
    this.rightColor = FCColors.blue,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final total = leftValue + rightValue;
    final leftShare = total == 0 ? 0.5 : leftValue / total;
    final fmt = formatter ?? (v) => v.toInt().toString();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(fmt(leftValue), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: leftColor)),
            Text(fmt(rightValue), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: rightColor)),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final leftWidth = width * leftShare;
            final bar = Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: FCColors.white05,
              ),
              child: Row(
                children: [
                  if (leftWidth > 0)
                    Container(
                      width: leftWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [leftColor, leftColor.withValues(alpha: 0.6)]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  if (width - leftWidth > 0)
                    Container(
                      width: width - leftWidth,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [rightColor.withValues(alpha: 0.6), rightColor]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            );
            if (_reducedMotion(context)) return bar;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: leftShare),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, animatedShare, _) {
                final lw = width * animatedShare;
                return Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: FCColors.white05,
                  ),
                  child: Row(
                    children: [
                      if (lw > 0)
                        Container(
                          width: lw,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [leftColor, leftColor.withValues(alpha: 0.6)]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      if (width - lw > 0)
                        Container(
                          width: width - lw,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [rightColor.withValues(alpha: 0.6), rightColor]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(leftLabel, style: TextStyle(fontSize: 11, color: FCColors.white50), overflow: TextOverflow.ellipsis)),
            Flexible(child: Text(rightLabel, style: TextStyle(fontSize: 11, color: FCColors.white50), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right)),
          ],
        ),
      ],
    );
  }
}

/// A compact trend line, drawn from a list of raw values.
///
/// Used for a team's points-per-match or a player's rating over time. Requires
/// at least two points; anything less renders a "not enough data" note so we
/// never imply a trend that isn't there.
class SparkLine extends StatelessWidget {
  final List<num> values;
  final Color color;
  final double height;
  final String? emptyLabel;

  const SparkLine({
    super.key,
    required this.values,
    this.color = FCColors.accent,
    this.height = 56,
    this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            emptyLabel ?? 'Not enough data for a trend',
            style: TextStyle(fontSize: 11, color: FCColors.white30),
          ),
        ),
      );
    }

    final painter = _SparkLinePainter(values: values, color: color);

    if (_reducedMotion(context)) {
      return SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: painter),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: painter.withProgress(progress)),
      ),
    );
  }
}

class _SparkLinePainter extends CustomPainter {
  final List<num> values;
  final Color color;
  final double progress;

  _SparkLinePainter({required this.values, required this.color, this.progress = 1});

  _SparkLinePainter withProgress(double p) =>
      _SparkLinePainter(values: values, color: color, progress: p);

  @override
  void paint(Canvas canvas, Size size) {
    final nums = values.map((e) => e.toDouble()).toList();
    final minV = nums.reduce(math.min);
    final maxV = nums.reduce(math.max);
    final span = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);

    final stepX = size.width / (nums.length - 1);
    Offset pointAt(int i) {
      final x = stepX * i;
      final normalised = (nums[i] - minV) / span;
      final y = size.height - (normalised * (size.height - 8)) - 4;
      return Offset(x, y);
    }

    // Clip horizontally so the line draws in left → right.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < nums.length; i++) {
      final prev = pointAt(i - 1);
      final curr = pointAt(i);
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    // Fill under the curve for a little depth.
    final fill = Path.from(path)
      ..lineTo(pointAt(nums.length - 1).dx, size.height)
      ..lineTo(pointAt(0).dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // End marker, revealed only once the line has caught up.
    if (progress > 0.98) {
      final last = pointAt(nums.length - 1);
      canvas.drawCircle(last, 3.4, Paint()..color = color);
      canvas.drawCircle(last, 6.5, Paint()..color = color.withValues(alpha: 0.25));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SparkLinePainter old) =>
      old.progress != progress || old.values != values;
}

/// Team crest: the uploaded logo when there is one, otherwise the team's
/// initials on a deterministic gradient so two teams never look alike.
class TeamLogo extends StatelessWidget {
  final String? logoUrl;
  final String initials;
  final double size;
  final double radius;

  const TeamLogo({
    super.key,
    this.logoUrl,
    required this.initials,
    this.size = 44,
    this.radius = 12,
  });

  /// Stable colour per team name, so a crest keeps the same tint everywhere.
  static const _palette = [
    [Color(0xFF2ECC71), Color(0xFF1B8A4A)],
    [Color(0xFF3498DB), Color(0xFF1F618D)],
    [Color(0xFF9B59B6), Color(0xFF6C3483)],
    [Color(0xFFF39C12), Color(0xFFB9770E)],
    [Color(0xFF1ABC9C), Color(0xFF117A65)],
    [Color(0xFFE74C3C), Color(0xFF922B21)],
    [Color(0xFFF5C542), Color(0xFFC9A020)],
  ];

  List<Color> get _gradient {
    if (initials.isEmpty) return _palette.first;
    final hash = initials.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[hash % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _gradient;

    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          logoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          // Fall back to the initials crest if the image fails to load, so a
          // broken URL never leaves a blank hole in the layout.
          errorBuilder: (_, _, _) => _initialsCrest(colors),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _initialsCrest(colors);
          },
        ),
      );
    }
    return _initialsCrest(colors);
  }

  Widget _initialsCrest(List<Color> colors) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Label + value tile used across the statistics centre.
class StatTile extends StatelessWidget {
  final String label;
  final num value;
  final IconData icon;
  final Color color;
  final String? suffix;
  final int decimals;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = FCColors.accent,
    this.suffix,
    this.decimals = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderColor: color.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedCounter(
                value: value,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                formatter: (v) => decimals > 0 ? v.toStringAsFixed(decimals) : v.toInt().toString(),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 3),
                Text(suffix!, style: TextStyle(fontSize: 11, color: FCColors.white30)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A slim animated bar, used for per-row metrics in tables and rankings.
class MetricBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;

  const MetricBar({
    super.key,
    required this.fraction,
    this.color = FCColors.accent,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    final target = fraction.clamp(0, 1).toDouble();

    Widget bar(double value) => Container(
          height: height,
          decoration: BoxDecoration(
            color: FCColors.white05,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.55)],
                ),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        );

    if (_reducedMotion(context)) return bar(target);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => bar(value),
    );
  }
}
