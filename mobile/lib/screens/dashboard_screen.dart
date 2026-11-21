import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app/palette.dart';
import '../models/ticket.dart';
import '../providers/tickets_provider.dart';
import '../widgets/motion.dart';
import 'ticket_detail_screen.dart';
import 'tickets_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  int _rank(String u) {
    switch (u) {
      case 'CRITICAL':
        return 0;
      case 'HIGH':
        return 1;
      case 'MEDIUM':
        return 2;
      default:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<TicketsProvider>().tickets;
    final total = all.length;
    final open = all.where((t) => t.status != 'RESOLVED').length;
    final resolved = total - open;
    final high =
        all.where((t) => t.urgency == 'HIGH' || t.urgency == 'CRITICAL').length;
    final esc = all.where((t) => t.status == 'ESCALATED').length;
    final avgConf = total == 0
        ? 0
        : (all.map((t) => t.confidence).reduce((a, b) => a + b) / total * 100)
            .round();

    // Open workload per department
    final Map<String, int> dept = {};
    for (final t in all.where((t) => t.status != 'RESOLVED')) {
      for (final d in t.departments.toSet()) {
        dept[d] = (dept[d] ?? 0) + 1;
      }
    }
    final deptSorted = dept.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Urgency distribution
    final Map<String, int> urg = {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0};
    for (final t in all) {
      urg[t.urgency] = (urg[t.urgency] ?? 0) + 1;
    }

    // Common issues
    final Map<String, int> issues = {};
    for (final t in all) {
      for (final i in t.issues) {
        issues[i] = (issues[i] ?? 0) + 1;
      }
    }
    final issuesSorted = issues.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Needs attention
    final attention = all
        .where((t) => t.status == 'ESCALATED' || t.status == 'NEW')
        .toList()
      ..sort((a, b) => _rank(a.urgency).compareTo(_rank(b.urgency)));

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          FadeSlideIn(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Agent Dashboard',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Live view of tickets on this device',
                          style: GoogleFonts.inter(
                              color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Pal.purple.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Pal.purple.withOpacity(0.4)),
                  ),
                  child: Text('AGENT VIEW',
                      style: GoogleFonts.inter(
                          color: Pal.purple,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (total == 0)
            FadeSlideIn(delayMs: 100, child: _empty(context))
          else ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                _stat('Total tickets', total, '', Icons.inbox_rounded, Pal.blue, 0),
                _stat('Open', open, '', Icons.pending_actions_rounded, Pal.amber, 1),
                _stat('High priority', high, '', Icons.bolt_rounded, Pal.orange, 2),
                _stat('Escalated', esc, '', Icons.priority_high_rounded, Pal.red, 3),
                _stat('Resolved', resolved, '', Icons.check_circle_rounded, Pal.green, 4),
                _stat('Avg confidence', avgConf, '%', Icons.insights_rounded, Pal.teal, 5),
              ],
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delayMs: 300,
              child: _section(
                'Urgency distribution',
                Icons.warning_amber_rounded,
                Pal.orange,
                _urgencyBar(urg, total),
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              delayMs: 380,
              child: _section(
                'Open workload by department',
                Icons.corporate_fare_rounded,
                Pal.purple,
                deptSorted.isEmpty
                    ? Text('No open tickets',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 12))
                    : Column(
                        children: [
                          for (final e in deptSorted)
                            _barRow(e.key, e.value, deptSorted.first.value,
                                Pal.purple),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              delayMs: 460,
              child: _section(
                'Most common issues',
                Icons.leaderboard_rounded,
                Pal.blue,
                Column(
                  children: [
                    for (final e in issuesSorted.take(5))
                      _barRow(e.key, e.value, issuesSorted.first.value,
                          Pal.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delayMs: 540,
              child: Row(
                children: [
                  const Icon(Icons.flag_rounded, color: Pal.red, size: 16),
                  const SizedBox(width: 8),
                  Text('Needs attention',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (attention.isEmpty)
              Text('All caught up',
                  style:
                      GoogleFonts.inter(color: Colors.white38, fontSize: 12))
            else
              for (int i = 0; i < attention.take(4).length; i++)
                FadeSlideIn(
                  delayMs: 600 + i * 70,
                  child: TicketCard(
                    ticket: attention[i],
                    hero: false,
                    onTap: () => openTicket(context, attention[i].id),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, int value, String suffix, IconData icon,
      Color c, int index) {
    return FadeSlideIn(
      delayMs: 80 + index * 70,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Pal.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Pal.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: c, size: 15),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          color: Colors.white54, fontSize: 11)),
                ),
              ],
            ),
            CountUp(
              value: value,
              suffix: suffix,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, Color c, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: c, size: 16),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _barRow(String label, int value, int max, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => TweenAnimationBuilder<double>(
                tween: Tween<double>(
                    begin: 0, end: max == 0 ? 0 : value / max),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Pal.border,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    Container(
                      height: 10,
                      width: c.maxWidth * v,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$value',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _urgencyBar(Map<String, int> urg, int total) {
    final order = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, c) => TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  for (final k in order)
                    if ((urg[k] ?? 0) > 0)
                      Container(
                        height: 14,
                        width: c.maxWidth * (urg[k]! / total) * v,
                        color: Pal.urgency(k),
                      ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final k in order)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Pal.urgency(k),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('$k ${urg[k] ?? 0}',
                      style: GoogleFonts.inter(
                          color: Colors.white54, fontSize: 11)),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Pal.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Pal.border),
      ),
      child: Column(
        children: [
          Floating(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Pal.bg,
                shape: BoxShape.circle,
                border: Border.all(color: Pal.border),
              ),
              child: const Icon(Icons.dashboard_rounded,
                  color: Pal.lightBlue, size: 34),
            ),
          ),
          const SizedBox(height: 16),
          Text('No tickets to analyse yet',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Create a ticket from the Home tab, or load sample tickets to preview the dashboard.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: Colors.white38, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 18),
          Pressable(
            onTap: () => context.read<TicketsProvider>().addDemoData(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Pal.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Load sample tickets',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}