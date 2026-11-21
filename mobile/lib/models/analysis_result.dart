import 'issue.dart';
import 'entity.dart';
import 'department.dart';
import 'similar_ticket.dart';

/// Full analysis result from the NLP pipeline.
class AnalysisResult {
  final List<Issue> issues;
  final List<Entity> entities;
  final String urgency;
  final String sentiment;
  final double confidence;
  final bool escalatedToHuman;
  final List<Department> routing;
  final String explanation;
  final Map<String, double> wordImportance;
  final String aiTitle;
  final String aiSummary;
  final List<SimilarTicket> similarTickets;
  final int inferenceMs;

  const AnalysisResult({
    required this.issues,
    required this.entities,
    required this.urgency,
    required this.sentiment,
    required this.confidence,
    required this.escalatedToHuman,
    required this.routing,
    required this.explanation,
    required this.wordImportance,
    required this.aiTitle,
    required this.aiSummary,
    required this.similarTickets,
    required this.inferenceMs,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
        issues: (json['issues'] as List<dynamic>)
            .map((e) => Issue.fromJson(e as Map<String, dynamic>))
            .toList(),
        entities: (json['entities'] as List<dynamic>)
            .map((e) => Entity.fromJson(e as Map<String, dynamic>))
            .toList(),
        urgency: json['urgency'] as String,
        sentiment: json['sentiment'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        escalatedToHuman: json['escalated_to_human'] as bool? ?? false,
        routing: (json['routing'] as List<dynamic>)
            .map((e) => Department.fromJson(e as Map<String, dynamic>))
            .toList(),
        explanation: json['explanation'] as String,
        wordImportance:
            (json['word_importance'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, (v as num).toDouble()),
                ) ??
                {},
        aiTitle: json['ai_title'] as String,
        aiSummary: json['ai_summary'] as String,
        similarTickets: (json['similar_tickets'] as List<dynamic>?)
                ?.map((e) => SimilarTicket.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        inferenceMs: json['inference_ms'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'issues': issues.map((e) => e.toJson()).toList(),
        'entities': entities.map((e) => e.toJson()).toList(),
        'urgency': urgency,
        'sentiment': sentiment,
        'confidence': confidence,
        'escalated_to_human': escalatedToHuman,
        'routing': routing.map((e) => e.toJson()).toList(),
        'explanation': explanation,
        'word_importance': wordImportance,
        'ai_title': aiTitle,
        'ai_summary': aiSummary,
        'similar_tickets': similarTickets.map((e) => e.toJson()).toList(),
        'inference_ms': inferenceMs,
      };

  /// Primary department (first one marked as primary, or first in list)
  Department? get primaryDepartment =>
      routing.isEmpty ? null : routing.firstWhere(
        (d) => d.isPrimary,
        orElse: () => routing.first,
      );

  /// Total number of issues detected
  int get issueCount => issues.length;

  /// Whether this is a multi-issue query
  bool get isMultiIssue => issues.length > 1;

  /// Highest confidence issue
  Issue? get topIssue =>
      issues.isEmpty ? null : (issues.toList()..sort((a, b) => b.confidence.compareTo(a.confidence))).first;
}
