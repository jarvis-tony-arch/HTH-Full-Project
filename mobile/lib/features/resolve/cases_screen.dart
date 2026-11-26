import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import 'cases_store.dart';
import 'issue_card.dart';
import 'models.dart';
import 'widgets.dart';

/// Screen 6: My cases (saved on the phone).
class CasesScreen extends StatelessWidget {
  const CasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CasesStore>();
    final open = store.open;
    final solved = store.all.where((c) => c.solved).toList();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My cases')),
      body: SafeArea(
        top: false,
        child: store.all.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No cases yet. When you get help, your case is saved here.',
                      textAlign: TextAlign.center, style: t.bodyLarge),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (open.isNotEmpty) ...[
                    const SectionLabel('Open'),
                    for (var i = 0; i < open.length; i++) ...[
                      CaseTile(c: open[i]).gentleIn(context, index: i),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (solved.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SectionLabel('Solved'),
                    for (final c in solved) ...[CaseTile(c: c), const SizedBox(height: 10)],
                  ],
                ],
              ),
      ),
    );
  }
}

class CaseTile extends StatelessWidget {
  final SavedCase c;
  const CaseTile({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dl = c.deadline;
    final passed = dl != null && DateTime.now().isAfter(dl);
    return Pressable(
      onTap: () => Navigator.of(context).push(AppTheme.route(CaseDetailScreen(caseId: c.id))),
      semanticLabel: c.issue.summary,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: passed && !c.solved ? AppColors.warn : AppColors.line),
        ),
        child: Row(children: [
          CompanyAvatar(name: c.companyName ?? c.issue.title, section: c.section),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.issue.summary, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                c.solved ? 'Solved' : 'Now: ${c.currentStep.title}',
                style: t.bodyMedium?.copyWith(color: AppColors.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!c.solved && dl != null) ...[
                const SizedBox(height: 4),
                Text(passed ? "Time's up. See the next step" : timeLeft(dl),
                    style: t.bodySmall?.copyWith(
                        color: passed ? AppColors.warn : AppColors.muted, fontWeight: FontWeight.w700)),
              ],
            ]),
          ),
          Icon(c.solved ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: c.solved ? AppColors.good : AppColors.muted),
        ]),
      ),
    );
  }
}

class CaseDetailScreen extends StatelessWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CasesStore>();
    final c = store.byId(caseId);
    if (c == null) return const Scaffold();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.companyName ?? 'Your case'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Delete this case?'),
                    content: const Text('This removes it and its evidence log from this phone.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
                      TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
                    ],
                  ),
                );
                if (yes == true && context.mounted) {
                  Navigator.of(context).pop();
                  await store.remove(c);
                }
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete case'))],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            IssueCard(c: c),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionLabel('Evidence log'),
                Text('Keep a record of what you sent and when. The consumer helpline, AirSewa and e-Daakhil ask for this.',
                    style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 12),
                for (final e in c.evidence.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 8, color: AppColors.muted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.what, style: t.bodyMedium),
                          if (e.ticket != null && e.ticket!.isNotEmpty)
                            Text('Ticket / reference: ${e.ticket}',
                                style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          Text(friendlyTime(e.at), style: t.bodySmall?.copyWith(color: AppColors.muted)),
                        ]),
                      ),
                    ]),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _addNote(context, c),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add a note or ticket number'),
                ),
                const SizedBox(height: 12),
                if (!c.solved)
                  FilledButton.icon(
                    onPressed: () async {
                      await store.markSolved(c);
                      if (context.mounted) await _celebrate(context);
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.good),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Mark as solved'),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addNote(BuildContext context, SavedCase c) async {
    final what = TextEditingController();
    final ticket = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Add to evidence log'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: what,
            decoration: const InputDecoration(labelText: 'What happened?', hintText: 'e.g. Called customer care'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ticket,
            decoration: const InputDecoration(labelText: 'Ticket number (optional)'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 48)),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted && (what.text.trim().isNotEmpty || ticket.text.trim().isNotEmpty)) {
      await context.read<CasesStore>().log(
            c,
            what.text.trim().isEmpty ? 'Ticket number noted' : what.text.trim(),
            ticket: ticket.text.trim().isEmpty ? null : ticket.text.trim(),
          );
    }
  }

  Future<void> _celebrate(BuildContext context) {
    final reduce = AppTheme.reduceMotion(context);
    return showDialog(
      context: context,
      builder: (d) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(alignment: Alignment.center, children: [
              for (final a in const [
                Alignment(-1, -1), Alignment(1, -0.8), Alignment(-0.9, 0.9), Alignment(0.9, 1)
              ])
                Align(
                  alignment: a,
                  child: const Icon(Icons.auto_awesome, color: AppColors.warn, size: 20)
                      .animate()
                      .fadeIn(duration: reduce ? 0.ms : 300.ms, delay: reduce ? 0.ms : 150.ms)
                      .scale(begin: const Offset(0.4, 0.4), duration: reduce ? 0.ms : 350.ms),
                ),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: AppColors.goodSoft, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppColors.good, size: 60),
              ).animate().scale(
                    begin: const Offset(0.5, 0.5),
                    duration: reduce ? 0.ms : 380.ms,
                    curve: Curves.easeOutBack,
                  ),
            ]),
            const SizedBox(height: 18),
            Text('Great, it\'s solved!', style: Theme.of(d).textTheme.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text("Well done for sticking with it. We'll keep this case in your records.",
                textAlign: TextAlign.center, style: Theme.of(d).textTheme.bodyLarge),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(d).pop(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.good),
              child: const Text('Back to my case'),
            ),
          ]),
        ),
      ),
    );
  }
}
