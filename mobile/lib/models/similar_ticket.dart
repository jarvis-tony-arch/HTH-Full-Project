/// SimilarTicket model — a past ticket matched by semantic similarity.
class SimilarTicket {
  final String id;
  final String title;
  final String summary;
  final double similarityScore;
  final String status;
  final String urgency;

  const SimilarTicket({
    required this.id,
    required this.title,
    required this.summary,
    required this.similarityScore,
    required this.status,
    required this.urgency,
  });

  factory SimilarTicket.fromJson(Map<String, dynamic> json) => SimilarTicket(
        id: json['id'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        similarityScore: (json['similarity_score'] as num).toDouble(),
        status: json['status'] as String? ?? 'resolved',
        urgency: json['urgency'] as String? ?? 'MEDIUM',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'similarity_score': similarityScore,
        'status': status,
        'urgency': urgency,
      };

  /// Similarity as percentage string
  String get similarityPercent =>
      '${(similarityScore * 100).toStringAsFixed(0)}%';
}
