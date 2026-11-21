/// Entity model — a single extracted entity (NER result).
class Entity {
  final String type;
  final String value;

  const Entity({
    required this.type,
    required this.value,
  });

  factory Entity.fromJson(Map<String, dynamic> json) => Entity(
        type: json['type'] as String,
        value: json['value'] as String,
      );

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
      };

  /// Icon for this entity type
  String get icon {
    switch (type.toUpperCase()) {
      case 'ORDER_ID':
        return '📦';
      case 'AMOUNT':
      case 'MONEY':
        return '💰';
      case 'DATE':
        return '📅';
      case 'PERSON':
        return '👤';
      case 'PRODUCT':
        return '🏷️';
      case 'PHONE':
        return '📱';
      case 'EMAIL':
        return '📧';
      case 'ORG':
        return '🏢';
      default:
        return '📌';
    }
  }

  /// Human-readable type name
  String get formattedType =>
      type.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      }).join(' ');
}
