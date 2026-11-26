import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// Cases live on the phone only (no new server tables today).
class CasesStore extends ChangeNotifier {
  static const _key = 'resolve_cases_v1';
  final List<SavedCase> _cases = [];
  bool _loaded = false;

  List<SavedCase> get all => List.unmodifiable(_cases);
  List<SavedCase> get open => _cases.where((c) => !c.solved).toList();
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        _cases
          ..clear()
          ..addAll((jsonDecode(raw) as List)
              .map((e) => SavedCase.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {
      // A corrupt store should never stop the app from opening.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_cases.map((c) => c.toJson()).toList()));
    notifyListeners();
  }

  SavedCase? byId(String id) {
    for (final c in _cases) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Saves each issue of a result as its own case. Returns the new cases.
  Future<List<SavedCase>> addFromResult(ResolveResult r, String userText) async {
    final now = DateTime.now();
    final added = <SavedCase>[];
    for (var i = 0; i < r.issues.length; i++) {
      final issue = r.issues[i];
      final c = SavedCase(
        id: '${now.microsecondsSinceEpoch}_$i',
        section: r.section ?? 'shopping',
        companyId: r.company,
        companyName: r.companyName,
        userText: userText,
        issue: issue,
        currentLevel: issue.startLevel,
        stepStartedAt: now,
        createdAt: now,
        evidence: [EvidenceEntry(now, 'Case opened: ${issue.summary}')],
      );
      _cases.insert(0, c);
      added.add(c);
    }
    await _save();
    return added;
  }

  Future<void> nextStep(SavedCase c) async {
    if (!c.hasNextStep) return;
    final from = c.currentStep.title;
    c.currentLevel = c.issue.steps.firstWhere((s) => s.level > c.currentLevel).level;
    c.stepStartedAt = DateTime.now();
    c.evidence.add(EvidenceEntry(DateTime.now(), "Moved on: '$from' didn't work. Next: ${c.currentStep.title}"));
    await _save();
  }

  Future<void> log(SavedCase c, String what, {String? ticket}) async {
    c.evidence.add(EvidenceEntry(DateTime.now(), what, ticket));
    await _save();
  }

  Future<void> markSolved(SavedCase c) async {
    c.solved = true;
    c.evidence.add(EvidenceEntry(DateTime.now(), 'Marked as solved'));
    await _save();
  }

  Future<void> remove(SavedCase c) async {
    _cases.removeWhere((x) => x.id == c.id);
    await _save();
  }
}
