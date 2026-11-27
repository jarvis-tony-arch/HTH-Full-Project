import 'link_parser.dart';

/// One review exactly as the shopping page showed it. Reviewer names are
/// never collected.
class Review {
  final String platform;
  final String id;
  final String title;
  final String text;
  final double rating;
  final String dateRaw;
  final bool? verified;
  final String variant;
  final int helpful;

  const Review({
    required this.platform,
    this.id = '',
    this.title = '',
    required this.text,
    required this.rating,
    this.dateRaw = '',
    this.verified,
    this.variant = '',
    this.helpful = 0,
  });

  /// Used to drop the same review seen twice (e.g. product page + page 1).
  String get key => id.isNotEmpty ? '$platform:$id' : '$platform:${rating.round()}:${title.toLowerCase()}:${text.toLowerCase()}';

  factory Review.fromPage(String platform, Map<String, dynamic> j) => Review(
        platform: platform,
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        dateRaw: (j['date_raw'] ?? '') as String,
        verified: j['verified'] as bool?,
        variant: (j['variant'] ?? '') as String,
        helpful: (j['helpful'] as num?)?.toInt() ?? 0,
      );

  factory Review.fromJson(Map<String, dynamic> j) => Review.fromPage(j['platform'] as String, j);

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'id': id,
        'title': title,
        'text': text,
        'rating': rating,
        'date_raw': dateRaw,
        'verified': verified,
        'variant': variant,
        'helpful': helpful,
      };
}

/// What the product page says about itself.
class ProductMeta {
  final String platform;
  final String productId;
  final String url;
  final String title;
  final String brand;
  final String model;
  final String variant;
  final double? price;
  final String image;
  final double? rating;
  final int? ratingCount;
  final Map<String, double> histogram; // "5" -> share 0..1
  final Map<String, String> specs;
  final String fitSummary;

  const ProductMeta({
    required this.platform,
    required this.productId,
    required this.url,
    this.title = '',
    this.brand = '',
    this.model = '',
    this.variant = '',
    this.price,
    this.image = '',
    this.rating,
    this.ratingCount,
    this.histogram = const {},
    this.specs = const {},
    this.fitSummary = '',
  });

  factory ProductMeta.fromPage(ProductLink link, Map<String, dynamic> j) => ProductMeta(
        platform: link.platform.name,
        productId: link.productId,
        url: link.canonical.toString(),
        title: (j['title'] ?? '') as String,
        brand: (j['brand'] ?? '') as String,
        model: (j['model'] ?? '') as String,
        variant: (j['variant'] ?? '') as String,
        price: (j['price'] as num?)?.toDouble(),
        image: (j['image'] ?? '') as String,
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: (j['rating_count'] as num?)?.toInt(),
        histogram: ((j['histogram'] ?? {}) as Map).map((k, v) => MapEntry('$k', (v as num).toDouble())),
        specs: ((j['specs'] ?? {}) as Map).map((k, v) => MapEntry('$k', '$v')),
        fitSummary: (j['fit_summary'] ?? '') as String,
      );

  factory ProductMeta.fromJson(Map<String, dynamic> j) => ProductMeta(
        platform: j['platform'] as String,
        productId: (j['product_id'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        brand: (j['brand'] ?? '') as String,
        model: (j['model'] ?? '') as String,
        variant: (j['variant'] ?? '') as String,
        price: (j['price'] as num?)?.toDouble(),
        image: (j['image'] ?? '') as String,
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: (j['rating_count'] as num?)?.toInt(),
        histogram: ((j['histogram'] ?? {}) as Map).map((k, v) => MapEntry('$k', (v as num).toDouble())),
        specs: ((j['specs'] ?? {}) as Map).map((k, v) => MapEntry('$k', '$v')),
        fitSummary: (j['fit_summary'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'product_id': productId,
        'url': url,
        'title': title,
        'brand': brand,
        'model': model,
        'variant': variant,
        'price': price,
        'image': image,
        'rating': rating,
        'rating_count': ratingCount,
        'histogram': histogram,
        'specs': specs,
        'fit_summary': fitSummary,
      };
}

enum SourceState { waiting, reading, needsUser, done, failed, skipped }

/// Reviews gathered from one listing (one platform).
class SourceReviews {
  final ProductLink link;
  ProductMeta? meta;
  final List<Review> reviews = [];
  final Set<String> _keys = {};
  SourceState state = SourceState.waiting;

  /// Why collection stopped early, in plain words (sign-in skipped, timeout…).
  String note = '';

  SourceReviews(this.link);

  String get platform => link.platform.name;

  /// Adds new reviews, returns how many were actually new.
  int addAll(Iterable<Review> list) {
    var n = 0;
    for (final r in list) {
      if (r.text.trim().isEmpty && r.title.trim().isEmpty) continue;
      if (_keys.add(r.key)) {
        reviews.add(r);
        n++;
      }
    }
    return n;
  }
}
