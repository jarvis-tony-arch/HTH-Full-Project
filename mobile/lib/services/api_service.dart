import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  /// Changed from the Settings screen. On a real phone this must be your
  /// laptop's LAN IP (http://192.168.x.x:8000) or a tunnel URL (https://...).
  static String baseUrl = 'https://hth-backend-5q9g.onrender.com';
  static const String _prefKey = 'backend_url';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_prefKey) ?? baseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    var clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    baseUrl = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, clean);
  }

  static Future<bool> health() async {
    try {
      final r = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 6));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> analyzeQuery(String text) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      // utf8.decode(bodyBytes) is required, otherwise Hindi/Telugu text breaks.
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    throw Exception('Server error: ${response.statusCode}');
  }
    // --- Save a ticket to the Neon database ---
  static Future<bool> createTicket(Map<String, dynamic> ticketData) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tickets'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(ticketData),
      ).timeout(const Duration(seconds: 15));
      
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Error saving ticket: $e");
      return false;
    }
  }

  // --- Fetch all tickets from the Neon database ---
  static Future<List<dynamic>> getTickets() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tickets'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes)) as List;
      }
      return [];
    } catch (e) {
      print("Error fetching tickets: $e");
      return [];
    }
  }
}