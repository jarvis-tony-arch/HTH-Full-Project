import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hth_support/features/reviews/link_parser.dart';

void main() {
  group('extractUrl', () {
    test('finds the URL inside Amazon share text', () {
      final u = extractUrl('Check this out: boAt Airdopes 141 https://amzn.in/d/2xYzAbc Hurry!');
      expect(u.toString(), 'https://amzn.in/d/2xYzAbc');
    });
    test('drops trailing punctuation', () {
      expect(extractUrl('see https://www.myntra.com/123456789.').toString(), 'https://www.myntra.com/123456789');
    });
    test('handles a bare www link', () {
      expect(extractUrl('www.flipkart.com/x/p/itmabc?pid=ABCDEFGHIJKLMNOP')?.host, 'www.flipkart.com');
    });
    test('null when there is no link', () {
      expect(extractUrl('hello there'), isNull);
    });
  });

  group('identify', () {
    test('Amazon /dp/ ASIN', () {
      final l = identify(Uri.parse('https://www.amazon.in/boAt-Airdopes-141/dp/B09N3ZNHTY/ref=sr_1_1?th=1'))!;
      expect(l.platform, Platform.amazon);
      expect(l.productId, 'B09N3ZNHTY');
      expect(l.canonical.toString(), 'https://www.amazon.in/dp/B09N3ZNHTY');
    });
    test('Amazon gp/aw/d mobile link', () {
      expect(identify(Uri.parse('https://m.amazon.in/gp/aw/d/B0CHX1W1XY'))!.productId, 'B0CHX1W1XY');
    });
    test('Flipkart pid', () {
      final l = identify(Uri.parse(
          'https://www.flipkart.com/boat-airdopes/p/itm8f1c2d3e4f5a6?pid=ACCG6UFDFGHTZB8J&lid=x&marketplace=FLIPKART'))!;
      expect(l.platform, Platform.flipkart);
      expect(l.productId, 'ACCG6UFDFGHTZB8J');
      expect(l.canonical.queryParameters.keys, ['pid']);
    });
    test('Flipkart without pid falls back to itm id', () {
      expect(identify(Uri.parse('https://dl.flipkart.com/s/p/itmabc123'))!.productId, 'itmabc123');
    });
    test('Myntra style ID', () {
      final l = identify(Uri.parse('https://www.myntra.com/tshirts/roadster/roadster-men-black-tshirt/12345678/buy'))!;
      expect(l.platform, Platform.myntra);
      expect(l.productId, '12345678');
    });
    test('Amazon search page is not a product', () {
      expect(identify(Uri.parse('https://www.amazon.in/s?k=earbuds')), isNull);
    });
    test('unknown site', () {
      expect(identify(Uri.parse('https://example.com/p/123')), isNull);
    });
  });

  group('readSharedText', () {
    test('expands a short link by following redirects', () async {
      final client = MockClient((req) async {
        if (req.url.host == 'amzn.in') {
          return http.Response('', 301, headers: {'location': 'https://www.amazon.in/dp/B09N3ZNHTY?ref=share'});
        }
        return http.Response('ok', 200);
      });
      final r = await readSharedText('Look https://amzn.in/d/abc', client: client);
      expect(r.link?.productId, 'B09N3ZNHTY');
    });
    test('friendly message for a non-product link', () async {
      final r = await readSharedText('https://www.youtube.com/watch?v=x',
          client: MockClient((_) async => http.Response('', 200)));
      expect(r.link, isNull);
      expect(r.problem, unsupportedMessage);
    });
    test('AJIO is recognised but not shareable yet', () async {
      final r = await readSharedText('https://www.ajio.com/x/p/469123456_black',
          client: MockClient((_) async => http.Response('', 200)));
      expect(r.problem, unsupportedMessage);
    });
  });
}
