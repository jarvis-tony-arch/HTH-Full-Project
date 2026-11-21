import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app/palette.dart';
import '../models/ticket.dart';
import '../providers/tickets_provider.dart';
import '../widgets/motion.dart';

void openTicket(BuildContext context, String id) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => TicketDetailScreen(ticketId: id),
      transitionsBuilder: (_, a, __, c) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: c,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 380),
    ),
  );
}

class TicketDetailScreen extends StatelessWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketsProvider>();
    final found = provider.tickets.where((t) => t.id == ticketId).toList();

    if (found.isEmpty) {
      return Scaffold(
        backgroundColor: Pal.bg,
        appBar: AppBar(
            backgroundColor: Pal.bg, foregroundColor: Colors.white),
        body: Center(
          child: Text('Ticket not found',
              style: GoogleFonts.inter(color: Colors.white54)),
        ),
      );
    }

    final t = found.first;
    final uc = Pal.urgency(t.urgency);
    const colors = [Pal.blue, Pal.red, Pal.purple, Pal.teal, Pal.amber];
    final paired =
        t.issues.isNotEmpty && t.issues.length == t.departments.length;

    return Scaffold(
      backgroundColor: Pal.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, t, uc),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  FadeSlideIn(
                    child: _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Status', Icons.timeline_rounded, Pal.blue),
                          const SizedBox(height: 16),
                          _StatusTimeline(status: t.status),
                          if (t.status == 'ESCALATED') ...[
                            const SizedBox(height: 14),
                            _note(
                              'Escalated to a human agent for review.',
                              Pal.red,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delayMs: 80,
                    child: _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Customer message',
                              Icons.format_quote_rounded, Pal.lightBlue),
                          const SizedBox(height: 10),
                          Text(
                            t.rawQuery,
                            style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.6,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delayMs: 160,
                    child: _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('AI summary', Icons.auto_awesome_rounded,
                              Pal.purple),
                          const SizedBox(height: 10),
                          Text(
                            t.aiSummary,
                            style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delayMs: 240,
                    child: Row(
                      children: [
                        Expanded(
                            child: _metric('Urgency', t.urgency, uc,
                                Icons.bolt_rounded)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _metric('Sentiment', t.sentiment,
                                Pal.amber, Icons.mood_rounded)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _metric(
                                'Confidence',
                                '${(t.confidence * 100).toInt()}%',
                                Pal.blue,
                                Icons.insights_rounded)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delayMs: 320,
                    child: _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Issues & routing',
                              Icons.alt_route_rounded, Pal.teal),
                          const SizedBox(height: 12),
                          if (paired)
                            for (int i = 0; i < t.issues.length; i++)
                              _routeRow(t.issues[i], t.departments[i],
                                  colors[i % colors.length])
                          else ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final s in t.issues)
                                  _pill(s, Pal.blue),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final d in t.departments.toSet())
                                  _pill(d, Pal.purple),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    delayMs: 400,
                    child: _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Agent actions · update status',
                              Icons.manage_accounts_rounded, Pal.amber),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in const [
                                'NEW',
                                'ASSIGNED',
                                'IN_PROGRESS',
                                'WAITING',
                                'RESOLVED',
                                'ESCALATED'
                              ])
                                _statusChip(context, t, s),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Ticket t, Color uc) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Pal.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Hero(
            tag: 'tk-${t.id}',
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: uc.withOpacity(0.14),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                deptIcon(t.departments.isNotEmpty ? t.departments.first : ''),
                color: uc,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.aiTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                Text(
                  '${t.id} · ${timeAgo(t.createdAt)}',
                  style:
                      GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Pal.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Pal.border),
      ),
      child: child,
    );
  }

  Widget _label(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(text,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _note(String text, Color c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(text,
          style: GoogleFonts.inter(color: c, fontSize: 12)),
    );
  }

  Widget _metric(String label, String value, Color c, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                color: c, fontSize: 12, fontWeight: FontWeight.w800),
          ),
          Text(label,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _pill(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.withOpacity(0.4)),
      ),
      child: Text(text,
          style: GoogleFonts.inter(
              color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _routeRow(String issue, String dept, Color c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(issue,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Icon(Icons.arrow_forward_rounded, color: c, size: 16),
          const SizedBox(width: 8),
          Icon(deptIcon(dept), color: c, size: 16),
          const SizedBox(width: 6),
          Text(dept,
              style: GoogleFonts.inter(
                  color: c, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, Ticket t, String s) {
    final c = Pal.status(s);
    final active = t.status == s;
    return Pressable(
      onTap: () => context.read<TicketsProvider>().updateTicketStatus(t.id, s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c : c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withOpacity(active ? 1 : 0.35)),
        ),
        child: Text(
          prettyStatus(s),
          style: GoogleFonts.inter(
            color: active ? Colors.white : c,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  static const _stages = ['NEW', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED'];

  int get _current {
    switch (status) {
      case 'NEW':
        return 0;
      case 'ASSIGNED':
      case 'ESCALATED':
        return 1;
      case 'IN_PROGRESS':
      case 'WAITING':
        return 2;
      case 'RESOLVED':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    final activeColor = Pal.status(status);

    return Row(
      children: List.generate(_stages.length, (i) {
        final done = i < cur;
        final isCur = i == cur;
        final reached = i <= cur;
        final dotColor = done
            ? Pal.green
            : isCur
                ? activeColor
                : Pal.border;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 2,
                      color: i == 0
                          ? Colors.transparent
                          : (reached ? Pal.green : Pal.border),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: isCur ? 28 : 22,
                    height: isCur ? 28 : 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done || isCur
                          ? dotColor
                          : Pal.bg,
                      border: Border.all(color: dotColor, width: 2),
                      boxShadow: isCur
                          ? [
                              BoxShadow(
                                color: dotColor.withOpacity(0.5),
                                blurRadius: 12,
                              ),
                            ]
                          : null,
                    ),
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      height: 2,
                      color: i == _stages.length - 1
                          ? Colors.transparent
                          : (i < cur ? Pal.green : Pal.border),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                prettyStatus(_stages[i]),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: reached ? Colors.white : Colors.white30,
                  fontSize: 9.5,
                  fontWeight: isCur ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}