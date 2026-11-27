import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';

/// Backend calls for the review analyser. All return null on failure;
/// the screens explain what's missing instead of guessing.
class ReviewApi {
  ReviewApi._();

  static Future<Map<String, dynamic>?> _post(String path, Object body, {Duration timeout = const Duration(seconds: 45)}) async {
    try {
      final r = await http
          .post(Uri.parse('${ApiService.baseUrl}$path'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(timeout);
      if (r.statusCode == 200) {
        return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Wakes the Render server while the phone is still reading pages.
  static void wake() {
    http.get(Uri.parse('${ApiService.baseUrl}/health')).timeout(const Duration(seconds: 60)).catchError((_) => http.Response('', 0));
  }

  static Future<Map<String, dynamic>?> matchProducts(Map<String, dynamic> product, List<Map<String, dynamic>> candidates) =>
      _post('/match-products', {'product': product, 'candidates': candidates}, timeout: const Duration(seconds: 30));

  static Future<Map<String, dynamic>?> independentOpinions(String query) =>
      _post('/independent-opinions', {'query': query}, timeout: const Duration(seconds: 30));

  static Future<Map<String, dynamic>?> analyzeReviews(Map<String, dynamic> body) =>
      _post('/analyze-reviews', body, timeout: const Duration(seconds: 60));
}
