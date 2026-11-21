import 'package:flutter/material.dart';
import '../models/analysis_result.dart';

enum AnalysisState { idle, loading, success, error }

class AnalysisProvider extends ChangeNotifier {
  AnalysisState _state = AnalysisState.idle;
  AnalysisResult? _result;
  String? _errorMessage;

  AnalysisState get state => _state;
  AnalysisResult? get result => _result;
  String? get errorMessage => _errorMessage;

  void setLoading() {
    _state = AnalysisState.loading;
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }

  void setResult(AnalysisResult result) {
    _state = AnalysisState.success;
    _result = result;
    notifyListeners();
  }

  void setError(String message) {
    _state = AnalysisState.error;
    _errorMessage = message;
    notifyListeners();
  }

  void reset() {
    _state = AnalysisState.idle;
    _result = null;
    _errorMessage = null;
    notifyListeners();
  }
}