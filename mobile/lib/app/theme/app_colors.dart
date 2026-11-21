import 'package:flutter/material.dart';

/// HTH Design System — Color Palette
/// Deep navy/indigo primary with teal accents.
/// Semantic colors for urgency, sentiment, and confidence.
class AppColors {
  AppColors._();

  // ─── Brand Colors ───────────────────────────────────────
  static const Color primaryNavy = Color(0xFF0A1628);
  static const Color primaryIndigo = Color(0xFF2D3A8C);
  static const Color primaryBlue = Color(0xFF3B5BDB);
  static const Color accentTeal = Color(0xFF15AABF);
  static const Color accentCyan = Color(0xFF22B8CF);
  static const Color accentMint = Color(0xFF38D9A9);

  // ─── Gradient Definitions ──────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryIndigo, primaryBlue],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primaryNavy, Color(0xFF1A2744)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentTeal, accentMint],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A1628), Color(0xFF1A2744), Color(0xFF2D3A8C)],
  );

  // ─── Urgency Colors ────────────────────────────────────
  static const Color urgencyLow = Color(0xFF40C057);
  static const Color urgencyMedium = Color(0xFFFCC419);
  static const Color urgencyHigh = Color(0xFFFF922B);
  static const Color urgencyCritical = Color(0xFFFF6B6B);

  static const Color urgencyLowBg = Color(0x1A40C057);
  static const Color urgencyMediumBg = Color(0x1AFCC419);
  static const Color urgencyHighBg = Color(0x1AFF922B);
  static const Color urgencyCriticalBg = Color(0x1AFF6B6B);

  static Color getUrgencyColor(String urgency) {
    switch (urgency.toUpperCase()) {
      case 'LOW':
        return urgencyLow;
      case 'MEDIUM':
        return urgencyMedium;
      case 'HIGH':
        return urgencyHigh;
      case 'CRITICAL':
        return urgencyCritical;
      default:
        return urgencyMedium;
    }
  }

  static Color getUrgencyBgColor(String urgency) {
    switch (urgency.toUpperCase()) {
      case 'LOW':
        return urgencyLowBg;
      case 'MEDIUM':
        return urgencyMediumBg;
      case 'HIGH':
        return urgencyHighBg;
      case 'CRITICAL':
        return urgencyCriticalBg;
      default:
        return urgencyMediumBg;
    }
  }

  // ─── Sentiment Colors ──────────────────────────────────
  static const Color sentimentPositive = Color(0xFF51CF66);
  static const Color sentimentNeutral = Color(0xFFADB5BD);
  static const Color sentimentNegative = Color(0xFFFF922B);
  static const Color sentimentFrustrated = Color(0xFFFF6B6B);

  static Color getSentimentColor(String sentiment) {
    switch (sentiment.toUpperCase()) {
      case 'POSITIVE':
        return sentimentPositive;
      case 'NEUTRAL':
        return sentimentNeutral;
      case 'NEGATIVE':
        return sentimentNegative;
      case 'FRUSTRATED':
        return sentimentFrustrated;
      default:
        return sentimentNeutral;
    }
  }

  // ─── Confidence Meter Colors ───────────────────────────
  static const Color confidenceLow = Color(0xFFFF6B6B);
  static const Color confidenceMid = Color(0xFFFCC419);
  static const Color confidenceHigh = Color(0xFF51CF66);

  static Color getConfidenceColor(double confidence) {
    if (confidence < 0.5) return confidenceLow;
    if (confidence < 0.75) return confidenceMid;
    return confidenceHigh;
  }

  // ─── Surface Colors (Light) ────────────────────────────
  static const Color surfaceLight = Color(0xFFF8F9FA);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF1F3F5);
  static const Color borderLight = Color(0xFFE9ECEF);
  static const Color dividerLight = Color(0xFFDEE2E6);

  // ─── Surface Colors (Dark) ─────────────────────────────
  static const Color surfaceDark = Color(0xFF0D1B2A);
  static const Color surfaceDarkCard = Color(0xFF152238);
  static const Color surfaceDarkElevated = Color(0xFF1B2D45);
  static const Color borderDark = Color(0xFF2A3F5F);
  static const Color dividerDark = Color(0xFF1E3050);

  // ─── Text Colors ───────────────────────────────────────
  static const Color textPrimaryLight = Color(0xFF212529);
  static const Color textSecondaryLight = Color(0xFF6C757D);
  static const Color textTertiaryLight = Color(0xFFADB5BD);

  static const Color textPrimaryDark = Color(0xFFF8F9FA);
  static const Color textSecondaryDark = Color(0xFFADB5BD);
  static const Color textTertiaryDark = Color(0xFF6C757D);

  // ─── Status Colors ─────────────────────────────────────
  static const Color success = Color(0xFF40C057);
  static const Color warning = Color(0xFFFCC419);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF339AF0);

  // ─── Department Colors ─────────────────────────────────
  static const Map<String, Color> departmentColors = {
    'billing': Color(0xFF845EF7),
    'payments': Color(0xFF845EF7),
    'technical': Color(0xFF339AF0),
    'logistics': Color(0xFFFF922B),
    'shipping': Color(0xFFFF922B),
    'account': Color(0xFF20C997),
    'general': Color(0xFFADB5BD),
    'security': Color(0xFFFF6B6B),
    'product': Color(0xFF5C7CFA),
    'refund': Color(0xFFF06595),
  };

  static Color getDepartmentColor(String department) {
    final key = department.toLowerCase().replaceAll(' ', '_');
    return departmentColors[key] ?? accentTeal;
  }

  // ─── XAI Highlight Colors ─────────────────────────────
  static const Color xaiLowImportance = Color(0x333B5BDB);
  static const Color xaiMedImportance = Color(0x663B5BDB);
  static const Color xaiHighImportance = Color(0xCC3B5BDB);
  static const Color xaiMaxImportance = Color(0xFF3B5BDB);

  static Color getImportanceColor(double score) {
    // score 0.0 → 1.0
    if (score < 0.25) return xaiLowImportance;
    if (score < 0.5) return xaiMedImportance;
    if (score < 0.75) return xaiHighImportance;
    return xaiMaxImportance;
  }
}
