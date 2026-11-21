import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';
import '../models/issue.dart';

/// Issue chip widget — displays a detected issue with confidence badge.
/// Color saturation scales with confidence level.
class IssueChip extends StatelessWidget {
  final Issue issue;
  final VoidCallback? onTap;
  final bool showConfidence;

  const IssueChip({
    super.key,
    required this.issue,
    this.onTap,
    this.showConfidence = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = AppColors.primaryBlue;
    final bgOpacity = 0.08 + (issue.confidence * 0.15);
    final borderOpacity = 0.2 + (issue.confidence * 0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: bgOpacity),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(
              color: baseColor.withValues(alpha: borderOpacity),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIssueIcon(issue.label),
                size: 14,
                color: isDark ? AppColors.accentCyan : baseColor,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                issue.formattedLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isDark ? AppColors.textPrimaryDark : baseColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (showConfidence) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getConfidenceColor(issue.confidence)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    issue.confidencePercent,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.getConfidenceColor(issue.confidence),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIssueIcon(String label) {
    switch (label) {
      case 'delivery_issue':
      case 'late_delivery':
      case 'missing_package':
        return Icons.local_shipping_outlined;
      case 'wrong_item':
        return Icons.swap_horiz;
      case 'duplicate_payment':
      case 'overcharge':
      case 'billing_error':
        return Icons.payment;
      case 'refund_request':
        return Icons.currency_exchange;
      case 'account_locked':
      case 'unauthorized_access':
        return Icons.security;
      case 'password_reset':
      case 'account_update':
      case 'profile_issue':
        return Icons.person_outline;
      case 'product_defect':
        return Icons.report_problem_outlined;
      case 'technical_error':
      case 'app_crash':
      case 'login_issue':
        return Icons.bug_report_outlined;
      default:
        return Icons.help_outline;
    }
  }
}
