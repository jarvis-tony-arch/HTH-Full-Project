import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../features/resolve/home_screen.dart';
import 'main_shell.dart';
import 'onboarding_screen.dart';

/// Old entry point, kept for the "Company triage mode" link on Home.
/// These screens keep the app's original dark theme.
Future<void> openTriageMode(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final seen = prefs.getBool('onboarded') ?? false;
  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: seen ? const MainShell() : const OnboardingScreen(),
    ),
  ));
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1200), _goHome);
  }

  /// The simple "get help" Home is the front door now. The old company
  /// triage mode (onboarding + MainShell) is one small link away on Home.
  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            Theme(data: AppTheme.light, child: const ResolveHomeScreen()),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnim,
              child: Transform.translate(
                offset: Offset(0, _slideAnim.value),
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo container
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.4),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          size: 58,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 36),
                      // HTH text
                      Text(
                        'HTH',
                        style: GoogleFonts.inter(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 10,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Subtitle
                      Text(
                        'Smart Support Intelligence',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.55),
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Powered by NLP tag
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF2563EB).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          'Powered by NLP',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF60A5FA),
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),
                      // Loading indicator
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}