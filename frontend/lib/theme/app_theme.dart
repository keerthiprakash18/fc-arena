import 'package:flutter/material.dart';

class FCColors {
  FCColors._();

  static const Color pitch = Color(0xFF0D1B0E);
  static const Color pitchLight = Color(0xFF1A2E1C);
  static const Color surface = Color(0xFF141E15);
  static const Color surfaceLight = Color(0xFF1E2D1F);
  static const Color surfaceCard = Color(0xFF1A2A1C);
  static const Color accent = Color(0xFF2ECC71);
  static const Color accentBright = Color(0xFF4ADE80);
  static const Color accentDark = Color(0xFF1B8A4A);
  static const Color gold = Color(0xFFF5C542);
  static const Color goldDark = Color(0xFFC9A020);
  static const Color white = Colors.white;
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white50 = Color(0x80FFFFFF);
  static const Color white30 = Color(0x4DFFFFFF);
  static const Color white15 = Color(0x26FFFFFF);
  static const Color white10 = Color(0x1AFFFFFF);
  static const Color white05 = Color(0x0DFFFFFF);
  static const Color red = Color(0xFFE74C3C);
  static const Color amber = Color(0xFFF39C12);
  static const Color blue = Color(0xFF3498DB);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color purple = Color(0xFF9B59B6);
  static const Color teal = Color(0xFF1ABC9C);
  static const Color divider = Color(0x1A2ECC71);
  static const Color shimmer = Color(0x1A2ECC71);
}

class FCGradients {
  FCGradients._();

  static const LinearGradient pitch = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D1B0E), Color(0xFF0A120B)],
  );

  static const LinearGradient card = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2A1C), Color(0xFF141E15)],
  );

  static const LinearGradient accent = LinearGradient(
    colors: [Color(0xFF2ECC71), Color(0xFF1B8A4A)],
  );

  static const LinearGradient gold = LinearGradient(
    colors: [Color(0xFFF5C542), Color(0xFFC9A020)],
  );

  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2ECC71), Color(0xFF1B8A4A), Color(0xFF0D1B0E)],
  );

  static const LinearGradient statusBar = LinearGradient(
    colors: [Color(0xFF0D1B0E), Color(0xFF141E15)],
  );
}

class FCTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: FCColors.accent,
        onPrimary: FCColors.white,
        secondary: FCColors.gold,
        surface: FCColors.surface,
        onSurface: FCColors.white,
      ),
      scaffoldBackgroundColor: FCColors.pitch,
      appBarTheme: const AppBarTheme(
        backgroundColor: FCColors.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: FCColors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: FCColors.white),
      ),
      cardTheme: CardThemeData(
        color: FCColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: FCColors.white10, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FCColors.accent,
          foregroundColor: FCColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FCColors.accent,
          side: const BorderSide(color: FCColors.accent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FCColors.white05,
        hintStyle: const TextStyle(color: FCColors.white30),
        labelStyle: const TextStyle(color: FCColors.white50),
        prefixIconColor: FCColors.white30,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FCColors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FCColors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FCColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: FCColors.red),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: FCColors.surface,
        indicatorColor: FCColors.accent.withValues(alpha: 0.2),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: FCColors.accent, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: FCColors.white30, fontSize: 11);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: FCColors.surfaceCard,
        contentTextStyle: const TextStyle(color: FCColors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: FCColors.divider,
        thickness: 0.5,
        space: 0,
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FCColors.surfaceCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? FCColors.white10, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class PitchDivider extends StatelessWidget {
  const PitchDivider({super.key});

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

class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool small;

  const StatusBadge({super.key, required this.text, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: small ? 9 : 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class FCSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const FCSectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: FCColors.white50,
            letterSpacing: 2,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
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
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: FCColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: FCColors.accent.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, size: 36, color: FCColors.accent.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: FCColors.white70)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: FCColors.white30), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorRetry({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: FCColors.white15),
            const SizedBox(height: 16),
            Text('Something went wrong', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: FCColors.white70)),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(fontSize: 13, color: FCColors.white30), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
