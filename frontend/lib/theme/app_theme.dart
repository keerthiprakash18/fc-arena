import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// FC HARINA — PREMIUM FOOTBALL TOURNAMENT PLATFORM THEME
// Inspired by premium sports apps: deep navy/purple gradients, clean typography,
// professional cards, football-focused visual language.
// ═════════════════════════════════════════════════════════════════════════════

class FCColors {
  FCColors._();

  // ── Backgrounds ───────────────────────────────────────
  static const Color pitch = Color(0xFF070B14);         // deepest navy-black
  static const Color pitchLight = Color(0xFF0D1321);    // slightly lighter
  static const Color surface = Color(0xFF0F1729);       // card/surface bg
  static const Color surfaceLight = Color(0xFF151D30);  // elevated surface
  static const Color surfaceCard = Color(0xFF111A2E);   // card fill

  // ── Primary Accent (Electric Sky) ────────────────────
  static const Color accent = Color(0xFF00D4AA);        // teal-green (pitch grass)
  static const Color accentBright = Color(0xFF00F5C4);  // bright teal
  static const Color accentDark = Color(0xFF00B894);    // deeper teal
  static const Color accentGlow = Color(0x4000D4AA);    // glow shadow

  // ── Secondary Accent (Stadium Gold) ──────────────────
  static const Color gold = Color(0xFFFFD700);          // trophy gold
  static const Color goldDark = Color(0xFFD4AF37);      // deeper gold
  static const Color goldGlow = Color(0x40FFD700);      // gold glow

  // ── Tertiary (Stadium Purple) ────────────────────────
  static const Color purple = Color(0xFF8B5CF6);        // stadium light purple
  static const Color purpleDark = Color(0xFF6D28D9);    // deep purple

  // ── Functional ───────────────────────────────────────
  static const Color white = Colors.white;
  static const Color white80 = Color(0xCCFFFFFF);
  static const Color white60 = Color(0x99FFFFFF);
  static const Color white40 = Color(0x66FFFFFF);
  static const Color white20 = Color(0x33FFFFFF);
  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white05 = Color(0x0DFFFFFF);

  // Backward-compatible aliases (old names → new names)
  static const Color white70 = white80;
  static const Color white50 = white60;
  static const Color white30 = white40;
  static const Color white15 = white20;

  static const Color red = Color(0xFFFF4757);
  static const Color redDark = Color(0xFFDC3545);
  static const Color amber = Color(0xFFFFA502);
  static const Color blue = Color(0xFF3498DB);
  static const Color cyan = Color(0xFF00D2D3);
  static const Color teal = Color(0xFF1DD1A1);
  static const Color green = Color(0xFF2ED573);

  // ── Overlays ─────────────────────────────────────────
  static const Color divider = Color(0x15FFFFFF);
  static const Color shimmer = Color(0x1A00D4AA);
  static const Color glassOverlay = Color(0x1AFFFFFF);
}

class FCGradients {
  FCGradients._();

  /// Main app background — deep navy to black
  static const LinearGradient pitch = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1428), Color(0xFF070B14)],
  );

  /// Hero/landing gradient — navy to deep purple
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1428), Color(0xFF1a103c), Color(0xFF070B14)],
  );

  /// Card surface gradient
  static const LinearGradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF151D30), Color(0xFF0F1729)],
  );

  /// Primary accent gradient (teal)
  static const LinearGradient accent = LinearGradient(
    colors: [Color(0xFF00F5C4), Color(0xFF00D4AA), Color(0xFF00B894)],
  );

  /// Gold accent gradient
  static const LinearGradient gold = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFD4AF37)],
  );

  /// Stadium light effect — purple to teal
  static const LinearGradient stadium = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF00D4AA)],
  );

  /// Pitch line gradient
  static const LinearGradient pitchLine = LinearGradient(
    colors: [Color(0x0000D4AA), Color(0x4000D4AA), Color(0x0000D4AA)],
  );
}

class FCTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: FCColors.accent,
        onPrimary: FCColors.pitch,
        secondary: FCColors.gold,
        onSecondary: FCColors.pitch,
        surface: FCColors.surface,
        onSurface: FCColors.white,
        error: FCColors.red,
        onError: FCColors.white,
      ),
      scaffoldBackgroundColor: FCColors.pitch,
      fontFamily: 'Inter',

      // ── AppBar ───────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: FCColors.surface.withValues(alpha:0.95),
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: const TextStyle(
          color: FCColors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: FCColors.white80),
      ),

      // ── Cards ────────────────────────────────────────
      cardTheme: CardThemeData(
        color: FCColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: FCColors.white10, width: 1),
        ),
      ),

      // ── Buttons ──────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FCColors.accent,
          foregroundColor: FCColors.pitch,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FCColors.accent,
          side: const BorderSide(color: FCColors.accent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FCColors.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),

      // ── Inputs ───────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FCColors.white05,
        hintStyle: const TextStyle(color: FCColors.white40, fontSize: 14),
        labelStyle: const TextStyle(color: FCColors.white60, fontSize: 14),
        prefixIconColor: FCColors.white40,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FCColors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FCColors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FCColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: FCColors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),

      // ── Navigation ───────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FCColors.surface.withValues(alpha:0.95),
        indicatorColor: FCColors.accent.withValues(alpha:0.15),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: FCColors.accent, fontSize: 11, fontWeight: FontWeight.w700);
          }
          return const TextStyle(color: FCColors.white40, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: FCColors.accent, size: 24);
          }
          return const IconThemeData(color: FCColors.white40, size: 24);
        }),
      ),

      // ── SnackBar ─────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FCColors.surfaceLight,
        contentTextStyle: const TextStyle(color: FCColors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
        elevation: 8,
      ),

      // ── Divider ──────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: FCColors.divider,
        thickness: 1,
        space: 1,
      ),

      // ── Dialog ───────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: FCColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
      ),

      // ── Bottom Sheet ─────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: FCColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PREMIUM WIDGET COMPONENTS
// ═════════════════════════════════════════════════════════════════════════════

/// A premium glass-morphism card with subtle border and shadow
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.borderColor,
    this.gradient,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient ?? FCGradients.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? FCColors.white10, width: 1),
        boxShadow: boxShadow ?? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: FCColors.accent.withValues(alpha: 0.03),
              blurRadius: 40,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: child,
    );
  }
}

/// A premium action button with gradient background
class FCActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isSecondary;
  final bool isFullWidth;
  final double height;

  const FCActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isSecondary = false,
    this.isFullWidth = true,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 10),
        ],
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );

    if (isSecondary) {
      return SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: height,
        child: OutlinedButton(
          onPressed: onPressed,
          child: child,
        ),
      );
    }

    return Container(
      width: isFullWidth ? double.infinity : null,
      height: height,
      decoration: BoxDecoration(
        gradient: FCGradients.accent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: FCColors.accentGlow.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// A premium stat/chip badge
class FCStatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool small;
  final IconData? icon;

  const FCStatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.small = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha:0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: small ? 10 : 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// A premium section header with accent line
class FCSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final bool showAccent;

  const FCSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.showAccent = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showAccent) ...[
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: FCGradients.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: FCColors.white60,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

/// Alias for backward compatibility
@Deprecated('Use FCEmptyState')
typedef EmptyState = FCEmptyState;

/// Alias for backward compatibility
@Deprecated('Use FCStatusBadge')
typedef StatusBadge = FCStatusBadge;

/// Alias for backward compatibility
@Deprecated('Use FCErrorRetry')
typedef ErrorRetry = FCErrorRetry;

/// Alias for backward compatibility
@Deprecated('Use PitchDivider')
typedef PitchDivider = _PitchDivider;

class _PitchDivider extends StatelessWidget {
  const _PitchDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FCColors.accent.withValues(alpha: 0),
            FCColors.accent.withValues(alpha: 0.3),
            FCColors.accent.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

/// A premium empty state with illustration
class FCEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const FCEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FCColors.accent.withValues(alpha:0.15),
                    FCColors.purple.withValues(alpha:0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: FCColors.accent.withValues(alpha:0.15)),
              ),
              child: Icon(icon, size: 44, color: FCColors.accent.withValues(alpha:0.6)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: FCColors.white80,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: FCColors.white40, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 28), action!],
          ],
        ),
      ),
    );
  }
}

/// A premium error state with retry
class FCErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const FCErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: FCColors.red.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.error_outline, size: 40, color: FCColors.red),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FCColors.white80),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(fontSize: 14, color: FCColors.white40),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FCActionButton(
              label: 'TRY AGAIN',
              onPressed: onRetry,
              icon: Icons.refresh,
              isFullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}

/// A premium info/stat row
class FCInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  const FCInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor ?? FCColors.white40),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: FCColors.white40),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: FCColors.white80,
          ),
        ),
      ],
    );
  }
}

/// Animated gradient border container
class FCGradientBorder extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final EdgeInsetsGeometry? padding;

  const FCGradientBorder({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.borderWidth = 1.5,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4AA), Color(0xFF8B5CF6)],
        ),
      ),
      child: Container(
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: FCColors.pitch,
          borderRadius: BorderRadius.circular(borderRadius - borderWidth),
        ),
        child: child,
      ),
    );
  }
}
