import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'link_parser.dart';
import 'models.dart';
import 'page_reader.dart';

/// When a store shows a sign-in page or a "are you human" check, the app
/// stops, shows that page to the user, and waits. It never types, clicks
/// or solves anything on those pages itself.
class Handoff {
  final SourceReviews source;
  final PageReader reader;
  final String reason;
  final _done = Completer<bool>();
  Handoff(this.source, this.reader, this.reason);

  /// User tapped "Skip": continue with the reviews we already have.
  void skip() {
    if (!_done.isCompleted) _done.complete(false);
  }

  void _resolved() {
    if (!_done.isCompleted) _done.complete(true);
  }

  Future<bool> get result => _done.future;
}

String fillUrl(String template, ProductLink link, {int page = 1}) {
  var s = template
      .replaceAll('{id}', link.productId)
      .replaceAll('{url}', link.canonical.toString())
      .replaceAll('{page}', '$page');
  if (s.contains('{flipkart_reviews}')) {
    final u = link.url;
    final path = u.path.contains('/p/') ? u.path.replaceFirst('/p/', '/product-reviews/') : u.path;
    final pid = u.queryParameters['pid'] ?? (link.productId.startsWith('itm') ? null : link.productId);
    final base = Uri.https('www.flipkart.com', path, pid == null ? {'x': '1'} : {'pid': pid});
    s = s.replaceAll('{flipkart_reviews}', base.toString());
  }
  return s;
}

/// Reads one listing's reviews on the phone.
class SourceCollector {
  final SourceReviews source;
  final PageReader reader;
  final Map<String, dynamic> cfg;
  final void Function() onProgress;
  final void Function(Handoff) onNeedsUser;
  final int target;

  /// Time spent reading pages ourselves. Time the user spends on a sign-in
  /// page doesn't count.
  final Duration budget;

  SourceCollector({
    required this.source,
    required this.reader,
    required this.cfg,
    required this.onProgress,
    required this.onNeedsUser,
    this.target = 150,
    this.budget = const Duration(seconds: 40),
  });

  final _clock = Stopwatch();
  bool _stopped = false;

  void stop() => _stopped = true;

  bool get _outOfTime => _clock.elapsed > budget;
  bool get _enough => source.reviews.length >= target;

  Future<void> run() async {
    _clock.start();
    source.state = SourceState.reading;
    onProgress();
    try {
      if (cfg['mode'] == 'page_api') {
        await _pageApiMode();
      } else if (cfg['mode'] == 'scroll') {
        await _scrollMode();
      } else {
        await _pagesMode();
      }
      if (source.state != SourceState.skipped) {
        source.state = source.reviews.isEmpty && source.meta == null ? SourceState.failed : SourceState.done;
      }
      if (_outOfTime && source.note.isEmpty) source.note = 'Stopped early to keep things quick';
    } catch (_) {
      source.state = source.reviews.isEmpty ? SourceState.failed : SourceState.done;
    } finally {
      _clock.stop();
      onProgress();
    }
  }

  /// Returns null when the user chose to skip.
  Future<Map<String, dynamic>?> _extract({bool meta = false}) async {
    var r = await reader.call('extract', cfg, opts: {'meta': meta});
    if (r == null && !_stopped) {
      // Slow page (busy main thread): give it a moment and try once more.
      await Future<void>.delayed(const Duration(seconds: 2));
      r = await reader.call('extract', cfg, opts: {'meta': meta});
    }
    if (r != null && r['blocked'] != null) {
      final ok = await _askUser('${r['blocked']}');
      if (!ok) return null;
      r = await reader.call('extract', cfg, opts: {'meta': meta});
    }
    return r;
  }

