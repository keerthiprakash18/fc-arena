import 'package:flutter/material.dart';

/// Responsive primitives.
///
/// The brief is explicit that mobile must not simply be a shrunken desktop: a
/// phone gets a single column and full-width cards, while a wide screen gets
/// several columns and a bounded content width so text does not stretch into
/// unreadable lines.
class Breakpoints {
  /// Below this is a phone.
  static const double tablet = 600;

  /// At and above this is a desktop-class window.
  static const double desktop = 1100;

  /// Cards wider than this start to look sparse, so we add a column instead.
  static const double comfortableCardWidth = 380;

  /// Nothing should stretch wider than this; long measures are hard to read.
  static const double maxContentWidth = 1280;
}

enum FormFactor { mobile, tablet, desktop }

FormFactor formFactorOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= Breakpoints.desktop) return FormFactor.desktop;
  if (width >= Breakpoints.tablet) return FormFactor.tablet;
  return FormFactor.mobile;
}

/// True on phone-sized windows, where dense layouts need to stack.
bool isMobile(BuildContext context) => formFactorOf(context) == FormFactor.mobile;

/// Centres its child and caps its width on large screens.
///
/// Without this, a 2560px monitor stretches a card list across the whole window
/// and the layout reads as broken even though nothing is technically wrong.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Lays children out in as many columns as the width comfortably allows.
///
/// Uses [Wrap] rather than a grid so items keep their natural height — a card
/// with a long team name does not force its whole row taller.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = Breakpoints.comfortableCardWidth,
    this.maxColumns = 4,
    this.spacing = 12,
    this.runSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        // Guard against an unbounded or zero width during first layout.
        if (!available.isFinite || available <= 0) {
          return Column(children: children);
        }

        final fits = (available / minItemWidth).floor();
        final columns = fits.clamp(1, maxColumns);

        // A single column is the common phone case: skip the Wrap entirely so
        // children can use their full intrinsic width.
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }

        final itemWidth = (available - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

/// A horizontal metric row that becomes a wrapped block on narrow screens.
///
/// Statistics strips look fine side by side on a desktop and terrible squeezed
/// onto a phone, so the layout switches rather than shrinking.
class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double minItemWidth;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 12,
    this.minItemWidth = 150,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveGrid(
      minItemWidth: minItemWidth,
      maxColumns: children.length,
      spacing: spacing,
      runSpacing: spacing,
      children: children,
    );
  }
}
