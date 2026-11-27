import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';

/// Per-platform selectors for reading review pages. A copy is bundled in
/// the app; GET /review-selectors can ship a newer one, so a site layout
/// change can be fixed without a new APK.
class SelectorConfig {
  final int version;
  final Map<String, dynamic> raw;
  SelectorConfig(this.version, this.raw);

  Map<String, dynamic>? platform(String name) =>
      (raw['platforms'] as Map<String, dynamic>?)?[name] as Map<String, dynamic>?;
  Map<String, dynamic>? search(String name) =>
      (raw['search'] as Map<String, dynamic>?)?[name] as Map<String, dynamic>?;
  Iterable<String> get searchPlatforms => ((raw['search'] as Map?) ?? const {}).keys.cast<String>();

  static SelectorConfig? _cached;
  static const _prefKey = 'review_selectors_v1';

  static SelectorConfig _parse(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return SelectorConfig((j['version'] as num?)?.toInt() ?? 0, j);
  }

  /// Newest of: bundled, last downloaded, server. Never throws.
  static Future<SelectorConfig> load() async {
    if (_cached != null) return _cached!;
    var best = _parse(await rootBundle.loadString('assets/review_selectors.json'));
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        final c = _parse(saved);
        if (c.version > best.version) best = c;
      }
    } catch (_) {}
    try {
      final r = await http
          .get(Uri.parse('${ApiService.baseUrl}/review-selectors'))
          .timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final body = utf8.decode(r.bodyBytes);
        final c = _parse(body);
        if (c.version >= best.version && c.platform('amazon') != null) {
          best = c;
          await prefs?.setString(_prefKey, body);
        }
      }
    } catch (_) {
      // Server asleep or offline: the bundled copy is fine.
    }
    return _cached = best;
  }
}
