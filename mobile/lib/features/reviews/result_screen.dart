import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'analysis_job.dart';
import 'link_parser.dart';
import 'rtheme.dart';

/// Share → one result screen, top to bottom, in plain words.
class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final bool demo;
  const ResultScreen({super.key, required this.result, this.demo = false});

  factory ResultScreen.fromJob(AnalysisJob job) => ResultScreen(result: job.analysis!);

  Map<String, dynamic> _m(String k) => (result[k] as Map?)?.cast<String, dynamic>() ?? const {};

  @override
  Widget build(BuildContext context) {
    final verdict = _m('verdict');
    final noVerdict = verdict['score'] == null;
    var i = 0;
    Widget a(Widget w) => Appear(index: i++, child: Padding(padding: const EdgeInsets.only(bottom: 14), child: w));
    final cards = <Widget>[
      a(_Header(result: result, demo: demo)),
      if (!noVerdict) ...[
        a(_PhotoMeter(nas: _m('not_as_shown'))),
        a(_Aspects(aspects: _m('aspects'))),
        a(_Trust(trust: _m('trust'))),
        if (result['size_advice'] is Map && (result['size_advice'] as Map)['advice'] != null)
          a(_SizeCard(size: _m('size_advice'))),
        a(_Trend(trend: _m('trend'))),
      ],
      a(_Platforms(xp: _m('cross_platform'))),
      a(_Independent(ind: (_m('cross_platform')['independent'] as Map?)?.cast<String, dynamic>() ?? const {})),
      if (!noVerdict) a(_Why(verdict: verdict, quotes: (result['quotes'] as List? ?? const []).cast<Map>())),
      a(_Footer(result: result)),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Should you buy it?'),
        actions: [
          IconButton(
            tooltip: 'Share result',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => shareResult(result),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: cards),
      ),
    );
  }
}

Future<void> shareResult(Map<String, dynamic> r) async {
  final p = (r['product'] as Map?) ?? const {};
  final v = (r['verdict'] as Map?) ?? const {};
  final nas = (r['not_as_shown'] as Map?) ?? const {};
  final lines = [
    'HTH review check: ${p['title'] ?? 'Product'}',
    '${v['label']}: ${v['sentence']}',
    for (final x in ((v['reasons'] as List?) ?? const []).take(4)) '• $x',
    if (nas['share'] != null) '${((nas['share'] as num) * 100).round()}% of buyers say it isn\'t like the photo',
    if ((p['url'] ?? '').toString().isNotEmpty) '${p['url']}',
  ];
  await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
}

Future<void> _open(BuildContext context, String? url) async {
  final u = Uri.tryParse(url ?? '');
  if (u == null || !u.hasScheme) return;
  final ok = await launchUrl(u, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open that link")));
  }
}

String _platform(String? p) => Platform.byName(p)?.label ??
    switch (p) { 'youtube' => 'YouTube', 'reddit' => 'Reddit', _ => p ?? '' };

// ─── building blocks ───────────────────────────────────────────────────

class _CardBox extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  const _CardBox({this.title, this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null) Text(title!, style: t.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: t.bodyMedium?.copyWith(color: c.muted)),
          ],
          if (title != null) const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool solid;
  const _Pill(this.text, {required this.color, this.solid = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: solid ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(color: solid ? Colors.white : color, fontWeight: FontWeight.w800, fontSize: 13.5)),
      );
}

class _QuoteTile extends StatelessWidget {
  final Map q;
  const _QuoteTile(this.q);
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final rating = (q['rating'] as num?)?.round();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('“${q['text']}”', style: TextStyle(color: c.ink, height: 1.4)),
        const SizedBox(height: 4),
        Text([if (rating != null) '$rating★', _platform(q['platform'] as String?)].join(' · '),
            style: TextStyle(color: c.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

void _showQuotes(BuildContext context, String title, List<Map> positive, List<Map> negative) {
  final c = RC.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Theme(
      data: Theme.of(context),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Real words from buyers', style: TextStyle(color: c.muted)),
          const SizedBox(height: 14),
          if (negative.isNotEmpty) ...[
            const Text('Complaints', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final q in negative) _QuoteTile(q),
            const SizedBox(height: 8),
          ],
          if (positive.isNotEmpty) ...[
            const Text('Praise', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final q in positive) _QuoteTile(q),
          ],
          if (positive.isEmpty && negative.isEmpty) Text('No quotes to show.', style: TextStyle(color: c.muted)),
        ]),
      ),
    ),
  );
}

