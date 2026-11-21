import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app/palette.dart';
import '../widgets/motion.dart';
import 'main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  final bool replay;
  const OnboardingScreen({super.key, this.replay = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pc = PageController();
  late final AnimationController _loop;
  int _page = 0;

  static const _titles = [
    'Describe it your way',
    'One message, many issues',
    'Right team, every time',
  ];
  static const _bodies = [
    'Type or speak in English, Hindi, Hinglish, Telugu, Tamil and more. No forms, no menus.',
    'HTH finds every problem hidden inside your message, not just the first one.',
    'Each issue goes to its own department, with a plain-language reason and a confidence score.',
  ];

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _loop.dispose();
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    if (!mounted) return;
    if (widget.replay) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  void _next() {
    if (_page == 2) {
      _finish();
    } else {
      _pc.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _illustration(int i) {
    switch (i) {
      case 0:
        return _IllustrationType(t: _loop);
      case 1:
        return _IllustrationSplit(t: _loop);
      default:
        return _IllustrationRoute(t: _loop);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pal.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _page = i),
                children: List.generate(3, (i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _illustration(i),
                        const SizedBox(height: 20),
                        FadeSlideIn(
                          delayMs: 150,
                          child: Text(
                            _titles[i],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FadeSlideIn(
                          delayMs: 300,
                          child: Text(
                            _bodies[i],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Pal.blue : Pal.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Pressable(
                onTap: _next,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Pal.blue, Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Pal.blue.withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _page == 2 ? 'Get started' : 'Next',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _chip(String text, Color c) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: c.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withOpacity(0.5)),
    ),
    child: Text(
      text,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Page 1: pulsing rings with floating multilingual message chips.
class _IllustrationType extends StatelessWidget {
  final Animation<double> t;
  const _IllustrationType({required this.t});

  Widget _ring(double p) {
    return Opacity(
      opacity: ((1 - p).clamp(0.0, 1.0)) * 0.5,
      child: Container(
        width: 84 + p * 200,
        height: 84 + p * 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Pal.blue, width: 1.5),
        ),
      ),
    );
  }

  Widget _bob(Offset base, double v, double phase, Widget child) {
    final dy = math.sin((v + phase) * 2 * math.pi) * 6;
    return Transform.translate(
      offset: Offset(base.dx, base.dy + dy),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final v = t.value;
        return SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 3; i++) _ring((v + i / 3) % 1.0),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Pal.blue,
                  boxShadow: [
                    BoxShadow(
                      color: Pal.blue.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: Colors.white, size: 42),
              ),
              _bob(const Offset(-45, -120), v, 0.0,
                  _chip('मेरा ऑर्डर नहीं आया', Pal.purple)),
              _bob(const Offset(55, 100), v, 0.33,
                  _chip('Mera order nhi aya', Pal.teal)),
              _bob(const Offset(-55, 62), v, 0.66,
                  _chip("My order hasn't arrived", Pal.blue)),
            ],
          ),
        );
      },
    );
  }
}

/// Page 2: one message splitting into three issues.
class _IllustrationSplit extends StatelessWidget {
  final Animation<double> t;
  const _IllustrationSplit({required this.t});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        final raw = (1 - math.cos(t.value * 2 * math.pi)) / 2;
        final s = Curves.easeInOutCubic.transform(raw);
        final items = <(String, IconData, Color)>[
          ('Delivery', Icons.local_shipping_rounded, Pal.blue),
          ('Payment', Icons.credit_card_rounded, Pal.red),
          ('Refund', Icons.reply_rounded, Pal.purple),
        ];
        return SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(-90, 0),
                child: Container(
                  width: 96,
                  height: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Pal.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Pal.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_rounded,
                          color: Pal.lightBlue, size: 28),
                      const SizedBox(height: 10),
                      for (final w in [60.0, 44.0, 52.0])
                        Container(
                          width: w,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 5),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              for (int i = 0; i < 3; i++)
                Transform.translate(
                  offset: Offset(62, (i - 1) * 72.0 * s),
                  child: Opacity(
                    opacity: 0.3 + 0.7 * s,
                    child: Container(
                      width: 112,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: items[i].$3.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                        border:
                            Border.all(color: items[i].$3.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(items[i].$2, color: items[i].$3, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            items[i].$1,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Page 3: issues routed to departments with moving dots.
class _IllustrationRoute extends StatelessWidget {
  final Animation<double> t;
  const _IllustrationRoute({required this.t});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, Color, String, IconData)>[
      ('Delivery', Pal.blue, 'Logistics', Icons.local_shipping_rounded),
      ('Payment', Pal.red, 'Payments', Icons.account_balance_rounded),
      ('Refund', Pal.purple, 'Refunds', Icons.currency_rupee_rounded),
    ];
    return AnimatedBuilder(
      animation: t,
      builder: (context, _) {
        return SizedBox(
          width: 300,
          height: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: SizedBox(
                    width: 300,
                    height: 48,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 10,
                          child: _chip(rows[i].$1, rows[i].$2),
                        ),
                        Positioned(
                          left: 108,
                          right: 108,
                          top: 23,
                          child: Container(height: 2, color: Colors.white12),
                        ),
                        Positioned(
                          left: 108 + ((t.value + i * 0.25) % 1.0) * 80,
                          top: 19,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: rows[i].$2,
                              boxShadow: [
                                BoxShadow(
                                  color: rows[i].$2.withOpacity(0.7),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 92,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Pal.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: rows[i].$2.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(rows[i].$4, color: rows[i].$2, size: 15),
                                const SizedBox(width: 5),
                                Text(
                                  rows[i].$3,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}