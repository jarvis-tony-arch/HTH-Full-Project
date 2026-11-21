import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';

/// Sentiment indicator with emoji and color-coded label.
class SentimentIndicator extends StatelessWidget {
  final String sentiment;
  final bool compact;

  const SentimentIndicator({
    super.key,
    required this.sentiment,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.getSentimentColor(sentiment);
    final emoji = _getEmoji(sentiment);
    final label = sentiment[0].toUpperCase() + sentiment.substring(1).toLowerCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 3 : AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: compact ? 12 : 14)),
          SizedBox(width: compact ? 3 : AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 10 : 11,
                ),
          ),
        ],
      ),
    );
  }

  String _getEmoji(String sentiment) {
    switch (sentiment.toUpperCase()) {
      case 'POSITIVE':
        return '😊';
      case 'NEUTRAL':
        return '😐';
      case 'NEGATIVE':
        return '😞';
      case 'FRUSTRATED':
        return '😤';
      default:
        return '😐';
    }
  }
}