// ─── sections ──────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Map<String, dynamic> result;
  final bool demo;
  const _Header({required this.result, required this.demo});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final t = Theme.of(context).textTheme;
    final p = (result['product'] as Map?) ?? const {};
    final v = (result['verdict'] as Map?) ?? const {};
    final conf = (result['confidence'] as Map?) ?? const {};
    final color = RC.verdict(v['color'] as String?);
    final img = (p['image'] ?? '') as String;
    final n = result['reviews_analysed'] ?? 0;
    final per = ((result['stats'] as Map?)?['per_platform'] as Map?) ?? const {};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (img.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(img, width: 72, height: 72, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 72, height: 72, color: c.line)),
              ),
            if (img.isNotEmpty) const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['title'] ?? 'Product'}', maxLines: 3, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                const SizedBox(height: 4),
                Text(
                  [
                    _platform(p['platform'] as String?),
                    if (p['price'] != null) '₹${(p['price'] as num).round()}',
                    if (demo) 'Demo',
                  ].join(' · '),
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          Semantics(
            label: 'Verdict: ${v['label']}',
            child: _Pill('${v['label'] ?? ''}', color: color, solid: true),
          ),
          const SizedBox(height: 10),
          Text('${v['sentence'] ?? ''}', style: t.titleLarge?.copyWith(height: 1.3)),
          const SizedBox(height: 10),
          Text(
            'Based on $n reviews from ${per.keys.map((k) => _platform(k as String)).join(', ')}. ${conf['text'] ?? ''}',
            style: TextStyle(color: c.muted),
          ),
        ]),
      ),
    );
  }
}

class _PhotoMeter extends StatelessWidget {
  final Map<String, dynamic> nas;
  const _PhotoMeter({required this.nas});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final share = ((nas['share'] as num?) ?? 0).toDouble();
    final level = nas['level'] as String? ?? 'low';
    final color = level == 'high' ? RC.bad : level == 'some' ? RC.caution : RC.good;
    final types = (nas['types'] as List? ?? const []).cast<Map>();
    final headline = switch (level) {
      'high' => 'Many buyers say it isn\'t like the photo',
      'some' => 'Some buyers say it isn\'t like the photo',
      _ => 'Buyers say it looks like the photo',
    };
    return _CardBox(
      title: 'Is it like the photo?',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          CountUp(
            value: share * 100,
            format: (x) => '${x.round()}%',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: color, height: 1),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('of reviews say it\'s different from the listing', style: TextStyle(color: c.muted)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        FillBar(value: (share / 0.3).clamp(0, 1), color: color),
        const SizedBox(height: 10),
        Text(headline, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (types.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final ty in types)
              ActionChip(
                label: Text('${ty['label']} · ${ty['count']}'),
                onPressed: () => _showQuotes(context, '${ty['label']}', const [],
                    (ty['examples'] as List? ?? const []).cast<Map>()),
              ),
          ]),
        ],
      ]),
    );
  }
}

class _Aspects extends StatelessWidget {
  final Map<String, dynamic> aspects;
  const _Aspects({required this.aspects});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final rows = aspects.entries
        .map((e) => MapEntry(e.key, (e.value as Map).cast<String, dynamic>()))
        .where((e) => ((e.value['positive'] as int? ?? 0) + (e.value['negative'] as int? ?? 0)) >= 3)
        .toList()
      ..sort((a, b) => (b.value['mentions'] as int).compareTo(a.value['mentions'] as int));
    return _CardBox(
      title: 'What buyers say',
      subtitle: rows.isEmpty ? 'Not enough detail in the reviews to break this down.' : 'Tap a row to read real reviews',
      child: Column(children: [
        for (final e in rows)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final q = (e.value['quotes'] as Map?) ?? const {};
              _showQuotes(context, '${e.value['label']}', (q['positive'] as List? ?? const []).cast<Map>(),
                  (q['negative'] as List? ?? const []).cast<Map>());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: _AspectRow(a: e.value, muted: c.muted),
            ),
          ),
      ]),
    );
  }
}

