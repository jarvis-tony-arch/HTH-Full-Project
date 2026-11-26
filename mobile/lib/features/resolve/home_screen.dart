import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../screens/splash_screen.dart' show openTriageMode;
import 'cases_screen.dart';
import 'cases_store.dart';
import 'describe_screen.dart';
import 'models.dart';
import 'resolve_api.dart';
import 'widgets.dart';

/// Screen 1: a friendly greeting and two big choices.
class ResolveHomeScreen extends StatefulWidget {
  const ResolveHomeScreen({super.key});
  @override
  State<ResolveHomeScreen> createState() => _ResolveHomeScreenState();
}

class _ResolveHomeScreenState extends State<ResolveHomeScreen> {
  List<SectionInfo> _sections = ResolveApi.fallbackSections;

  @override
  void initState() {
    super.initState();
    // Also wakes the Render server early, so "Get help" is faster.
    ResolveApi.sections().then((s) {
      if (mounted) setState(() => _sections = s);
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _open(String id) {
    final s = _sections.firstWhere((x) => x.id == id, orElse: () => ResolveApi.fallbackSections.first);
    Navigator.of(context).push(AppTheme.route(DescribeScreen(section: s)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CasesStore>();
    final open = store.open;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        actions: [
          if (store.all.isNotEmpty)
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(AppTheme.route(const CasesScreen())),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('My cases'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text('$_greeting 👋', style: t.titleMedium?.copyWith(color: AppColors.muted))
                .gentleIn(context),
            const SizedBox(height: 6),
            Text('What do you need help with?', style: t.headlineMedium).gentleIn(context, index: 1),
            const SizedBox(height: 8),
            Text("Tell us what went wrong. We'll show you exactly what to do.",
                    style: t.bodyLarge?.copyWith(color: AppColors.muted))
                .gentleIn(context, index: 2),
            const SizedBox(height: 24),
            _BigChoice(
              section: 'shopping',
              icon: Icons.shopping_bag_rounded,
              title: 'Shopping',
              subtitle: 'Orders, clothes, refunds',
              onTap: () => _open('shopping'),
            ).gentleIn(context, index: 3),
            const SizedBox(height: 14),
            _BigChoice(
              section: 'travel',
              icon: Icons.flight_takeoff_rounded,
              title: 'Travel',
              subtitle: 'Flights and trains',
              onTap: () => _open('travel'),
            ).gentleIn(context, index: 4),
            if (open.isNotEmpty) ...[
              const SizedBox(height: 32),
              const SectionLabel('Your open cases'),
              for (var i = 0; i < open.length && i < 3; i++) ...[
                CaseTile(c: open[i]).gentleIn(context, index: 5 + i),
                const SizedBox(height: 10),
              ],
              if (open.length > 3)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(AppTheme.route(const CasesScreen())),
                    child: Text('See all ${open.length} cases'),
                  ),
                ),
            ],
            const SizedBox(height: 40),
            Center(
              child: TextButton(
                onPressed: () => openTriageMode(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: const Text('For support teams: open Company triage mode'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigChoice extends StatelessWidget {
  final String section, title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _BigChoice({
    required this.section, required this.icon, required this.title,
    required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent(section);
    return Pressable(
      onTap: onTap,
      semanticLabel: '$title: $subtitle',
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppColors.line),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.accentSoft(section), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: accent, size: 34),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.muted)),
            ]),
          ),
          Icon(Icons.arrow_forward_rounded, color: accent, size: 28),
        ]),
      ),
    );
  }
}
