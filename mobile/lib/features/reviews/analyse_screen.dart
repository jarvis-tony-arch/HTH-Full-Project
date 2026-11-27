import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import 'history_store.dart';
import 'rtheme.dart';
import 'analysis_job.dart';
import 'collector.dart';
import 'cross_platform.dart';
import 'link_parser.dart';
import 'models.dart';
import 'page_reader.dart';
import 'result_screen.dart';

/// Share → this screen: progress while the phone reads reviews, then the result.
class AnalyseScreen extends StatefulWidget {
  final String sharedText;
  const AnalyseScreen({super.key, required this.sharedText});
  @override
  State<AnalyseScreen> createState() => _AnalyseScreenState();
}

class _AnalyseScreenState extends State<AnalyseScreen> {
  late final AnalysisJob job = AnalysisJob(widget.sharedText);
  final Map<PageReader, GlobalKey> _keys = {};
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    job.addListener(_onJob);
    job.start();
  }

  void _onJob() {
    if (!mounted) return;
    if (job.stage == JobStage.done && !_opened && job.analysis != null) {
      _opened = true;
      final result = job.analysis!;
      final l = job.link;
      context.read<HistoryStore>().add(SavedAnalysis(
            id: '${l?.platform.name}_${l?.productId}',
            savedAt: DateTime.now(),
            result: result,
          ));
      Navigator.of(context).pushReplacement(reviewRoute(ResultScreen(result: result)));
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    job.removeListener(_onJob);
    job.dispose();
    super.dispose();
  }

  Widget _webView(PageReader r) => KeyedSubtree(
        key: _keys.putIfAbsent(r, GlobalKey.new),
        child: WebViewWidget(controller: r.controller),
      );

  @override
  Widget build(BuildContext context) {
    final handoff = job.handoffs.isEmpty ? null : job.handoffs.first;
    return PopScope(
      canPop: handoff == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) handoff?.skip();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(handoff == null ? 'Checking reviews' : handoff.source.link.platform.label)),
        body: SafeArea(
          top: false,
          child: Stack(children: [
            // Web views stay in the tree, hidden under the progress screen, so
            // pages keep loading. The one that needs the user is brought up.
            for (final r in job.allReaders)
              if (r != handoff?.reader) Positioned.fill(child: _webView(r)),
            Positioned.fill(
              child: handoff == null
                  ? ColoredBox(color: RC.of(context).bg, child: _progress(context))
                  : _handoffView(context, handoff),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _handoffView(BuildContext context, Handoff h) {
    final signIn = h.reason.contains('signin') || h.reason.contains('login');
    final shop = h.source.link.platform.label;
    return ColoredBox(
      color: RC.of(context).bg,
      child: Column(children: [
        Container(
          width: double.infinity,
          color: RC.caution.withValues(alpha: 0.14),
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, color: RC.caution),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                signIn
                    ? '$shop asks you to sign in to show all reviews. Sign in yourself, or skip and we\'ll use the reviews we already have.'
                    : '$shop wants to check you\'re a person. Please complete it yourself, or skip.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(onPressed: h.skip, child: const Text('Skip')),
          ]),
        ),
        Expanded(child: _webView(h.reader)),
      ]),
    );
  }

  Widget _progress(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (job.stage == JobStage.failed) {
      if (job.problem != null) {
        return Padding(padding: const EdgeInsets.all(24), child: UnsupportedLink(message: job.problem!));
      }
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_off_rounded, size: 56, color: RC.of(context).muted),
          const SizedBox(height: 16),
          Text(job.analysisError ?? 'Something went wrong.', textAlign: TextAlign.center, style: t.titleMedium),
          const SizedBox(height: 24),
          FilledButton(onPressed: job.retryAnalysis, child: const Text('Try again')),
        ]),
      );
    }
    final meta = job.main?.meta;
    final early = job.stage == JobStage.reading || job.stage == JobStage.link;
    final reading = early && (job.sources.isEmpty ||
        job.sources.any((s) => s.state == SourceState.reading || s.state == SourceState.waiting || s.state == SourceState.needsUser));
    final searching = early && !reading;
    final steps = [
      (_Step.reading, reading ? 'Reading reviews… ${job.total} found' : 'Read ${job.total} reviews'),
      (_Step.shops, searching ? 'Looking for it on other shops…' : 'Checked other shops'),
      (_Step.buyers, 'Checking what buyers say'),
      (_Step.genuine, 'Checking if reviews are genuine'),
    ];
    final current = reading ? 0 : searching ? 1 : job.stage == JobStage.analysing ? 2 : 4;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
      if (meta != null && meta.title.isNotEmpty)
        _ProductHeader(meta: meta)
      else if (job.link != null)
        Text('${job.link!.platform.label} product', style: t.titleMedium)
      else
        Text('Opening the product link…', style: t.titleMedium),
      const SizedBox(height: 20),
      for (var i = 0; i < steps.length; i++)
        _StepRow(
          label: steps[i].$2,
          state: i < current ? _StepState.done : i == current ? _StepState.active : _StepState.waiting,
        ),
      if (job.questions.isNotEmpty) ...[
        const SizedBox(height: 16),
        for (final q in job.questions) _SameProductCard(m: q, onAnswer: (v) => job.answer(q, v)),
      ],
      const SizedBox(height: 20),
      if (job.sources.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('SHOPS', style: TextStyle(fontSize: 13, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: RC.of(context).muted)),
        ),
      for (final s in job.sources) _SourceRow(s),
      for (final e in job.shopSearch.entries)
        if (!job.sources.any((s) => s.platform == e.key))
          _SearchRow(platform: e.key, state: e.value, matched: job.matches.any((m) => m.listing.platform == e.key && m.confirmed)),
      if (job.total < minReviews && job.stage == JobStage.analysing)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('Only ${job.total} reviews so far. The result will say if that is too few to judge.',
              style: t.bodyMedium?.copyWith(color: RC.of(context).muted)),
        ),
    ]);
  }
}

