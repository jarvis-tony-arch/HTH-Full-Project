import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'models.dart';
import 'widgets.dart';
import 'working_screen.dart';

/// Screen 5: one simple question with big option buttons.
class ClarifyScreen extends StatelessWidget {
  final String text;
  final ResolveResult result;
  final String? section, company, issueType;
  const ClarifyScreen({
    super.key, required this.text, required this.result, this.section, this.company, this.issueType,
  });

  void _pick(BuildContext context, ClarifyOption o) {
    // Carry every earlier answer forward so we never ask the same thing twice.
    Navigator.of(context).pushReplacement(AppTheme.route(WorkingScreen(
      text: text,
      section: o.section ?? result.section ?? section,
      company: o.company ?? result.company ?? company,
      issueType: o.issueType ?? issueType,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sec = result.section ?? section;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          children: [
            Text('One quick question', style: t.titleMedium?.copyWith(color: AppColors.muted)).gentleIn(context),
            const SizedBox(height: 6),
            Text(result.clarificationQuestion ?? 'Can you tell us a bit more?', style: t.headlineMedium)
                .gentleIn(context, index: 1),
            const SizedBox(height: 24),
            for (var i = 0; i < result.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Pressable(
                  onTap: () => _pick(context, result.options[i]),
                  semanticLabel: result.options[i].label,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      border: Border.all(color: AppColors.line, width: 1.5),
                    ),
                    child: Row(children: [
                      if (result.options[i].company != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: CompanyAvatar(name: result.options[i].label, section: result.options[i].section ?? sec),
                        ),
                      Expanded(child: Text(result.options[i].label, style: t.titleMedium)),
                      Icon(Icons.arrow_forward_rounded, color: AppColors.accent(result.options[i].section ?? sec)),
                    ]),
                  ),
                ).gentleIn(context, index: 2 + i),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('None of these. Let me describe it again'),
            ),
          ],
        ),
      ),
    );
  }
}
