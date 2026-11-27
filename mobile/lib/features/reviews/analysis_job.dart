import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'collector.dart';
import 'cross_platform.dart';
import 'link_parser.dart';
import 'models.dart';
import 'page_reader.dart';
import 'review_api.dart';
import 'selectors.dart';

/// Fewer reviews than this and we say there isn't enough to go on.
const minReviews = 15;

enum JobStage { link, reading, analysing, done, failed }

enum ShopSearch { searching, found, notFound, failed }

/// Everything that happens after a share, in one place:
///  1. read the link            2. read reviews on the shared shop
///  3. find the same product on other shops (on the phone) + match (backend)
///  4. read reviews on confirmed matches   5. YouTube/Reddit (backend)
///  6. analyse (backend)
class AnalysisJob extends ChangeNotifier {
  final String sharedText;
  AnalysisJob(this.sharedText);

  JobStage stage = JobStage.link;
  String? problem;
  ProductLink? link;
  SelectorConfig? _cfg;

  final List<SourceReviews> sources = [];
  final Map<SourceReviews, PageReader> readers = {};
  final List<PageReader> searchReaders = [];
  final List<Handoff> handoffs = [];
  final List<SourceCollector> _collectors = [];

  final Map<String, ShopSearch> shopSearch = {};
  List<MatchResult> matches = [];
  String matchSummary = '';
  String query = '';
  Map<String, dynamic>? opinions;
  Map<String, dynamic>? analysis;
  String? analysisError;

  /// "Is this the same product?" questions waiting for the user.
  List<MatchResult> get questions =>
      matches.where((m) => m.decision == 'possible' && m.userSaysSame == null).toList();

  bool _disposed = false;
  final _started = Stopwatch();
  Timer? _watchdog;
  static const deadline = Duration(seconds: 90);
  bool get _pastDeadline => _started.elapsed > deadline;
  final _futures = <Future<void>>[];
  Future<void>? _elsewhere;

  SourceReviews? get main => sources.isEmpty ? null : sources.first;
  int get total => sources.fold(0, (n, s) => n + s.reviews.length);
  List<PageReader> get allReaders => [...readers.values, ...searchReaders];

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    final r = await readSharedText(sharedText);
    if (_disposed) return;
    if (r.link == null) {
      problem = r.problem;
      stage = JobStage.failed;
      _changed();
      return;
    }
    link = r.link;
    ReviewApi.wake();
    _cfg = await SelectorConfig.load();
    stage = JobStage.reading;
    _changed();

