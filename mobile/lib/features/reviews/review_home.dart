import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../resolve/home_screen.dart';
import 'history_store.dart';
import 'link_parser.dart';
import 'result_screen.dart';
import 'rtheme.dart';
import 'settings_sheet.dart';
import 'share_listener.dart';

/// Front door: how to use, paste a link, recent checks.
class ReviewHome extends StatefulWidget {
  const ReviewHome({super.key});
  @override
  State<ReviewHome> createState() => _ReviewHomeState();
}

class _ReviewHomeState extends State<ReviewHome> {
  final _link = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => takePendingShare());
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) setState(() => _link.text = d!.text!.trim());
  }

  void _check() {
    final text = _link.text.trim();
    if (extractUrl(text) == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paste a product link from Amazon, Flipkart or Myntra')));
      return;
    }
    FocusScope.of(context).unfocus();
    openAnalyser(text);
    _link.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final t = Theme.of(context).textTheme;
    final history = context.watch<HistoryStore>().items;
    var i = 0;
    Widget a(Widget w) => Appear(index: i++, child: w);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          const Text('HTH'),
        ]),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => showSettingsSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 28), children: [
          a(Text('Check a product before you buy', style: t.headlineMedium)),
          const SizedBox(height: 8),
          a(Text('HTH reads the reviews for you and tells you, in plain words, if it\'s really what it looks like.',
              style: t.bodyLarge?.copyWith(color: c.muted))),
          const SizedBox(height: 20),
          a(const _HowTo()),
          const SizedBox(height: 16),
          a(Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Or paste a link', style: t.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _check(),
                  decoration: InputDecoration(
                    hintText: 'https://www.amazon.in/…',
                    suffixIcon: IconButton(tooltip: 'Paste', icon: const Icon(Icons.content_paste_rounded), onPressed: _paste),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _check, child: const Text('Check reviews')),
              ]),
            ),
          )),
          if (context.watch<DemoSettings>().on) ...[
            const SizedBox(height: 24),
            a(const _DemoProducts()),
          ],
          if (history.isNotEmpty) ...[
            const SizedBox(height: 24),
            a(Text('RECENT CHECKS', style: TextStyle(fontSize: 13, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: c.muted))),
            const SizedBox(height: 8),
            for (final h in history.take(8)) a(_HistoryTile(h)),
          ],
          const SizedBox(height: 24),
          a(Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(AppTheme.route(const ResolveHomeScreen())),
              icon: const Icon(Icons.support_agent_rounded),
              label: const Text('Got a problem after buying? Get help'),
              style: TextButton.styleFrom(foregroundColor: c.muted),
            ),
          )),
        ]),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final SavedAnalysis h;
  const _HistoryTile(this.h);
  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    final v = h.verdict;
    final color = RC.verdict(v['color'] as String?);
    final img = (h.product['image'] ?? '') as String;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(h.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(22)),
          child: const Icon(Icons.delete_outline_rounded),
        ),
        onDismissed: (_) => context.read<HistoryStore>().remove(h.id),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(reviewRoute(ResultScreen(result: h.result, demo: h.demo))),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: img.isEmpty
                      ? Container(width: 52, height: 52, color: c.line, child: Icon(Icons.shopping_bag_outlined, color: c.muted))
                      : Image.network(img, width: 52, height: 52, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 52, height: 52, color: c.line)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('${v['label'] ?? ''}${h.demo ? ' · Demo' : ''}',
                            style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three steps, highlighted in turn (static when reduce-motion is on).
class _HowTo extends StatefulWidget {
  const _HowTo();
  @override
  State<_HowTo> createState() => _HowToState();
}

class _HowToState extends State<_HowTo> {
  int _step = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (!reduceMotion(context)) {
      _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) => setState(() => _step = (_step + 1) % 3));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    const steps = [
      (Icons.storefront_rounded, 'Open any product', 'in the Amazon, Flipkart or Myntra app'),
      (Icons.share_rounded, 'Tap Share', 'the share button on the product page'),
      (Icons.fact_check_rounded, 'Choose HTH', 'we read the reviews and give you a verdict'),
    ];
    final animate = !reduceMotion(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How to use', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (var k = 0; k < steps.length; k++)
            AnimatedContainer(
              duration: Duration(milliseconds: animate ? 300 : 0),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: animate && k == _step ? c.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                AnimatedScale(
                  scale: animate && k == _step ? 1.12 : 1,
                  duration: const Duration(milliseconds: 300),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: k == _step || !animate ? c.accent : c.line,
                    child: Icon(steps[k].$1, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${k + 1}. ${steps[k].$2}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Text(steps[k].$3, style: TextStyle(color: c.muted)),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}


/// Demo mode: real products collected earlier, analysed by the real analyser,
/// bundled in the app. Works without live shop pages or the server.
class _DemoProducts extends StatelessWidget {
  const _DemoProducts();

  Future<List<Map<String, dynamic>>> _load() async {
    final raw = await rootBundle.loadString('assets/demo/index.json');
    return ((jsonDecode(raw) as Map)['products'] as List).cast<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> _open(BuildContext context, Map<String, dynamic> p) async {
    final result = (jsonDecode(await rootBundle.loadString(p['file'] as String)) as Map).cast<String, dynamic>();
    if (!context.mounted) return;
    Navigator.of(context).push(reviewRoute(ResultScreen(result: result, demo: true)));
  }

  @override
  Widget build(BuildContext context) {
    final c = RC.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DEMO PRODUCTS', style: TextStyle(fontSize: 13, letterSpacing: 0.8, fontWeight: FontWeight.w800, color: c.muted)),
          const SizedBox(height: 4),
          Text("Real reviews collected earlier. Results don't change with the live shops.",style: TextStyle(color: c.muted)),
          const SizedBox(height: 8),
          for (final p in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: RC.verdict(p['color'] as String?), shape: BoxShape.circle)),
                  title: Text('${p['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${p['verdict']} · ${p['note']} · collected ${p['collected']}', style: TextStyle(color: c.muted)),
                  trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
                  onTap: () => _open(context, p),
                ),
              ),
            ),
        ]);
      },
    );
  }
}
