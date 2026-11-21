import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';

/// Status timeline — vertical visual tracker showing ticket status progression.
class StatusTimeline extends StatelessWidget {
  final String currentStatus;

  const StatusTimeline({super.key, required this.currentStatus});

  static const _statuses = ['open', 'in_progress', 'resolved', 'closed'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _statuses.indexOf(currentStatus.toLowerCase());
    final isEscalated = currentStatus.toLowerCase() == 'escalated';

    return Column(
      children: List.generate(_statuses.length, (index) {
        final isActive = index <= currentIndex;
        final isCurrent = index == currentIndex;

        return _buildTimelineItem(
          context,
          label: _getStatusLabel(_statuses[index]),
          icon: _getStatusIcon(_statuses[index]),
          isActive: isActive,
          isCurrent: isCurrent && !isEscalated,
          isLast: index == _statuses.length - 1,
          color: isEscalated && isCurrent
              ? AppColors.error
              : _getStatusColor(_statuses[index]),
        );
      }),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isActive,
    required bool isCurrent,
    required bool isLast,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2);

    return IntrinsicHeight(
      child: Row(
        children: [
          // Timeline track
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Dot
                Container(
                  width: isCurrent ? 20 : 14,
                  height: isCurrent ? 20 : 14,
                  decoration: BoxDecoration(
                    color: isActive ? color.withValues(alpha: 0.2) : inactiveColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? color : inactiveColor,
                      width: isCurrent ? 3 : 2,
                    ),
                  ),
                  child: isActive && !isCurrent
                      ? Icon(Icons.check, size: 8, color: color)
                      : null,
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isActive ? color.withValues(alpha: 0.3) : inactiveColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Label
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isActive ? color : inactiveColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isActive
                              ? null
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        'CURRENT',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Ticket Created';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'open':
        return Icons.add_circle_outline;
      case 'in_progress':
        return Icons.autorenew;
      case 'resolved':
        return Icons.check_circle_outline;
      case 'closed':
        return Icons.archive_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.info;
      case 'in_progress':
        return AppColors.warning;
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return AppColors.textSecondaryLight;
      default:
        return AppColors.info;
    }
  }
}
