import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';

/// Department model — a routing target for a detected issue.
class Department {
  final String name;
  final bool isPrimary;

  const Department({
    required this.name,
    this.isPrimary = false,
  });

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        name: json['name'] as String,
        isPrimary: json['is_primary'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'is_primary': isPrimary,
      };

  /// Human-readable name
  String get formattedName =>
      name.replaceAll('_', ' ').split(' ').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1);
      }).join(' ');

  /// Color for this department
  Color get color => AppColors.getDepartmentColor(name);

  /// Icon for this department
  IconData get icon {
    switch (name.toLowerCase()) {
      case 'billing':
      case 'payments':
        return Icons.receipt_long_rounded;
      case 'technical':
        return Icons.build_rounded;
      case 'logistics':
      case 'shipping':
        return Icons.local_shipping_rounded;
      case 'account':
        return Icons.person_rounded;
      case 'security':
        return Icons.shield_rounded;
      case 'product':
        return Icons.inventory_2_rounded;
      case 'refund':
        return Icons.currency_exchange_rounded;
      case 'general':
      default:
        return Icons.support_agent_rounded;
    }
  }
}
