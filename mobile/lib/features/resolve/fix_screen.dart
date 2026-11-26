import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cases_store.dart';
import 'issue_card.dart';
import 'models.dart';
import 'widgets.dart';

/// Screen 4: "Your fix", one card per issue, top to bottom.
class FixScreen extends StatelessWidget {
  final List<String> caseIds;
  const FixScreen({super.key, required this.caseIds});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CasesStore>();
    final cases = caseIds.map(store.byId).whereType<SavedCase>().toList();
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your fix'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Done'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (cases.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text('We found ${cases.length} problems. Here is what to do for each one.',
                    style: t.bodyLarge),
              ).gentleIn(context),
            for (var i = 0; i < cases.length; i++) ...[
              IssueCard(c: cases[i]).gentleIn(context, index: i + 1),
              const SizedBox(height: 14),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Saved to My cases on this phone.',
                  textAlign: TextAlign.center, style: t.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
