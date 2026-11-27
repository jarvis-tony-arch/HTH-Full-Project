import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours for the review analyser. Navy text on off-white (dark mode too),
/// one brand accent, and green/amber/red ONLY for verdicts.
class RC {
  final Color bg, card, ink, muted, line, accent, accentSoft;
  final bool dark;
  const RC._(this.bg, this.card, this.ink, this.muted, this.line, this.accent, this.accentSoft, this.dark);

  static const light = RC._(Color(0xFFF7F6F2), Colors.white, Color(0xFF14213D), Color(0xFF5C6680),
      Color(0xFFE4E3DC), Color(0xFF3557D6), Color(0xFFE8EDFC), false);
  static const darkTheme = RC._(Color(0xFF0E1525), Color(0xFF172036), Color(0xFFE8ECF6), Color(0xFF9AA4BC),
      Color(0xFF263150), Color(0xFF7D97FF), Color(0xFF1F2A4D), true);

  static RC of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? darkTheme : light;

  // Verdict colours (used for nothing else).
  static const good = Color(0xFF1E8E4E);
  static const caution = Color(0xFFB7791F);
  static const bad = Color(0xFFC53030);
  static const grey = Color(0xFF7A8296);

  static Color verdict(String? c) => switch (c) {
        'green' => good,
        'amber' => caution,
        'red' => bad,
        _ => grey,
      };
}

ThemeData reviewTheme(Brightness b) {
  final c = b == Brightness.dark ? RC.darkTheme : RC.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(seedColor: c.accent, brightness: b, surface: c.bg, primary: c.accent),
    scaffoldBackgroundColor: c.bg,
  );
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(bodyColor: c.ink, displayColor: c.ink);
  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16.5, height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.45, color: c.ink),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: (c.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: c.bg,
        systemNavigationBarIconBrightness: c.dark ? Brightness.light : Brightness.dark,
      ),
      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w700, color: c.ink),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: c.line)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.dark ? const Color(0xFF0E1525) : Colors.white,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(48, 50),
        side: BorderSide(color: c.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: GoogleFonts.plusJakartaSans(color: c.muted, fontSize: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.line, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.accent, width: 2)),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}

/// Pushes a review-analyser screen with the light or dark theme to match the phone.
Route<T> reviewRoute<T>(Widget page) => MaterialPageRoute<T>(
      builder: (context) => Theme(
        data: reviewTheme(MediaQuery.platformBrightnessOf(context)),
        child: page,
      ),
    );

bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Staggered fade + slide in, ≤ 350ms, off with reduce-motion.
class Appear extends StatefulWidget {
  final Widget child;
  final int index;
  const Appear({super.key, required this.child, this.index = 0});
  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      Future.delayed(Duration(milliseconds: 50 * widget.index.clamp(0, 8)), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a), child: widget.child),
    );
  }
}

/// A number that counts up (≤ 400ms).
class CountUp extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle? style;
  const CountUp({super.key, required this.value, required this.format, this.style});
  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(format(v), style: style),
    );
  }
}

/// A bar that fills to [value] (0..1) once (≤ 400ms).
class FillBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color? back;
  final double height;
  const FillBar({super.key, required this.value, required this.color, this.back, this.height = 10});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    Widget bar(double v) => ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Stack(children: [
            Container(height: height, color: back ?? c.line),
            FractionallySizedBox(widthFactor: v.clamp(0, 1), child: Container(height: height, color: color)),
          ]),
        );
    if (reduceMotion(context)) return bar(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => bar(v),
    );
  }
}