    _started.start();
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      // Keep the whole check under ~90s of our own time. Never cut off a
      // sign-in/check page the user is looking at.
      if (handoffs.isNotEmpty) {
        _started.stop();
      } else {
        _started.start();
      }
      if (_pastDeadline) {
        for (final c in _collectors) {
          c.stop();
        }
      }
    });
    final mainSrc = SourceReviews(link!);
    final mainDone = _collect(mainSrc, budget: const Duration(seconds: 35), interactive: true);

    // As soon as the product page tells us what this is, look elsewhere.
    while (!_disposed && (mainSrc.meta?.title ?? '').isEmpty && mainSrc.state != SourceState.done &&
        mainSrc.state != SourceState.failed && mainSrc.state != SourceState.skipped) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    final meta = mainSrc.meta;
    Future<void>? opinionsDone;
    if (meta != null && meta.title.isNotEmpty) {
      query = searchQuery(meta);
      _elsewhere = _findElsewhere(meta);
      opinionsDone = ReviewApi.independentOpinions(query).then((o) {
        opinions = o;
        _changed();
      });
    }
    await mainDone;
    debugPrint('HTH main done: ${mainSrc.reviews.length} reviews, state=${mainSrc.state}');
    if (_elsewhere != null) await _elsewhere;
    // Collectors started for matches the user confirmed while we waited.
    while (_futures.isNotEmpty) {
      final f = List.of(_futures);
      _futures.clear();
      await Future.wait(f);
    }
    if (opinionsDone != null) await opinionsDone.timeout(const Duration(seconds: 20), onTimeout: () {});
    _watchdog?.cancel();
    if (_disposed) return;
    _closeReaders();
    await analyse();
  }

  Future<void> _collect(SourceReviews s, {Duration budget = const Duration(seconds: 25), bool interactive = false}) {
    final pc = _cfg?.platform(s.platform);
    sources.add(s);
    if (pc == null) {
      s.state = SourceState.failed;
      _changed();
      return Future.value();
    }
    final reader = PageReader();
    readers[s] = reader;
    final c = SourceCollector(
      source: s,
      reader: reader,
      cfg: pc,
      budget: budget,
      interactive: interactive,
      onProgress: _changed,
      onNeedsUser: (h) {
        handoffs.add(h);
        h.result.whenComplete(() {
          handoffs.remove(h);
          _changed();
        });
        _changed();
      },
    );
    _collectors.add(c);
    _changed();
    return c.run();
  }

  Future<void> _findElsewhere(ProductMeta meta) async {
    final cfg = _cfg!;
    final shops = shopsFor(meta, cfg)
        .where((p) => p != meta.platform)
        .where((p) => cfg.search(p) != null && cfg.search(p)!['enabled'] != false)
        .toList();
    for (final s in shops) {
      shopSearch[s] = ShopSearch.searching;
    }
    _changed();
    // One shop at a time: several heavy store pages at once is too much for
    // many phones, and it's gentler on the shops.
    final found = <List<Listing>>[];
    for (final p in shops) {
      if (_disposed || _pastDeadline) {
        shopSearch[p] = ShopSearch.failed;
        continue;
      }
      found.add(await _searchOne(p, cfg));
    }
    final candidates = found.expand((l) => l).toList();
    await _matchAndRead(meta, candidates);
  }

  Future<List<Listing>> _searchOne(String p, SelectorConfig cfg) async {
      final reader = PageReader();
      searchReaders.add(reader);
      _changed();
      try {
        final list = await searchShop(reader, p, cfg.search(p)!, query).timeout(const Duration(seconds: 25));
        debugPrint('HTH search $p "$query" -> ${list.length}');
        shopSearch[p] = list.isEmpty ? ShopSearch.notFound : ShopSearch.found;
        return list;
      } catch (e) {
        debugPrint('HTH search $p failed: $e');
        shopSearch[p] = ShopSearch.failed;
        return <Listing>[];
      } finally {
        searchReaders.remove(reader);
        reader.dispose();
        _changed();
      }
  }

  Future<void> _matchAndRead(ProductMeta meta, List<Listing> candidates) async {
    if (_disposed) return;
    final product = {
      'platform': meta.platform,
      'title': meta.title,
      'brand': meta.brand,
      'model': meta.model,
      'url': meta.url,
      'price': meta.price,
      'rating': meta.rating,
    };
    debugPrint('HTH matching ${candidates.length} candidates');
    final res = candidates.isEmpty ? null : await ReviewApi.matchProducts(product, candidates.map((c) => c.toJson()).toList());
    if (res == null) {
      matchSummary = candidates.isEmpty ? "Couldn't find this exact product elsewhere" : "Couldn't check other shops right now";
      _changed();
      return;
    }
    debugPrint('HTH match result: ${res['summary']} ${(res['results'] as List).map((e) => '${e['candidate']['platform']}:${e['decision']}:${e['confidence']}').join(', ')}');
    matches = (res['results'] as List).map((e) => MatchResult.fromJson((e as Map).cast<String, dynamic>())).toList();
    matchSummary = (res['summary'] ?? '') as String;
    for (final m in matches.where((m) => m.decision == 'match')) {
      _readMatch(m);
    }
    _changed();
  }

  /// Read reviews for a confirmed match, if we can read that shop.
  void _readMatch(MatchResult m) {
    if (_pastDeadline) return;
    final l = identify(Uri.parse(m.listing.url));
    if (l == null || _cfg?.platform(l.platform.name) == null) return;
    if (sources.any((s) => s.link.platform == l.platform && s.link.productId == l.productId)) return;
    _futures.add(_collect(SourceReviews(l)));
  }

  /// User answered "Is this the same product?".
  void answer(MatchResult m, bool same) {
    m.userSaysSame = same;
    if (same && stage == JobStage.reading) _readMatch(m);
    _changed();
  }

  Map<String, dynamic> requestBody() => {
        'product': main?.meta?.toJson() ?? {'platform': link?.platform.name, 'url': link?.canonical.toString()},
        'sources': [
          for (final s in sources)
            {
              'platform': s.platform,
              'url': s.link.canonical.toString(),
              'meta': s.meta?.toJson(),
              'note': s.note,
              'reviews': s.reviews.map((r) => r.toJson()).toList(),
            }
        ],
        'listings': [
          for (final m in matches)
            if (m.confirmed) {...m.listing.toJson(), 'confidence': m.confidence, 'reasons': m.reasons}
        ],
        'opinions': opinions,
        'collected_at': DateTime.now().toIso8601String(),
      };

  Future<void> analyse() async {
    stage = JobStage.analysing;
    _changed();
    // Below minReviews the backend still answers, with a plain "not enough reviews".
    final body = requestBody();
    if (kDebugMode) _saveForTests(body);
    final res = await ReviewApi.analyzeReviews(body);
    if (_disposed) return;
    if (res == null) {
      analysisError = "We read $total reviews but couldn't reach our server to analyse them. Please check your internet and try again.";
      stage = JobStage.failed;
    } else {
      analysis = res;
      stage = JobStage.done;
    }
    _changed();
  }

  /// Debug builds only: keep the real collected reviews so they can be
  /// pulled with adb and used as golden tests / demo data.
  Future<void> _saveForTests(Map<String, dynamic> body) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final id = '${link?.platform.name}_${link?.productId}';
      await File('${dir.path}/collected_$id.json').writeAsString(jsonEncode(body));
    } catch (_) {}
  }

  Future<void> retryAnalysis() async {
    analysisError = null;
    await analyse();
  }

  void _closeReaders() {
    for (final r in allReaders) {
      r.dispose();
    }
    readers.clear();
    searchReaders.clear();
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _watchdog?.cancel();
    for (final c in _collectors) {
      c.stop();
    }
    for (final h in List.of(handoffs)) {
      h.skip();
    }
    for (final r in allReaders) {
      r.dispose();
    }
    super.dispose();
  }
}
