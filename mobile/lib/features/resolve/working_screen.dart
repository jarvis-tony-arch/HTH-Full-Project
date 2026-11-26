import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme.dart';
import 'cases_store.dart';
import 'clarify_screen.dart';
import 'fix_screen.dart';
import 'resolve_api.dart';
import 'widgets.dart';

/// Screen 3: short animated checklist while we call /resolve.
class WorkingScreen extends StatefulWidget {
  final String text;
  final String? section, company, issueType;
  const WorkingScreen({super.key, required this.text, this.section, this.company, this.issueType});
  @override
  State<WorkingScreen> createState() => _WorkingScreenState();
}

class _WorkingScreenState extends State<WorkingScreen> {
  static const _labels = [
    'Understanding your problem',
    'Checking your rights',
    'Finding the fastest fix',
  ];
  int _done = 0; // how many checklist items are ticked
  bool _slow = false;
  String? _error;
  Timer? _tick, _slowTimer;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _done = 0;
      _slow = false;
      _error = null;
    });
    _tick?.cancel();
    _slowTimer?.cancel();
    // Tick the first two items while we wait (the last waits for the answer).
    _tick = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted) return;
      if (_done < 2) setState(() => _done++);
    });
    _slowTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _slow = true);
    });

    final started = DateTime.now();
    try {
      final result = await ResolveApi.resolve(
        text: widget.text,
        section: widget.section,
        company: widget.company,
        issueType: widget.issueType,
      );
      // Keep the checklist visible for at least ~1.5s so it doesn't flash.
      final wait = const Duration(milliseconds: 1500) - DateTime.now().difference(started);
      if (wait > Duration.zero) await Future.delayed(wait);
      if (!mounted) return;
      _tick?.cancel();
      _slowTimer?.cancel();
      setState(() => _done = 3);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final nav = Navigator.of(context);
      if (result.needsClarification) {
        nav.pushReplacement(AppTheme.route(ClarifyScreen(
          text: widget.text,
          result: result,
          section: widget.section,
          company: widget.company,
          issueType: widget.issueType,
        )));
        return;
      }
      final cases = await context.read<CasesStore>().addFromResult(result, widget.text);
      if (!mounted) return;
      nav.pushReplacement(AppTheme.route(FixScreen(caseIds: cases.map((c) => c.id).toList())));
    } on FriendlyError catch (e) {
      _tick?.cancel();
      _slowTimer?.cancel();
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = AppColors.accent(widget.section);
    final reduce = AppTheme.reduceMotion(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _error != null ? _errorView(t, accent) : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Working on it…', style: t.headlineMedium),
              const SizedBox(height: 28),
              for (var i = 0; i < _labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: reduce ? 0 : 250),
                        transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                        child: i < _done
                            ? Icon(Icons.check_circle_rounded, key: const ValueKey('done'), color: AppColors.good, size: 32)
                            : (i == _done
                                ? Padding(
                                    key: const ValueKey('busy'),
                                    padding: const EdgeInsets.all(5),
                                    child: CircularProgressIndicator(strokeWidth: 3, color: accent),
                                  )
                                : const Icon(Icons.radio_button_unchecked_rounded,
                                    key: ValueKey('todo'), color: AppColors.line, size: 32)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(_labels[i],
                          style: t.titleMedium?.copyWith(
                              color: i <= _done ? AppColors.ink : AppColors.muted)),
                    ),
                  ]),
                ),
              if (_slow) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft(widget.section),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Icon(Icons.hourglass_top_rounded, color: accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Waking up the server, this takes a few seconds the first time.',
                          style: t.bodyMedium),
                    ),
                  ]),
                ).animate().fadeIn(duration: reduce ? 0.ms : 300.ms),
              ],
              const SizedBox(height: 28),
              // Shimmer preview of the result card that's coming.
              if (!reduce)
                Shimmer.fromColors(
                  baseColor: const Color(0xFFE9ECF3),
                  highlightColor: Colors.white,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _bar(220, 22),
                    const SizedBox(height: 14),
                    _bar(double.infinity, 16),
                    const SizedBox(height: 8),
                    _bar(260, 16),
                    const SizedBox(height: 20),
                    _bar(double.infinity, 56, r: 16),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(double w, double h, {double r = 8}) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(r)),
      );

  Widget _errorView(TextTheme t, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.muted),
        const SizedBox(height: 16),
        Text("We couldn't finish that", style: t.headlineMedium),
        const SizedBox(height: 10),
        Text(_error!, style: t.bodyLarge?.copyWith(color: AppColors.muted)),
        const Spacer(),
        FilledButton.icon(
          onPressed: _run,
          style: FilledButton.styleFrom(backgroundColor: accent),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Go back and edit'),
        ),
      ],
    ).gentleIn(context);
  }
}