  Future<bool> _askUser(String reason) async {
    _clock.stop();
    final h = Handoff(source, reader, reason);
    source.state = SourceState.needsUser;
    onNeedsUser(h);
    onProgress();
    // Watch the page: once it's no longer a sign-in/check page, carry on.
    final watcher = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      final p = await reader.call('probe', cfg, timeout: const Duration(seconds: 4));
      if (p != null && p['blocked'] == null && p['ready'] == 'complete') h._resolved();
    });
    bool ok;
    try {
      ok = await h.result.timeout(const Duration(minutes: 5), onTimeout: () => false);
    } finally {
      watcher.cancel();
    }
    if (!ok) {
      source.state = SourceState.skipped;
      source.note = reason.contains('signin') || reason.contains('login')
          ? 'Sign-in skipped, so only the first reviews were read'
          : 'Check skipped, so only some reviews were read';
    } else {
      source.state = SourceState.reading;
      // Give the page the user just finished on a moment to settle.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    onProgress();
    _clock.start();
    return ok;
  }

  int _take(Map<String, dynamic>? r) {
    if (r == null) return 0;
    final list = (r['reviews'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Review.fromPage(source.platform, e.cast<String, dynamic>()));
    final n = source.addAll(list);
    final m = r['meta'];
    if (m is Map) {
      final fresh = ProductMeta.fromPage(source.link, m.cast<String, dynamic>());
      source.meta = _merge(source.meta, fresh);
    }
    onProgress();
    return n;
  }

  /// Keep the first non-empty value for each field.
  ProductMeta _merge(ProductMeta? a, ProductMeta b) {
    if (a == null) return b;
    String pick(String x, String y) => x.isNotEmpty ? x : y;
    return ProductMeta(
      platform: a.platform,
      productId: a.productId,
      url: a.url,
      title: pick(a.title, b.title),
      brand: pick(a.brand, b.brand),
      model: pick(a.model, b.model),
      variant: pick(a.variant, b.variant),
      price: a.price ?? b.price,
      image: pick(a.image, b.image),
      rating: a.rating ?? b.rating,
      ratingCount: a.ratingCount ?? b.ratingCount,
      histogram: a.histogram.isNotEmpty ? a.histogram : b.histogram,
      specs: a.specs.isNotEmpty ? a.specs : b.specs,
      fitSummary: pick(a.fitSummary, b.fitSummary),
    );
  }

  Future<void> _pagesMode() async {
    // 1. Product page: identity, overall rating, and the top reviews.
    await reader.load(Uri.parse(fillUrl(cfg['product_url'] as String, source.link)));
    final first = await _extract(meta: true);
    if (first == null) return;
    debugPrint('HTH product page ${source.platform} url=${reader.currentUrl} title=${(first['meta'] as Map?)?['title']} reviews=${(first['reviews'] as List?)?.length}');
    _take(first);

    // 2. "Most recent" review pages, until we have enough or run out.
    final maxPages = (cfg['max_pages'] as num?)?.toInt() ?? 8;
    var emptyInARow = 0;
    for (var page = 1; page <= maxPages && !_stopped && !_enough && !_outOfTime; page++) {
      final loaded = await reader.load(Uri.parse(fillUrl(cfg['reviews_url'] as String, source.link, page: page)));
      var r = await _extract(meta: page == 1);
      // Single-page apps render reviews after "page finished": look again.
      for (var tries = 0; tries < 2 && r != null && r['blocked'] == null && ((r['reviews'] as List?)?.isEmpty ?? true); tries++) {
        await Future<void>.delayed(const Duration(milliseconds: 1800));
        r = await _extract(meta: page == 1);
      }
      debugPrint('HTH page ${source.platform} p$page loaded=$loaded t=${_clock.elapsed.inSeconds}s blocked=${r?['blocked']} n=${(r?['reviews'] as List?)?.length} url=${reader.currentUrl}');
      if (r == null) return;
      if (_take(r) == 0) {
        if (++emptyInARow >= 2) break;
      } else {
        emptyInARow = 0;
      }
    }
  }

  /// Reviews page for identity + first reviews, then the store's own
  /// "load more" request, page by page.
  Future<void> _pageApiMode() async {
    await reader.load(Uri.parse(fillUrl(cfg['reviews_url'] as String, source.link)));
    final first = await _extract(meta: true);
    if (first == null) return;
    // Product info only: the same reviews come back from the store's
    // request below, with ids, so they aren't counted twice.
    _take({'meta': first['meta']});
    final maxPages = (cfg['max_pages'] as num?)?.toInt() ?? 10;
    var empty = 0;
    for (var page = 1; page <= maxPages && !_stopped && !_enough && !_outOfTime; page++) {
      var r = await reader.call('api', cfg, opts: {'id': source.link.productId, 'page': page});
      if (r != null && r['blocked'] != null) {
        if (!await _askUser('${r['blocked']}')) return;
        r = await reader.call('api', cfg, opts: {'id': source.link.productId, 'page': page});
      }
      if (_take(r) == 0) {
        if (++empty >= 2) break;
      } else {
        empty = 0;
      }
    }
  }

  Future<void> _scrollMode() async {
    await reader.load(Uri.parse(fillUrl(cfg['reviews_url'] as String, source.link)));
    final first = await _extract(meta: true);
    if (first == null) return;
    _take(first);
    final sortText = cfg['sort_click_text'] as String?;
    if (sortText != null) {
      final s = await reader.call('sort', cfg);
      if (s?['clicked'] == true) _take(await _extract());
    }
    final maxScrolls = (cfg['max_scrolls'] as num?)?.toInt() ?? 10;
    var still = 0;
    for (var i = 0; i < maxScrolls && !_stopped && !_enough && !_outOfTime; i++) {
      await reader.call('scroll', cfg, timeout: const Duration(seconds: 8));
      final r = await _extract();
      if (r == null) return;
      if (_take(r) == 0) {
        if (++still >= 2) break;
      } else {
        still = 0;
      }
    }
  }
}
