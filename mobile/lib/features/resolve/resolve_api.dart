import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/api_service.dart';
import 'models.dart';

/// Thrown with a friendly message the screens can show as-is.
class FriendlyError implements Exception {
  final String message;
  FriendlyError(this.message);
  @override
  String toString() => message;
}

class ResolveApi {
  ResolveApi._();

  static const timeout = Duration(seconds: 60);

  /// Same data as GET /sections, bundled so Home works before the
  /// server wakes up. Refreshed from the server when available.
  static final List<SectionInfo> fallbackSections = [
    SectionInfo('shopping', 'Shopping', 'Orders, clothes, refunds', [
      'Flipkart refund nahi aaya 10 din se',
      'Myntra kurta size chota hai, return karna hai',
      'Amazon order late hai aur box toota hua aaya',
    ], [
      SectionCompany('amazon', 'Amazon', 'A'),
      SectionCompany('flipkart', 'Flipkart', 'F'),
      SectionCompany('myntra', 'Myntra', 'M'),
      SectionCompany('ajio', 'AJIO', 'A'),
      SectionCompany('meesho', 'Meesho', 'M'),
    ]),
    SectionInfo('travel', 'Travel', 'Flights and trains', [
      'IndiGo flight 7 ghante late tha, khana bhi nahi diya',
      'Air India cancelled my flight 2 hours before departure',
      'Train 4 ghante late hai, abhi nikli nahi, refund chahiye',
    ], [
      SectionCompany('indigo', 'IndiGo', 'I'),
      SectionCompany('air_india', 'Air India', 'A'),
      SectionCompany('akasa_air', 'Akasa Air', 'A'),
      SectionCompany('spicejet', 'SpiceJet', 'S'),
      SectionCompany('indian_railways', 'Indian Railways (IRCTC)', 'I'),
    ]),
  ];

  static Future<List<SectionInfo>> sections() async {
    try {
      final r = await http
          .get(Uri.parse('${ApiService.baseUrl}/sections'))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) {
        final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
        return (j['sections'] as List)
            .map((e) => SectionInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {/* fall back silently */}
    return fallbackSections;
  }

  static Future<ResolveResult> resolve({
    required String text,
    String? section,
    String? company,
    String? issueType,
  }) async {
    final body = <String, dynamic>{'text': text};
    if (section != null) body['section'] = section;
    if (company != null) body['company'] = company;
    if (issueType != null) body['issue_type'] = issueType;
    try {
      final r = await http
          .post(
            Uri.parse('${ApiService.baseUrl}/resolve'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      if (r.statusCode == 200) {
        // utf8.decode keeps ₹ and Hindi text intact.
        return ResolveResult.fromJson(
            jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
      }
      throw FriendlyError("Something went wrong on our side. Please try again.");
    } on TimeoutException {
      throw FriendlyError("The server is taking too long. Please check your internet and try again.");
    } on FriendlyError {
      rethrow;
    } catch (_) {
      throw FriendlyError("We couldn't reach the server. Please check your internet and try again.");
    }
  }
}
