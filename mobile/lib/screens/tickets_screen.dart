import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app/palette.dart';
import '../models/ticket.dart';
import '../providers/tickets_provider.dart';
import '../widgets/motion.dart';
import 'ticket_detail_screen.dart';

class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  String _filter = 'All';
  static const _filters = ['All', 'Open', 'High priority', 'Escalated', 'Resolved'];

  List<Ticket> _apply(List<Ticket> all) {
    switch (_filter) {
      case 'Open':
        return all.where((t) => t.status != 'RESOLVED').toList();
      case 'High priority':
        return all
            .where((t) => t.urgency == 'HIGH' || t.urgency == 'CRITICAL')
            .toList();
      case 'Escalated':
        return all.where((t) => t.status == 'ESCALATED').toList();
      case 'Resolved':
        return all.where((t) => t.status == 'RESOLVED').toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<TicketsProvider>().tickets;
    final list = _apply(all);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: FadeSlideIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Tickets',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${all.length} total · ${list.length} shown',
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _filters[i];
                final active = f == _filter;
                return Pressable(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? Pal.blue : Pal.card,
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: active ? Pal.blue : Pal.border),
                    ),
                    child: Text(
                      f,
                      style: GoogleFonts.inter(
                        color: active ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: list.isEmpty
                ? _empty(all.isEmpty)
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final t = list[i];
                      return FadeSlideIn(
                        key: ValueKey('$_filter-${t.id}'),
                        delayMs: (i > 8 ? 8 : i) * 60,
                        child: TicketCard(
                          ticket: t,
                          onTap: () => openTicket(context, t.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty(bool noTicketsAtAll) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Floating(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Pal.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: Pal.border),
                ),
                child: const Icon(Icons.inbox_rounded,
                    color: Pal.lightBlue, size: 38),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              noTicketsAtAll ? 'No tickets yet' : 'Nothing in this filter',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              noTicketsAtAll
                  ? 'Describe a problem on the Home tab and create a ticket.'
                  : 'Try a different filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onTap;
  final bool hero;
  const TicketCard(
      {super.key, required this.ticket, required this.onTap, this.hero = true});

  @override
  Widget build(BuildContext context) {
    final uc = Pal.urgency(ticket.urgency);
    final sc = Pal.status(ticket.status);
    final depts = ticket.departments.toSet().take(2).toList();

    final icon = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: uc.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        deptIcon(ticket.departments.isNotEmpty ? ticket.departments.first : ''),
        color: uc,
        size: 20,
      ),
    );

    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Pal.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Pal.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            hero ? Hero(tag: 'tk-${ticket.id}', child: icon) : icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ticket.aiTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: uc.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          ticket.urgency,
                          style: GoogleFonts.inter(
                              color: uc,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ticket.aiSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: sc.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: sc.withOpacity(0.4)),
                        ),
                        child: Text(
                          prettyStatus(ticket.status),
                          style: GoogleFonts.inter(
                              color: sc,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      for (final d in depts)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Pal.border,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            d,
                            style: GoogleFonts.inter(
                                color: Colors.white60, fontSize: 10),
                          ),
                        ),
                      Text(
                        timeAgo(ticket.createdAt),
                        style: GoogleFonts.inter(
                            color: Colors.white24, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}