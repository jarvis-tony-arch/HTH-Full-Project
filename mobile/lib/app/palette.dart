import 'package:flutter/material.dart';

class Pal {
  Pal._();
  static const Color bg = Color(0xFF060E1E);
  static const Color nav = Color(0xFF0A1628);
  static const Color card = Color(0xFF0F1E35);
  static const Color border = Color(0xFF1E3A5F);
  static const Color blue = Color(0xFF2563EB);
  static const Color lightBlue = Color(0xFF60A5FA);
  static const Color green = Color(0xFF16A34A);
  static const Color red = Color(0xFFDC2626);
  static const Color orange = Color(0xFFEA580C);
  static const Color amber = Color(0xFFD97706);
  static const Color purple = Color(0xFF7C3AED);
  static const Color teal = Color(0xFF0891B2);

  static Color urgency(String u) {
    switch (u.toUpperCase()) {
      case 'CRITICAL':
        return red;
      case 'HIGH':
        return orange;
      case 'MEDIUM':
        return amber;
      case 'LOW':
        return green;
      default:
        return blue;
    }
  }

  static Color status(String s) {
    switch (s) {
      case 'NEW':
        return blue;
      case 'ASSIGNED':
        return teal;
      case 'IN_PROGRESS':
        return amber;
      case 'WAITING':
        return purple;
      case 'RESOLVED':
        return green;
      case 'ESCALATED':
        return red;
      default:
        return blue;
    }
  }
}

IconData deptIcon(String dept) {
  switch (dept) {
    case 'Logistics':
      return Icons.local_shipping_rounded;
    case 'Payments':
      return Icons.account_balance_rounded;
    case 'Refunds':
      return Icons.currency_rupee_rounded;
    case 'Account Security':
      return Icons.lock_rounded;
    case 'Fraud & Security':
      return Icons.security_rounded;
    case 'Order Management':
      return Icons.inventory_2_rounded;
    case 'Technical Support':
      return Icons.build_rounded;
    default:
      return Icons.support_agent_rounded;
  }
}

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String prettyStatus(String s) => s.replaceAll('_', ' ');
