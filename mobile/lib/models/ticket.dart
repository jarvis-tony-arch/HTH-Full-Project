class Ticket {
  final String id;
  final String rawQuery;
  final String aiTitle;
  final String aiSummary;
  final String status;
  final String urgency;
  final String sentiment;
  final double confidence;
  final bool escalated;
  final List<String> issues;
  final List<String> departments;
  final DateTime createdAt;

  const Ticket({
    required this.id,
    required this.rawQuery,
    required this.aiTitle,
    required this.aiSummary,
    required this.status,
    required this.urgency,
    required this.sentiment,
    required this.confidence,
    required this.escalated,
    required this.issues,
    required this.departments,
    required this.createdAt,
  });

  Ticket copyWith({
    String? id,
    String? rawQuery,
    String? aiTitle,
    String? aiSummary,
    String? status,
    String? urgency,
    String? sentiment,
    double? confidence,
    bool? escalated,
    List<String>? issues,
    List<String>? departments,
    DateTime? createdAt,
  }) {
    return Ticket(
      id: id ?? this.id,
      rawQuery: rawQuery ?? this.rawQuery,
      aiTitle: aiTitle ?? this.aiTitle,
      aiSummary: aiSummary ?? this.aiSummary,
      status: status ?? this.status,
      urgency: urgency ?? this.urgency,
      sentiment: sentiment ?? this.sentiment,
      confidence: confidence ?? this.confidence,
      escalated: escalated ?? this.escalated,
      issues: issues ?? this.issues,
      departments: departments ?? this.departments,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Local storage JSON (keep this for now, just in case)
  Map<String, dynamic> toJson() => {
    'id': id,
    'rawQuery': rawQuery,
    'aiTitle': aiTitle,
    'aiSummary': aiSummary,
    'status': status,
    'urgency': urgency,
    'sentiment': sentiment,
    'confidence': confidence,
    'escalated': escalated,
    'issues': issues,
    'departments': departments,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
    id: json['id'],
    rawQuery: json['rawQuery'],
    aiTitle: json['aiTitle'],
    aiSummary: json['aiSummary'],
    status: json['status'],
    urgency: json['urgency'],
    sentiment: json['sentiment'],
    confidence: json['confidence'].toDouble(),
    escalated: json['escalated'],
    issues: List<String>.from(json['issues']),
    departments: List<String>.from(json['departments']),
    createdAt: DateTime.parse(json['createdAt']),
  );

  // --- NEW: Convert the ticket for the Python backend ---
  Map<String, dynamic> toBackendJson() {
    return {
      "ticket_id": id,
      "raw_query": rawQuery,
      "ai_title": aiTitle,
      "ai_summary": aiSummary,
      "urgency": urgency,
      "sentiment": sentiment,
      "confidence": confidence,
      "issues": issues,
      "departments": departments,
    };
  }
}