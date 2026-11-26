import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'models.dart';
import 'widgets.dart';
import 'working_screen.dart';

/// Screen 2: pick a company (optional) and describe the problem.
class DescribeScreen extends StatefulWidget {
  final SectionInfo section;
  const DescribeScreen({super.key, required this.section});
  @override
  State<DescribeScreen> createState() => _DescribeScreenState();
}

class _DescribeScreenState extends State<DescribeScreen> {
  final _ctrl = TextEditingController();
  String? _company;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(AppTheme.route(WorkingScreen(
      text: text,
      section: widget.section.id,
      company: _company,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    final accent = AppColors.accent(s.id);
    final t = Theme.of(context).textTheme;
    final canSubmit = _ctrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Text('Which company? (optional)', style: t.titleMedium),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in s.companies)
                    ChoiceChip(
                      avatar: CompanyAvatar(name: c.name, section: s.id, size: 26),
                      label: Text(c.name),
                      selected: _company == c.id,
                      selectedColor: AppColors.accentSoft(s.id),
                      showCheckmark: false,
                      side: BorderSide(color: _company == c.id ? accent : AppColors.line, width: 1.5),
                      onSelected: (v) => setState(() => _company = v ? c.id : null),
                    ),
                ]).gentleIn(context),
                const SizedBox(height: 24),
                Text('What happened?', style: t.titleMedium),
                const SizedBox(height: 10),
                TextField(
                  controller: _ctrl,
                  minLines: 5,
                  maxLines: 10,
                  textCapitalization: TextCapitalization.sentences,
                  style: t.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Tell us what happened, in your own words. English or Hinglish is fine.',
                  ),
                ).gentleIn(context, index: 1),
                const SizedBox(height: 20),
                Text('Or tap an example', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 8),
                for (var i = 0; i < s.examples.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Pressable(
                      onTap: () {
                        _ctrl.text = s.examples[i];
                        _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
                      },
                      semanticLabel: 'Use example: ${s.examples[i]}',
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft(s.id),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          Icon(Icons.format_quote_rounded, color: accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s.examples[i], style: t.bodyMedium)),
                        ]),
                      ),
                    ).gentleIn(context, index: 2 + i),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton.icon(
              onPressed: canSubmit ? _submit : null,
              style: FilledButton.styleFrom(backgroundColor: accent),
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Get help'),
            ),
          ),
        ]),
      ),
    );
  }
}
