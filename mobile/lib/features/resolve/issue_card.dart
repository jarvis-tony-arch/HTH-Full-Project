import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import 'cases_store.dart';
import 'complaint_sheet.dart';
import 'models.dart';
import 'widgets.dart';

/// One card per issue: summary, urgent banner, rights, the ONE thing to do now,
/// deadline, complaint, later steps, and "why".
class IssueCard extends StatefulWidget {
  final SavedCase c;
  const IssueCard({super.key, required this.c});
  @override
  State<IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<IssueCard> {
  Timer? _minute;

  @override
  void initState() {
    super.initState();
    // Keep the countdown fresh.
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _minute?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final issue = c.issue;
    final step = c.currentStep;
    final t = Theme.of(context).textTheme;
    final accent = AppColors.accent(c.section);
    final store = context.read<CasesStore>();
    final later = issue.steps.where((s) => s.level > c.currentLevel).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Summary
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CompanyAvatar(name: c.companyName ?? issue.title, section: c.section),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(issue.summary, style: t.titleLarge),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (c.solved) const Tag('Solved', color: AppColors.good, bg: AppColors.goodSoft, icon: Icons.check),
                  if (!c.solved && issue.urgency == 'high')
                    const Tag('Act soon', color: AppColors.urgent, bg: AppColors.urgentSoft),
                ]),
              ]),
            ),
          ]),

          // ── Urgent banner
          if (issue.urgentAction != null && !c.solved) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.urgentSoft, borderRadius: BorderRadius.circular(16)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.alarm_rounded, color: AppColors.urgent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(issue.urgentAction!,
                        style: t.bodyLarge?.copyWith(color: AppColors.urgent, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          ],

          // ── What you're entitled to
          if (issue.entitlements.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionLabel("What you're entitled to"),
            // Keep the main action near the top: show what's owed first,
            // and fold the fine print into "Good to know".
            for (final e in issue.entitlements.where((e) => e.status == 'owed' || e.status == 'maybe'))
              _EntitlementLine(e),
            if (issue.entitlements.any((e) => e.status == 'not_owed' || e.status == 'info'))
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('Good to know',
                      style: t.bodyMedium?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600)),
                  children: [
                    for (final e in issue.entitlements.where((e) => e.status == 'not_owed' || e.status == 'info'))
                      _EntitlementLine(e),
                  ],
                ),
              ),
          ],

          // ── Do this now
          if (!c.solved) ...[
            const SizedBox(height: 18),
            const SectionLabel('Do this now'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentSoft(c.section),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Step ${step.level}: ${step.title}', style: t.titleMedium)),
                  if (!step.verified) const NotVerifiedTag(),
                ]),
                const SizedBox(height: 6),
                Text(step.instructions, style: t.bodyMedium),
                if (issue.startReason != null && c.currentLevel == issue.startLevel) ...[
                  const SizedBox(height: 6),
                  Text(issue.startReason!, style: t.bodySmall?.copyWith(color: AppColors.muted)),
                ],
                const SizedBox(height: 14),
                _MainAction(c: c, step: step, accent: accent),
                if (step.otherContacts.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, children: [
                    for (final o in step.otherContacts)
                      TextButton.icon(
                        onPressed: () async {
                          final ok = await openContact(context, o, complaint: issue.complaint);
                          if (ok) store.log(c, '${_verbPast(o)} (${step.title})');
                        },
                        icon: Icon(contactIcon(o.kind), size: 18),
                        label: Text(o.verified ? (o.kind == 'phone' ? 'Call ${firstNumber(o.value!)}' : o.label) : 'Check the official page'),
                      ),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            _Deadline(c: c),
          ],

          // ── Complaint
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () => showComplaintSheet(context, c),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Write my complaint'),
            ),
          ),

          // ── Later steps
          if (later.isNotEmpty && !c.solved)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text("If that doesn't work", style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                children: [for (final s in later) _LaterStep(s)],
              ),
            ),
          if (issue.alternateSteps.isNotEmpty && !c.solved)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Paid by UPI or card? Ask your bank too',
                    style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                children: [for (final s in issue.alternateSteps) _LaterStep(s)],
              ),
            ),

          // ── Why
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Why are we suggesting this?',
                  style: t.bodyMedium?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600)),
              children: [
                for (final r in issue.xaiReasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.muted),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r, style: t.bodyMedium)),
                    ]),
                  ),
                if (issue.entities.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final e in issue.entities.entries)
                        if (e.key != 'meals_refused' && e.key != 'train_departed')
                          Chip(label: Text('${_entityLabel(e.key)}: ${e.value}')),
                    ]),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Next step
          if (!c.solved && c.hasNextStep)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await store.nextStep(c);
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.arrow_downward_rounded),
                label: const Text("Didn't work? Show next step"),
              ),
            ),
        ]),
      ),
    );
  }
}

