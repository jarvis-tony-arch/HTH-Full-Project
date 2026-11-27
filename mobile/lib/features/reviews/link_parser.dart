import 'dart:async';
import 'package:http/http.dart' as http;

/// Shopping sites HTH knows about. The first three can be shared into the
/// app; the rest are only used when looking for the same product elsewhere.
enum Platform {
  amazon('Amazon'),
  flipkart('Flipkart'),
  myntra('Myntra'),
  ajio('AJIO'),
  nykaa('Nykaa'),
  croma('Croma'),
  reliance('Reliance Digital');

  final String label;
  const Platform(this.label);

  static Platform? byName(String? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

const shareablePlatforms = {Platform.amazon, Platform.flipkart, Platform.myntra};

/// One product listing identified from a URL.
class ProductLink {
  final Platform platform;

  /// Amazon ASIN, Flipkart pid (or itm id when no pid), Myntra style ID,
  /// or the platform's own product code for the others.
  final String productId;
  final Uri url;
  const ProductLink(this.platform, this.productId, this.url);

  /// A clean product page URL with tracking parameters removed.
  Uri get canonical => switch (platform) {
        Platform.amazon => Uri.https('www.amazon.in', '/dp/$productId'),
        Platform.myntra => Uri.https('www.myntra.com', '/$productId'),
        Platform.flipkart => _flipkartCanonical(),
        _ => url.replace(queryParameters: const {}, fragment: ''),
      };

  Uri _flipkartCanonical() {
    final pid = url.queryParameters['pid'];
    return Uri.https(url.host.isEmpty ? 'www.flipkart.com' : url.host, url.path,
        pid == null ? null : {'pid': pid});
  }

  Map<String, dynamic> toJson() =>
      {'platform': platform.name, 'product_id': productId, 'url': url.toString()};

  static ProductLink? fromJson(Map<String, dynamic> j) {
    final p = Platform.byName(j['platform'] as String?);
    final u = Uri.tryParse(j['url'] as String? ?? '');
    if (p == null || u == null) return null;
    return ProductLink(p, j['product_id'] as String, u);
  }

  @override
  String toString() => '${platform.label} $productId';
}

/// Shared text looks like "Check out this product on Amazon https://amzn.in/d/abc
/// Hurry!", so pull out the first http(s) URL.
Uri? extractUrl(String sharedText) {
  final m = RegExp(r'''https?://[^\s<>"'()]+''', caseSensitive: false).firstMatch(sharedText);
  if (m == null) {
    // Some apps share "www.flipkart.com/..." without a scheme.
    final bare = RegExp(r'''\b(?:www\.|m\.)?(?:amazon\.in|flipkart\.com|myntra\.com)/[^\s<>"']*''',
            caseSensitive: false)
        .firstMatch(sharedText);
    return bare == null ? null : Uri.tryParse('https://${_trimTail(bare.group(0)!)}');
  }
  return Uri.tryParse(_trimTail(m.group(0)!));
}

String _trimTail(String s) => s.replaceFirst(RegExp(r'[.,;:!?\]]+$'), '');

const _shortHosts = {
  'amzn.in', 'amzn.to', 'amzn.eu', 'a.co',
  'dl.flipkart.com', 'fkrt.it', 'fkrt.cc', 'fkrt.co',
  'myntr.it', 'myntr.in',
};

bool isShortLink(Uri u) => _shortHosts.contains(u.host.toLowerCase());

String _host(Uri u) => u.host.toLowerCase().replaceFirst(RegExp(r'^(www|m)\.'), '');

/// Identify platform + product ID from a full (already expanded) URL.
ProductLink? identify(Uri u) {
  final host = _host(u);
  final path = u.path;

  if (host == 'amazon.in' || host == 'amazon.com' || host.endsWith('.amazon.in')) {
    final m = RegExp(r'/(?:dp|gp/product|gp/aw/d|product-reviews|gp/offer-listing)/([A-Z0-9]{10})(?:[/?]|$)',
            caseSensitive: false)
        .firstMatch(path);
    final asin = m?.group(1) ?? u.queryParameters['asin'];
    if (asin != null && RegExp(r'^[A-Z0-9]{10}$', caseSensitive: false).hasMatch(asin)) {
      return ProductLink(Platform.amazon, asin.toUpperCase(), u);
    }
    return null;
  }

  if (host == 'flipkart.com' || host.endsWith('.flipkart.com')) {
    final pid = u.queryParameters['pid'];
    if (pid != null && RegExp(r'^[A-Z0-9]{16}$', caseSensitive: false).hasMatch(pid)) {
      return ProductLink(Platform.flipkart, pid.toUpperCase(), u);
    }
    // Product pages always carry an "itm..." id in /p/ or /product-reviews/.
    final m = RegExp(r'/(?:p|product-reviews)/(itm[a-z0-9]+)', caseSensitive: false).firstMatch(path);
    if (m != null) return ProductLink(Platform.flipkart, m.group(1)!, u);
    return null;
  }

  if (host == 'myntra.com') {
    // /tshirts/roadster/roadster-men-.../12345678/buy  or  /12345678
    final m = RegExp(r'/(\d{6,10})(?:/buy)?/?$').firstMatch(path) ??
        RegExp(r'/reviews/(\d{6,10})').firstMatch(path);
    if (m != null) return ProductLink(Platform.myntra, m.group(1)!, u);
    return null;
  }

  if (host == 'ajio.com') {
    final m = RegExp(r'/p/([a-z0-9_]+)', caseSensitive: false).firstMatch(path);
    return m == null ? null : ProductLink(Platform.ajio, m.group(1)!, u);
  }
  if (host == 'nykaa.com' || host == 'nykaafashion.com') {
    final m = RegExp(r'/p/(\d+)').firstMatch(path);
    return m == null ? null : ProductLink(Platform.nykaa, m.group(1)!, u);
  }
  if (host == 'croma.com') {
    final m = RegExp(r'/p/(\d+)').firstMatch(path);
    return m == null ? null : ProductLink(Platform.croma, m.group(1)!, u);
  }
  if (host == 'reliancedigital.in') {
    final m = RegExp(r'/p/(\d+)').firstMatch(path) ?? RegExp(r'/(\d{6,})/?$').firstMatch(path);
    return m == null ? null : ProductLink(Platform.reliance, m.group(1)!, u);
  }
  return null;
}

/// Follows redirects by hand (max 8 hops) so we can see the final URL of
/// short links like amzn.in/d/xyz. Stops early once a product is recognised.
Future<Uri> expandShortLink(Uri u, {http.Client? client}) async {
  final c = client ?? http.Client();
  var current = u;
  try {
    for (var hop = 0; hop < 8; hop++) {
      if (identify(current) != null && !isShortLink(current)) return current;
      final req = http.Request('GET', current)
        ..followRedirects = false
        ..headers['User-Agent'] =
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';
      final res = await c.send(req).timeout(const Duration(seconds: 10));
      final loc = res.headers['location'];
      await res.stream.drain<void>();
      if (res.isRedirect || (res.statusCode >= 300 && res.statusCode < 400 && loc != null)) {
        if (loc == null) break;
        current = current.resolve(loc);
        continue;
      }
      break;
    }
  } on TimeoutException {
    // Use what we have; the webview can still follow JS redirects later.
  } catch (_) {
    // Network errors: same.
  } finally {
    if (client == null) c.close();
  }
  return current;
}

/// The result of reading a shared message.
class LinkResult {
  final ProductLink? link;
  final String? problem; // friendly message when link is null
  const LinkResult.ok(ProductLink this.link) : problem = null;
  const LinkResult.fail(String this.problem) : link = null;
}

const unsupportedMessage = 'Share a product from Amazon, Flipkart or Myntra';

/// Shared text → supported product link, or a friendly problem message.
Future<LinkResult> readSharedText(String text, {http.Client? client}) async {
  final url = extractUrl(text);
  if (url == null) return const LinkResult.fail(unsupportedMessage);
  final full = isShortLink(url) || identify(url) == null ? await expandShortLink(url, client: client) : url;
  final link = identify(full);
  if (link == null || !shareablePlatforms.contains(link.platform)) {
    return const LinkResult.fail(unsupportedMessage);
  }
  return LinkResult.ok(link);
}
