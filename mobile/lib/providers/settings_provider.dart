import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  double _confidenceThreshold = 0.65;
  bool _voiceEnabled = true;
  String _voiceLocale = 'en_IN';

  double get confidenceThreshold => _confidenceThreshold;
  bool get voiceEnabled => _voiceEnabled;
  String get voiceLocale => _voiceLocale;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _confidenceThreshold = prefs.getDouble('threshold') ?? 0.65;
    _voiceEnabled = prefs.getBool('voice') ?? true;
    _voiceLocale = prefs.getString('voiceLocale') ?? 'en_IN';
    notifyListeners();
  }

  Future<void> setThreshold(double v) async {
    _confidenceThreshold = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('threshold', v);
  }

  Future<void> setVoiceEnabled(bool v) async {
    _voiceEnabled = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice', v);
  }

  Future<void> setVoiceLocale(String v) async {
    _voiceLocale = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('voiceLocale', v);
  }
}