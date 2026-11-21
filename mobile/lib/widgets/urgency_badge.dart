import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';

/// Urgency badge — color-coded pill with icon.
/// CRITICAL level includes a subtle pulse animation.
class UrgencyBadge extends StatefulWidget {
  final String urgency;
  final bool compact;

  const UrgencyBadge({
    super.key,
    required this.urgency,
    this.compact = false,
  });

  @override
  State<UrgencyBadge> createState() => _UrgencyBadgeState();
}

class _UrgencyBadgeState extends State<UrgencyBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.urgency.toUpperCase() == 'CRITICAL') {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getUrgencyColor(widget.urgency);
    final bgColor = AppColors.getUrgencyBgColor(widget.urgency);
    final label = widget.urgency.toUpperCase();

    Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? AppSpacing.sm : AppSpacing.md,
        vertical: widget.compact ? 3 : AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(label),
            size: widget.compact ? 12 : 14,
            color: color,
          ),
          SizedBox(width: widget.compact ? 3 : AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: widget.compact ? 10 : 11,
                  letterSpacing: 0.8,
                ),
          ),
        ],
      ),
    );

    if (label == 'CRITICAL') {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        ),
        child: badge,
      );
    }

    return badge;
  }

  IconData _getIcon(String urgency) {
    switch (urgency) {
      case 'CRITICAL':
        return Icons.error_rounded;
      case 'HIGH':
        return Icons.warning_amber_rounded;
      case 'MEDIUM':
        return Icons.info_outline_rounded;
      case 'LOW':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.help_outline;
    }
  }
}
