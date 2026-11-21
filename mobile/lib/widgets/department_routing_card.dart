import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';
import '../models/department.dart';

/// Department routing card — shows issue→department mapping with flow visualization.
class DepartmentRoutingCard extends StatelessWidget {
  final List<Department> departments;

  const DepartmentRoutingCard({super.key, required this.departments});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkElevated : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.alt_route_rounded,
                size: 18,
                color: isDark ? AppColors.accentCyan : AppColors.primaryBlue,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Department Routing',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (departments.length > 1) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    'MULTI-ROUTE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.accentTeal,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.8,
                        ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...departments.asMap().entries.map((entry) {
            final index = entry.key;
            final dept = entry.value;
            return _buildDepartmentRow(context, dept, index == 0 && departments.length > 1);
          }),
        ],
      ),
    );
  }

  Widget _buildDepartmentRow(BuildContext context, Department dept, bool showPrimaryBadge) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: dept.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(dept.icon, size: 20, color: dept.color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dept.formattedName,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (dept.isPrimary || showPrimaryBadge) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: dept.color.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: Text(
                          'PRIMARY',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: dept.color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 8,
                                    letterSpacing: 0.8,
                                  ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Assigned to handle ${dept.formattedName.toLowerCase()} related issues',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
