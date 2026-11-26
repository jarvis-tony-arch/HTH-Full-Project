import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import 'cases_store.dart';
import 'models.dart';
import 'widgets.dart';

/// "Write my complaint": the ready email, editable, with Copy / Send / Share.
Future<void> showComplaintSheet(BuildContext context, SavedCase c) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ComplaintSheet(c: c),
  );
}

class _ComplaintSheet extends StatefulWidget {
  final SavedCase c;
  const _ComplaintSheet({required this.c});
  @override
  State<_ComplaintSheet> createState() => _ComplaintSheetState();
}

class _ComplaintSheetState extends State<_ComplaintSheet> {
  late final TextEditingController _subject;
  late final TextEditingController _body;
  late final String? _to;

  @override
  void initState() {
    super.initState();
    final comp = widget.c.issue.complaint;
    _subject = TextEditingController(text: comp.subject);
    _body = TextEditingController(text: comp.body);
    // Send to the email for the step the user is on now, if it has one.
    final step = widget.c.currentStep;
    final stepEmail = [step.contact, ...step.otherContacts]
        .where((x) => x.kind == 'email' && x.verified)
        .map((x) => x.value)
        .firstOrNull;
    _to = stepEmail ?? comp.to;
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  String get _full => 'Subject: ${_subject.text}\n\n${_body.text}';

  Future<void> _send() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _to ?? '',
      query: 'subject=${Uri.encodeComponent(_subject.text)}&body=${Uri.encodeComponent(_body.text)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!mounted) return;
    if (ok) {
      await context.read<CasesStore>().log(widget.c, 'Complaint email opened${_to != null ? ' to $_to' : ''}');
    } else {
      await copyText(context, _full, msg: 'No email app found. The complaint is copied instead.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = AppColors.accent(widget.c.section);
    final hasPlaceholders = _body.text.contains('[');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your complaint is ready', style: t.titleLarge),
          const SizedBox(height: 6),
          Text(
            _to != null ? 'To: $_to' : "To: add the company's email (we couldn't verify one)",
            style: t.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          if (hasPlaceholders) ...[
            const SizedBox(height: 8),
            const Tag('Fill in the parts in [brackets]', color: AppColors.warn, bg: AppColors.warnSoft, icon: Icons.edit),
          ],
          const SizedBox(height: 14),
          TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 10,
            maxLines: 18,
            style: t.bodyMedium,
            decoration: const InputDecoration(labelText: 'Message (you can edit it)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _send,
            style: FilledButton.styleFrom(backgroundColor: accent),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send email'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final store = context.read<CasesStore>();
                  await copyText(context, _full, msg: 'Complaint copied');
                  await store.log(widget.c, 'Complaint copied');
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final store = context.read<CasesStore>();
                  await SharePlus.instance.share(ShareParams(text: _full, subject: _subject.text));
                  await store.log(widget.c, 'Complaint shared');
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Share'),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
