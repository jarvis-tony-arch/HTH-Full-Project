/// Issue model — a single detected issue label with its confidence score.
class Issue {
  final String label;
  final double confidence;
  final String displayName;

  const Issue({
    required this.label,
    required this.confidence,
    String? displayName,
  }) : displayName = displayName ?? label;

  factory Issue.fromJson(Map<String, dynamic> json) => Issue(
        label: json['label'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        displayName: json['display_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'confidence': confidence,
        'display_name': displayName,
      };

  /// Human-readable label: snake_case → Title Case
  String get formattedLabel =>
      displayName.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');

  /// Confidence as percentage string
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(0)}%';
}
