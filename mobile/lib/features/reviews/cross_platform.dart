import 'package:flutter/foundation.dart' show debugPrint;
import 'link_parser.dart';
import 'models.dart';
import 'page_reader.dart';
import 'selectors.dart';

/// A product listing found on another shop's search page.
class Listing {
  final String platform, title, brand, url, image;
  final double? price, rating;
  final int? ratingCount;
  final bool sponsored;
  const Listing({
    required this.platform,
    required this.title,
    this.brand = '',
    required this.url,
    this.image = '',
    this.price,
    this.rating,
    this.ratingCount,
    this.sponsored = false,
  });

  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
        platform: (j['platform'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        brand: (j['brand'] ?? '') as String? ?? '',
        url: (j['url'] ?? '') as String? ?? '',
        image: (j['image'] ?? '') as String? ?? '',
        price: (j['price'] as num?)?.toDouble(),
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: (j['rating_count'] as num?)?.toInt(),
        sponsored: (j['sponsored'] ?? false) as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'title': title,
        'brand': brand,
        'url': url,
        'image': image,
        'price': price,
        'rating': rating,
        'rating_count': ratingCount,
        'sponsored': sponsored,
      };

  String get platformLabel => Platform.byName(platform)?.label ?? platform;
}

class MatchResult {
  final String decision; // match | possible | no_match
  final double confidence;
  final List<String> reasons;
  final Listing listing;

  /// For "possible" matches: null = not asked yet, true/false = user's answer.
  bool? userSaysSame;

  MatchResult(this.decision, this.confidence, this.reasons, this.listing);

  factory MatchResult.fromJson(Map<String, dynamic> j) => MatchResult(
        j['decision'] as String,
        (j['confidence'] as num).toDouble(),
        (j['reasons'] as List).cast<String>(),
        Listing.fromJson((j['candidate'] as Map).cast<String, dynamic>()),
      );

  Map<String, dynamic> toJson() => {
        'decision': decision,
        'confidence': confidence,
        'reasons': reasons,
        'candidate': listing.toJson(),
        'user_says_same': userSaysSame,
      };

  bool get confirmed => decision == 'match' || userSaysSame == true;
}

const _noise = {
  'new', 'launch', 'launched', 'latest', 'with', 'and', 'for', 'the', 'of', 'in', 'up', 'to', 'upto',
  'buy', 'online', 'best', 'price', 'india', 'pack', 'combo', 'edition', 'official', 'original',
  'genuine', 'free', 'offer', 'sale', 'deal', 'hot', 'bestseller', 'sponsored', 'men', 'women',
};
const _colours = {
  'black', 'white', 'blue', 'red', 'green', 'grey', 'gray', 'silver', 'gold', 'pink', 'purple',
  'yellow', 'orange', 'brown', 'beige', 'navy', 'maroon', 'olive', 'teal', 'cream', 'charcoal',
};

/// Brand + the first few model-ish words, without marketing words.
/// Mirrors product_matcher.search_query on the backend.
String searchQuery(ProductMeta m, {int maxWords = 6}) {
  String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[™®]'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9.+\s-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final brand = norm(m.brand).replaceFirst(RegExp(r'^(visit the|brand)\s+'), '').replaceAll(' store', '').trim();
  var ws = norm(m.title)
      .replaceAll('-', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty && !_noise.contains(w) && !_colours.contains(w) && !RegExp(r'^\d{4}$').hasMatch(w))
      .toList();
  if (brand.isNotEmpty && ws.isNotEmpty && ws.first == brand) ws = ws.sublist(1);
  final keep = <String>[];
  for (var i = 0; i < ws.length; i++) {
    final w = ws[i];
    if (keep.length >= maxWords) break;
    final next = i + 1 < ws.length ? ws[i + 1] : '';
    // Stop at specs ("48h", "50 hours", "128gb"); keep model numbers ("141", "gen 2").
    if (RegExp(r'^\d+(\.\d+)?(h|hrs?|hours?|mah|gb|tb|w|mm|ml|l|kg|g)$').hasMatch(w)) break;
    if (RegExp(r'^[\d.]+$').hasMatch(w) && RegExp(r'^(h|hrs?|hours?|mah|gb|tb|w|watt|mm|ml|kg)$').hasMatch(next)) break;
    keep.add(w);
  }
  return [if (brand.isNotEmpty) brand, ...keep].join(' ');
}

/// Which shops to look in, from the product's title.
List<String> shopsFor(ProductMeta m, SelectorConfig cfg) {
  final cats = (cfg.raw['categories'] as Map?)?.cast<String, dynamic>() ?? const {};
  final t = ' ${m.title.toLowerCase()} ';
  for (final name in ['fashion', 'beauty']) {
    final c = (cats[name] as Map?)?.cast<String, dynamic>();
    if (c == null) continue;
    final ws = (c['words'] as List).cast<String>();
    if (ws.any((w) => RegExp('\\b${RegExp.escape(w)}s?\\b').hasMatch(t))) {
      return (c['shops'] as List).cast<String>();
    }
  }
  if (m.platform == 'myntra') return ((cats['fashion'] as Map?)?['shops'] as List?)?.cast<String>() ?? const [];
  return ((cats['electronics'] as Map?)?['shops'] as List?)?.cast<String>() ?? const ['amazon', 'flipkart'];
}

/// Reads one shop's search results on the phone.
Future<List<Listing>> searchShop(PageReader reader, String platform, Map<String, dynamic> scfg, String query) async {
  final url = (scfg['url'] as String)
      .replaceAll('{q}', Uri.encodeQueryComponent(query))
      .replaceAll('{q_dash}', query.replaceAll(RegExp(r'\s+'), '-'));
  await reader.load(Uri.parse(url));
  final r = await reader.call('search', scfg);
  debugPrint('HTH searchShop $platform url=${reader.currentUrl} -> ${r == null ? 'null' : 'blocked=${r['blocked']} n=${(r['results'] as List?)?.length} err=${r['error']}'}');
  if (r == null || r['blocked'] != null) return const [];
  return (r['results'] as List? ?? const [])
      .whereType<Map>()
      .map((e) => Listing.fromJson({...e.cast<String, dynamic>(), 'platform': platform}))
      .where((l) => l.title.isNotEmpty && l.url.startsWith('http'))
      .take(8)
      .toList();
}