String _verbPast(Contact c) => switch (c.kind) {
      'phone' => 'Called ${c.value}',
      'email' => 'Opened email to ${c.value}',
      'whatsapp' => 'Opened WhatsApp ${c.value}',
      _ => 'Opened ${c.value}',
    };

String _entityLabel(String k) => const {
      'order_id': 'Order ID', 'amount': 'Amount (₹)', 'days_waiting': 'Days waiting',
      'delay_hours': 'Hours late', 'airline_pnr': 'PNR', 'train_pnr': 'PNR',
      'flight_number': 'Flight', 'train_number': 'Train', 'notice_hours': 'Notice (hours)',
      'block_hours': 'Flight length (hours)', 'departure_hour': 'Departure hour',
      'payment_method': 'Paid by', 'date': 'Date',
    }[k] ?? k;

class _MainAction extends StatelessWidget {
  final SavedCase c;
  final FixStep step;
  final Color accent;
  const _MainAction({required this.c, required this.step, required this.accent});

  @override
  Widget build(BuildContext context) {
    final ct = step.contact;
    final store = context.read<CasesStore>();
    if (ct.kind == 'none') {
      return Text(ct.label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700));
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () async {
          final ok = await openContact(context, ct, complaint: c.issue.complaint);
          if (ok) store.log(c, '${_verbPast(ct)} (${step.title})');
        },
        style: FilledButton.styleFrom(backgroundColor: ct.verified ? accent : AppColors.warn),
        icon: Icon(ct.verified ? contactIcon(ct.kind) : Icons.open_in_new_rounded),
        label: Text(contactVerb(ct), overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _Deadline extends StatelessWidget {
  final SavedCase c;
  const _Deadline({required this.c});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dl = c.deadline;
    final step = c.currentStep;
    if (dl == null) {
      return Text('This is the final step.', style: t.bodyMedium?.copyWith(color: AppColors.muted));
    }
    final passed = DateTime.now().isAfter(dl);
    final basis = step.deadlineBasis == 'rule' ? 'the legal deadline' : 'a sensible wait (not a legal deadline)';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: passed ? AppColors.warnSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: passed ? AppColors.warn : AppColors.line),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(passed ? Icons.timer_off_rounded : Icons.timer_outlined, color: passed ? AppColors.warn : AppColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              passed
                  ? "Time's up. If it isn't fixed, tap \"Show next step\"."
                  : "If they don't fix it by ${friendlyTime(dl)}, we'll show you the next step.",
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              passed ? 'Based on $basis' : '${timeLeft(dl)} · based on $basis',
              style: t.bodySmall?.copyWith(color: AppColors.muted),
            ),
            if (step.acknowledgeHours != null && !passed)
              Text('They must confirm they got it within ${step.acknowledgeHours} hours.',
                  style: t.bodySmall?.copyWith(color: AppColors.muted)),
          ]),
        ),
      ]),
    );
  }
}

class _EntitlementLine extends StatelessWidget {
  final Entitlement e;
  const _EntitlementLine(this.e);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (icon, color, prefix) = switch (e.status) {
      'owed' => (Icons.check_circle_rounded, AppColors.good, ''),
      'maybe' => (Icons.help_rounded, AppColors.warn, 'May apply: '),
      'not_owed' => (Icons.remove_circle_outline_rounded, AppColors.muted, ''),
      _ => (Icons.info_outline_rounded, AppColors.brand, ''),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showBasis(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$prefix${e.text}',
                style: t.bodyLarge?.copyWith(
                    color: e.status == 'not_owed' ? AppColors.muted : AppColors.ink)),
          ),
        ]),
      ),
    );
  }

  void _showBasis(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Where this comes from', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(e.basis.isEmpty ? 'General guidance' : e.basis, style: Theme.of(ctx).textTheme.bodyLarge),
            if (e.sourceUrl != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(e.sourceUrl!), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open the official source'),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _LaterStep extends StatelessWidget {
  final FixStep s;
  const _LaterStep(this.s);
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ct = s.contact;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.line,
          child: Text('${s.level}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s.title, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700))),
              if (!s.verified) const NotVerifiedTag(),
            ]),
            Text(s.instructions, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
            if (ct.kind != 'none')
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                onPressed: () => openContact(context, ct),
                icon: Icon(contactIcon(ct.kind), size: 18),
                label: Text(contactVerb(ct), overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),
      ]),
    );
  }
}
