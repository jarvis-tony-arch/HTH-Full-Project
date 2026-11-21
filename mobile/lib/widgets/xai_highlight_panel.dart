import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../app/theme/app_spacing.dart';

/// XAI Highlight Panel — shows query text with words colored by importance.
/// Includes expandable plain-language explanation.
class XaiHighlightPanel extends StatefulWidget {
  final String query;
  final Map<String, double> wordImportance;
  final String explanation;

  const XaiHighlightPanel({
    super.key,
    required this.query,
    required this.wordImportance,
    required this.explanation,
  });

  @override
  State<XaiHighlightPanel> createState() => _XaiHighlightPanelState();
}

class _XaiHighlightPanelState extends State<XaiHighlightPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDarkElevated
            : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(
                      Icons.psychology_rounded,
                      size: 20,
                      color: isDark ? AppColors.accentCyan : AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Decision Explanation',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'See why this routing decision was made',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.expand_more,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1),
                // Highlighted query
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'KEYWORD IMPORTANCE',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  letterSpacing: 1.2,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4),
                                ),
                          ),
                          const Spacer(),
                          _buildLegend(context),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildHighlightedText(context),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'ROUTING RATIONALE',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  letterSpacing: 1.2,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4),
                                ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        widget.explanation,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightedText(BuildContext context) {
    final words = widget.query.split(RegExp(r'(\s+)'));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 3,
      runSpacing: 6,
      children: words.map((word) {
        final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
        final importance = widget.wordImportance[word] ??
            widget.wordImportance[cleanWord] ??
            0.1;

        Color bgColor;
        if (importance > 0.75) {
          bgColor = (isDark ? AppColors.accentCyan : AppColors.primaryBlue)
              .withValues(alpha: 0.35);
        } else if (importance > 0.5) {
          bgColor = (isDark ? AppColors.accentCyan : AppColors.primaryBlue)
              .withValues(alpha: 0.2);
        } else if (importance > 0.3) {
          bgColor = (isDark ? AppColors.accentCyan : AppColors.primaryBlue)
              .withValues(alpha: 0.1);
        } else {
          bgColor = Colors.transparent;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            word,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      importance > 0.5 ? FontWeight.w600 : FontWeight.w400,
                  color: importance > 0.75
                      ? (isDark ? AppColors.accentCyan : AppColors.primaryBlue)
                      : null,
                ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.accentCyan : AppColors.primaryBlue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(color.withValues(alpha: 0.1), 'Low', context),
        const SizedBox(width: 8),
        _legendDot(color.withValues(alpha: 0.3), 'Med', context),
        const SizedBox(width: 8),
        _legendDot(color.withValues(alpha: 0.6), 'High', context),
      ],
    );
  }

  Widget _legendDot(Color color, String label, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
        ),
      ],
    );
  }
}
