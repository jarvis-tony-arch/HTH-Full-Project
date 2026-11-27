import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One analysed product, kept on the phone only.
class SavedAnalysis {
  final String id;
  final DateTime savedAt;
  final Map<String, dynamic> result;
  final bool demo;
  const SavedAnalysis({required this.id, required this.savedAt, required this.result, this.demo = false});

  Map<String, dynamic> get product => (result['product'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get verdict => (result['verdict'] as Map?)?.cast<String, dynamic>() ?? const {};
  String get title => (product['title'] as String?)?.trim().isNotEmpty == true ? product['title'] as String : 'Product';

  Map<String, dynamic> toJson() => {'id': id, 'saved_at': savedAt.toIso8601String(), 'result': result, 'demo': demo};

  factory SavedAnalysis.fromJson(Map<String, dynamic> j) => SavedAnalysis(
        id: j['id'] as String,
        savedAt: DateTime.tryParse(j['saved_at'] as String? ?? '') ?? DateTime.now(),
        result: (j['result'] as Map).cast<String, dynamic>(),
        demo: (j['demo'] ?? false) as bool,
      );
}

class HistoryStore extends ChangeNotifier {
  static const _key = 'review_history_v1';
  static const _max = 20;
  final List<SavedAnalysis> _items = [];
  List<SavedAnalysis> get items => List.unmodifiable(_items);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _items
          ..clear()
          ..addAll((jsonDecode(raw) as List).map((e) => SavedAnalysis.fromJson((e as Map).cast<String, dynamic>())));
      }
    } catch (_) {
      // A broken store must never stop the app opening.
    }
    notifyListeners();
  }

  Future<void> add(SavedAnalysis a) async {
    _items.removeWhere((x) => x.id == a.id);
    _items.insert(0, a);
    if (_items.length > _max) _items.removeRange(_max, _items.length);
    await _save();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((x) => x.id == id);
    await _save();
  }

  Future<void> clear() async {
    _items.clear();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_items.map((e) => e.toJson()).toList()));
    } catch (_) {}
    notifyListeners();
  }
}
