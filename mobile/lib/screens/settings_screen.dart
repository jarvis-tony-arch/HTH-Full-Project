import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app/palette.dart';
import '../providers/settings_provider.dart';
import '../providers/tickets_provider.dart';
import '../services/api_service.dart';
import '../widgets/motion.dart';
import 'onboarding_screen.dart';

enum _Conn { idle, checking, ok, fail }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url;
  _Conn _conn = _Conn.idle;

  static const _locales = <String, String>{
    'en_IN': 'English (India)',
    'hi_IN': 'Hindi',
    'te_IN': 'Telugu',
    'ta_IN': 'Tamil',
    'kn_IN': 'Kannada',
    'ml_IN': 'Malayalam',
    'mr_IN': 'Marathi',
    'bn_IN': 'Bengali',
  };

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: ApiService.baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    setState(() => _conn = _Conn.checking);
    await ApiService.setBaseUrl(_url.text);
    final ok = await ApiService.health();
    if (!mounted) return;
    setState(() => _conn = ok ? _Conn.ok : _Conn.fail);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final threshold = s.confidenceThreshold;

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          FadeSlideIn(
            child: Text('Settings',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 18),

          // ── Connection ──
          FadeSlideIn(
            delayMs: 80,
            child: _section(
              'AI backend connection',
              Icons.cloud_sync_rounded,
              Pal.blue,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'http://192.168.1.5:8000',
                      hintStyle: GoogleFonts.inter(
                          color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: Pal.bg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Pal.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Pal.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Pal.blue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'On a real phone use your laptop\'s Wi-Fi IP (not 127.0.0.1) or a tunnel URL.',
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Pressable(
                        onTap: _test,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Pal.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('Save & test',
                              style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _connBadge(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── AI behaviour ──
          FadeSlideIn(
            delayMs: 160,
            child: _section(
              'Confidence threshold',
              Icons.tune_rounded,
              Pal.amber,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Cases below this confidence go to a human agent instead of being auto-routed.',
                          style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 12,
                              height: 1.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('${(threshold * 100).round()}%',
                          style: GoogleFonts.inter(
                              color: Pal.amber,
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Pal.amber,
                      inactiveTrackColor: Pal.border,
                      thumbColor: Pal.amber,
                      overlayColor: Pal.amber.withOpacity(0.15),
                    ),
                    child: Slider(
                      value: threshold,
                      min: 0.5,
                      max: 0.9,
                      divisions: 8,
                      onChanged: (v) =>
                          context.read<SettingsProvider>().setThreshold(v),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('More automation',
                          style: GoogleFonts.inter(
                              color: Colors.white30, fontSize: 10)),
                      Text('More human review',
                          style: GoogleFonts.inter(
                              color: Colors.white30, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Voice ──
          FadeSlideIn(
            delayMs: 240,
            child: _section(
              'Voice input',
              Icons.mic_rounded,
              Pal.teal,
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Enable microphone button',
                            style: GoogleFonts.inter(
                                color: Colors.white70, fontSize: 13)),
                      ),
                      Switch(
                        value: s.voiceEnabled,
                        activeColor: Pal.teal,
                        onChanged: (v) =>
                            context.read<SettingsProvider>().setVoiceEnabled(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Speaking language',
                            style: GoogleFonts.inter(
                                color: Colors.white70, fontSize: 13)),
                      ),
                      DropdownButton<String>(
                        value: _locales.containsKey(s.voiceLocale)
                            ? s.voiceLocale
                            : 'en_IN',
                        dropdownColor: Pal.card,
                        underline: const SizedBox.shrink(),
                        style: GoogleFonts.inter(
                            color: Pal.lightBlue,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        items: [
                          for (final e in _locales.entries)
                            DropdownMenuItem(
                                value: e.key, child: Text(e.value)),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            context.read<SettingsProvider>().setVoiceLocale(v);
                          }
                        },
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Speech recognition uses your phone\'s built-in engine, so available languages depend on the device.',
                      style: GoogleFonts.inter(
                          color: Colors.white30, fontSize: 11, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Data ──
          FadeSlideIn(
            delayMs: 320,
            child: _section(
              'Data & demo',
              Icons.storage_rounded,
              Pal.purple,
              Column(
                children: [
                  _action(
                    Icons.dataset_rounded,
                    'Load sample tickets',
                    'Adds 8 labelled sample tickets (DEMO-xxx)',
                    Pal.purple,
                    () {
                      context.read<TicketsProvider>().addDemoData();
                      _toast('Sample tickets added');
                    },
                  ),
                  _action(
                    Icons.slideshow_rounded,
                    'Replay intro',
                    'Show the onboarding screens again',
                    Pal.blue,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingScreen(replay: true),
                      ),
                    ),
                  ),
                  _action(
                    Icons.delete_outline_rounded,
                    'Clear all tickets',
                    'Removes every ticket from this device',
                    Pal.red,
                    _confirmClear,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Column(
              children: [
                Text('HTH Smart Support Intelligence · v1.0.0',
                    style: GoogleFonts.inter(
                        color: Colors.white30, fontSize: 11)),
                const SizedBox(height: 4),
                Text('Team HTH · Abhijith Reddy · Harsha Vardhan · Surya Shah',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                        color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _connBadge() {
    switch (_conn) {
      case _Conn.checking:
        return Row(
          key: const ValueKey('checking'),
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Text('Checking…',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
          ],
        );
      case _Conn.ok:
        return Row(
          key: const ValueKey('ok'),
          children: [
            const Icon(Icons.check_circle_rounded, color: Pal.green, size: 18),
            const SizedBox(width: 6),
            Text('Connected',
                style: GoogleFonts.inter(
                    color: Pal.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        );
      case _Conn.fail:
        return Row(
          key: const ValueKey('fail'),
          children: [
            const Icon(Icons.error_rounded, color: Pal.red, size: 18),
            const SizedBox(width: 6),
            Text('Cannot reach server',
                style: GoogleFonts.inter(
                    color: Pal.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        );
      case _Conn.idle:
        return const SizedBox.shrink(key: ValueKey('idle'));
    }
  }

  Widget _section(String title, IconData icon, Color c, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c, size: 16),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _action(IconData icon, String title, String sub, Color c,
      VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.withOpacity(0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(sub,
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Pal.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Pal.card,
        title: Text('Clear all tickets?',
            style: GoogleFonts.inter(color: Colors.white)),
        content: Text('This cannot be undone.',
            style: GoogleFonts.inter(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Pal.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<TicketsProvider>().clearAll();
      _toast('All tickets cleared');
    }
  }
}