enum _Step { reading, shops, buyers, genuine }

enum _StepState { waiting, active, done }

class _StepRow extends StatelessWidget {
  final String label;
  final _StepState state;
  const _StepRow({required this.label, required this.state});
  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotion(context);
    final icon = switch (state) {
      _StepState.done => const Icon(Icons.check_circle_rounded, color: RC.good, key: ValueKey('d')),
      _StepState.active => SizedBox(
          key: const ValueKey('a'),
          width: 22,
          height: 22,
          child: reduce
              ? Icon(Icons.more_horiz_rounded, color: RC.of(context).accent)
              : const CircularProgressIndicator(strokeWidth: 2.5)),
      _StepState.waiting => Icon(Icons.radio_button_unchecked_rounded, color: RC.of(context).line, key: ValueKey('w')),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: AnimatedSwitcher(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: icon,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: state == _StepState.active ? FontWeight.w800 : FontWeight.w600,
                color: state == _StepState.waiting ? RC.of(context).muted : RC.of(context).ink,
              )),
        ),
      ]),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  final ProductMeta meta;
  const _ProductHeader({required this.meta});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (meta.image.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(meta.image, width: 56, height: 56, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(width: 56, height: 56)),
        ),
      if (meta.image.isNotEmpty) const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meta.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(Platform.byName(meta.platform)?.label ?? meta.platform, style: TextStyle(color: RC.of(context).muted)),
        ]),
      ),
    ]);
  }
}

class _SourceRow extends StatelessWidget {
  final SourceReviews s;
  const _SourceRow(this.s);
  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (s.state) {
      SourceState.done => (Icons.check_circle_rounded, RC.good),
      SourceState.failed => (Icons.error_outline_rounded, RC.bad),
      SourceState.skipped || SourceState.needsUser => (Icons.lock_outline_rounded, RC.caution),
      _ => (Icons.more_horiz_rounded, RC.of(context).muted),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.link.platform.label} · ${s.reviews.length} reviews', style: const TextStyle(fontWeight: FontWeight.w700)),
            if (s.note.isNotEmpty) Text(s.note, style: TextStyle(color: RC.of(context).muted)),
          ]),
        ),
      ]),
    );
  }
}

class _SearchRow extends StatelessWidget {
  final String platform;
  final ShopSearch state;
  final bool matched;
  const _SearchRow({required this.platform, required this.state, required this.matched});
  @override
  Widget build(BuildContext context) {
    final label = Platform.byName(platform)?.label ?? platform;
    final text = switch (state) {
      ShopSearch.searching => 'Looking on $label…',
      ShopSearch.found => matched ? '$label · same product found' : '$label · not the same product',
      ShopSearch.notFound => '$label · not sold there',
      ShopSearch.failed => '$label · couldn\'t check',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(
          state == ShopSearch.searching ? Icons.search_rounded : matched ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded,
          color: matched ? RC.good : RC.of(context).muted,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: RC.of(context).muted, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _SameProductCard extends StatelessWidget {
  final MatchResult m;
  final ValueChanged<bool> onAnswer;
  const _SameProductCard({required this.m, required this.onAnswer});
  @override
  Widget build(BuildContext context) {
    final l = m.listing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Is this the same product?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (l.image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(l.image, width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 64, height: 64)),
              ),
            if (l.image.isNotEmpty) const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.title, maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text([l.platformLabel, if (l.price != null) '₹${l.price!.round()}'].join(' · '),
                    style: TextStyle(color: RC.of(context).muted)),
              ]),
            ),
          ]),
          if (m.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(m.reasons.take(3).join(' · '), style: TextStyle(color: RC.of(context).muted, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => onAnswer(false), child: const Text('No'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: () => onAnswer(true), child: const Text('Yes, same'))),
          ]),
        ]),
      ),
    );
  }
}

/// Friendly "we can't read this link" card.
class UnsupportedLink extends StatelessWidget {
  final String message;
  const UnsupportedLink({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.link_off_rounded, size: 56, color: RC.of(context).muted),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center, style: t.titleLarge),
      const SizedBox(height: 8),
      Text('Open the product in the Amazon, Flipkart or Myntra app, tap Share, then choose HTH.',
              textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: RC.of(context).muted))
          ,
      const SizedBox(height: 24),
      FilledButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('OK')),
    ]);
  }
}