class _AspectRow extends StatelessWidget {
  final Map<String, dynamic> a;
  final Color muted;
  const _AspectRow({required this.a, required this.muted});
  @override
  Widget build(BuildContext context) {
    final pos = a['positive'] as int? ?? 0, neg = a['negative'] as int? ?? 0;
    final share = pos + neg == 0 ? 0.0 : pos / (pos + neg);
    final c = RC.of(context);
    return Semantics(
      button: true,
      label: '${a['label']}: ${(share * 100).round()} percent positive from ${pos + neg} reviews',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${a['label']}', style: const TextStyle(fontWeight: FontWeight.w700))),
          Text('${(share * 100).round()}% 👍', style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: muted, size: 20),
        ]),
        const SizedBox(height: 6),
        FillBar(value: share, color: c.accent, back: c.dark ? const Color(0xFF3A2430) : const Color(0xFFF1D9D9)),
        const SizedBox(height: 3),
        Text('$pos happy · $neg unhappy', style: TextStyle(color: muted, fontSize: 12.5)),
      ]),
    );
  }
}

class _Trust extends StatelessWidget {
  final Map<String, dynamic> trust;
  const _Trust({required this.trust});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final score = (trust['score'] as num?)?.toDouble();
    final level = trust['level'] as String? ?? 'unknown';
    final flags = (trust['flags'] as List? ?? const []).cast<Map>();
    final text = switch (level) {
      'high' => 'Reviews look genuine',
      'medium' => 'Mostly genuine, with some warning signs',
      'low' => 'Be careful: many reviews look unreliable',
      _ => 'Not enough reviews to judge',
    };
    return _CardBox(
      title: 'Can you trust these reviews?',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (score != null)
            CountUp(value: score, format: (x) => '${x.round()}', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: c.ink, height: 1)),
          if (score != null) Text(' /100', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        if (score != null) ...[const SizedBox(height: 10), FillBar(value: score / 100, color: c.accent)],
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final f in flags)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.flag_rounded, size: 18, color: f['severity'] == 'high' ? RC.bad : RC.caution),
                const SizedBox(width: 8),
                Expanded(child: Text('${f['text']}')),
              ]),
            ),
        ] else if (score != null) ...[
          const SizedBox(height: 10),
          Text('No red flags: few copy-paste or one-word reviews, no sudden bursts.', style: TextStyle(color: c.muted)),
        ],
      ]),
    );
  }
}

class _SizeCard extends StatelessWidget {
  final Map<String, dynamic> size;
  const _SizeCard({required this.size});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    return _CardBox(
      title: 'Size advice',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${size['advice']}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text('${size['small']} say small · ${size['true_to_size']} say true to size · ${size['large']} say large',
            style: TextStyle(color: c.muted)),
        if (size['shop_summary'] != null) ...[
          const SizedBox(height: 6),
          Text('Shop says: ${size['shop_summary']}', style: TextStyle(color: c.muted)),
        ],
      ]),
    );
  }
}

class _Trend extends StatelessWidget {
  final Map<String, dynamic> trend;
  const _Trend({required this.trend});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final status = trend['status'] as String? ?? 'unknown';
    final icon = switch (status) {
      'worse' => Icons.trending_down_rounded,
      'better' => Icons.trending_up_rounded,
      'stable' => Icons.trending_flat_rounded,
      _ => Icons.help_outline_rounded,
    };
    final color = status == 'worse' ? RC.bad : status == 'better' ? RC.good : c.muted;
    final aspects = (trend['aspects'] as List? ?? const []).cast<Map>();
    return _CardBox(
      title: 'Lately',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(child: Text('${trend['text']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        ]),
        if (trend['recent_rating'] != null) ...[
          const SizedBox(height: 6),
          Text('Last 60 days: ${trend['recent_rating']}★ (${trend['recent']} reviews) · before: ${trend['older_rating']}★ (${trend['older']})',
              style: TextStyle(color: c.muted)),
        ],
        for (final a in aspects)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('• ${a['text']}')),
      ]),
    );
  }
}

class _Platforms extends StatelessWidget {
  final Map<String, dynamic> xp;
  const _Platforms({required this.xp});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final shops = (xp['shops'] as List? ?? const []).cast<Map>();
    final gap = (xp['gap'] as Map?);
    final cheapest = (xp['cheapest'] as Map?);
    return _CardBox(
      title: 'Across shops',
      subtitle: shops.length <= 1 ? "Couldn't find this exact product on other shops" : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final s in shops)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['label']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    [
                      if (s['listing_rating'] != null) '${s['listing_rating']}★ overall',
                      if ((s['reviews_read'] ?? 0) > 0) '${s['reviews_read']} reviews read' else 'rating only',
                    ].join(' · '),
                    style: TextStyle(color: c.muted, fontSize: 13),
                  ),
                ]),
              ),
              if (s['price'] != null)
                Text('₹${(s['price'] as num).round()}', style: const TextStyle(fontWeight: FontWeight.w800)),
              if ((s['url'] ?? '').toString().isNotEmpty)
                IconButton(
                  tooltip: 'Open ${s['label']}',
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  onPressed: () => _open(context, s['url'] as String?),
                ),
            ]),
          ),
        if (gap != null) ...[
          const Divider(height: 20),
          Text('Big rating gap: ${gap['text']}', style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final w in (gap['likely_reasons'] as List? ?? const []))
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $w', style: TextStyle(color: c.muted))),
        ],
        if (cheapest != null && shops.length > 1) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _open(context, cheapest['url'] as String?),
            icon: const Icon(Icons.local_offer_rounded),
            label: Text(((cheapest['tied_with'] as List?) ?? const []).isEmpty
                ? 'Cheapest: ₹${(cheapest['price'] as num).round()} on ${cheapest['label']}'
                : 'Same price ₹${(cheapest['price'] as num).round()} on ${cheapest['label']} and ${(cheapest['tied_with'] as List).join(', ')}'),
          ),
        ],
      ]),
    );
  }
}

class _Independent extends StatelessWidget {
  final Map<String, dynamic> ind;
  const _Independent({required this.ind});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final sources = (ind['sources'] as List? ?? const []).cast<Map>();
    return _CardBox(
      title: 'Independent opinions',
      subtitle: 'YouTube and Reddit, kept separate from shop reviews',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ((ind['text'] ?? '').toString().isNotEmpty) Text('${ind['text']}', style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final s in sources) ...[
          const SizedBox(height: 10),
          Text('${s['label']}', style: const TextStyle(fontWeight: FontWeight.w800)),
          if (s['status'] == 'not_set_up')
            Text('Not connected yet', style: TextStyle(color: c.muted))
          else if (s['status'] == 'none_found')
            Text('Nothing found for this product', style: TextStyle(color: c.muted))
          else
            for (final it in (s['items'] as List? ?? const []).cast<Map>())
              InkWell(
                onTap: () => _open(context, it['url'] as String?),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(s['source'] == 'youtube' ? Icons.play_circle_outline_rounded : Icons.forum_outlined, color: c.muted),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${it['title']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),
        ],
      ]),
    );
  }
}

class _Why extends StatelessWidget {
  final Map<String, dynamic> verdict;
  final List<Map> quotes;
  const _Why({required this.verdict, required this.quotes});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: Text('Why this verdict?', style: Theme.of(context).textTheme.titleMedium),
          children: [
            for (final r in (verdict['reasons'] as List? ?? const []))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check_rounded, size: 18, color: c.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$r')),
                ]),
              ),
            if (quotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('What buyers wrote', style: TextStyle(color: c.muted, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final q in quotes) _QuoteTile(q),
            ],
            if (verdict['score'] != null)
              Text('Score ${verdict['score']}/100 from stars, complaints, trust and trend.', style: TextStyle(color: c.muted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final Map<String, dynamic> result;
  const _Footer({required this.result});
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final notes = (((result['stats'] as Map?)?['notes']) as List? ?? const []).cast<String>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final n in notes.toSet())
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Note: $n', style: TextStyle(color: c.muted))),
      const SizedBox(height: 6),
      OutlinedButton.icon(
        onPressed: () => shareResult(result),
        icon: const Icon(Icons.ios_share_rounded),
        label: const Text('Share this result'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
      const SizedBox(height: 10),
      Text(
        'HTH reads the reviews shown to you on each shop, on your phone. It never signs in or solves checks for you.',
        style: TextStyle(color: c.muted, fontSize: 12.5),
      ),
    ]);
  }
}
