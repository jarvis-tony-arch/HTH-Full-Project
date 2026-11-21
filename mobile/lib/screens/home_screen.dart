import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/settings_provider.dart';
import '../providers/tickets_provider.dart';
import '../models/ticket.dart';
import 'main_shell.dart';
import 'processing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _hasText = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // label shown on the chip -> full sentence placed in the text box
  static const List<List<String>> _examples = [
    ['💳 Charged twice', 'I was charged twice for my order'],
    ['📦 Order not arrived', 'My order has not arrived yet'],
    ['🔐 Account locked', 'My account is locked and I cannot login'],
    ['↩️ Need refund', 'I need a refund for my payment'],
    ['📱 App not working', 'The app keeps crashing and is not working'],
  ];

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() {
      final has = _queryController.text.trim().isNotEmpty;
      if (has != _hasText) {
        setState(() => _hasText = has);
      } else {
        setState(() {}); // keeps the character count live
      }
    });
    _focusNode.addListener(() => setState(() {}));
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    _queryController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _submitQuery() {
    final text = _queryController.text.trim();
    if (text.isEmpty) return;
    _focusNode.unfocus();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ProcessingScreen(query: text),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _toggleVoice() async {
    final settings = context.read<SettingsProvider>();

    if (!settings.voiceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice input is turned off in Settings.'),
        ),
      );
      return;
    }

    // Tapping again while listening stops it
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    bool available = false;
    try {
      available = await _speech.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _isListening = false);
          }
        },
        onError: (e) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {
      available = false;
    }

    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice input is not available on this device. '
            'Try it on an Android or iOS phone.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isListening = true);
    await _speech.listen(
      localeId: settings.voiceLocale,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      onResult: (r) {
        if (!mounted) return;
        setState(() {
          _queryController.text = r.recognizedWords;
          _queryController.selection = TextSelection.collapsed(
            offset: _queryController.text.length,
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060E1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),
                      _buildGreeting(),
                      const SizedBox(height: 24),
                      _buildQueryCard(),
                      const SizedBox(height: 24),
                      _buildQuickExamples(),
                      const SizedBox(height: 28),
                      _buildRecentTicketsSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            // No bottom nav here. MainShell provides it.
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'HTH',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _topBarIcon(Icons.notifications_outlined, () {}),
              const SizedBox(width: 8),
              _topBarIcon(Icons.person_outline_rounded, () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _topBarIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
        ),
        child: Icon(icon, color: Colors.white70, size: 19),
      ),
    );
  }

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How can we help',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        Text(
          'you today?',
          style: GoogleFonts.inter(
            color: const Color(0xFF2563EB),
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Describe your issue in any language. Our AI understands multiple problems at once.',
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildQueryCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isListening
              ? const Color(0xFFDC2626)
              : _focusNode.hasFocus
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF1E3A5F),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isListening
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB))
                .withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: TextField(
              controller: _queryController,
              focusNode: _focusNode,
              maxLines: 5,
              minLines: 3,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: _isListening
                    ? 'Listening… speak now'
                    : 'e.g. "My order hasn\'t arrived, I was charged twice, '
                        'and I need a refund immediately..."',
                hintStyle: GoogleFonts.inter(
                  color: _isListening ? Colors.white54 : Colors.white24,
                  fontSize: 14,
                  height: 1.6,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: const Color(0xFF1E3A5F),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Text(
                  '${_queryController.text.length} chars',
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _toggleVoice,
                  child: AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isListening ? _pulseAnim.value : 1.0,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _isListening
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF1E3A5F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none_rounded,
                            color:
                                _isListening ? Colors.white : Colors.white60,
                            size: 20,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_hasText) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _queryController.clear();
                      setState(() => _hasText = false);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A5F),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white60,
                        size: 20,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _hasText ? _submitQuery : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: _hasText
                          ? const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            )
                          : null,
                      color: _hasText ? null : const Color(0xFF1E3A5F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Analyze',
                          style: GoogleFonts.inter(
                            color: _hasText ? Colors.white : Colors.white30,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: _hasText ? Colors.white : Colors.white30,
                          size: 15,
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
    );
  }

  Widget _buildQuickExamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick examples',
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _examples.map((ex) {
            return GestureDetector(
              onTap: () {
                _queryController.text = ex[1];
                _queryController.selection = TextSelection.collapsed(
                  offset: _queryController.text.length,
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1E35),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFF1E3A5F), width: 1),
                ),
                child: Text(
                  ex[0],
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRecentTicketsSection() {
    final tickets = context.watch<TicketsProvider>().tickets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent tickets',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (tickets.isNotEmpty)
              GestureDetector(
                onTap: () => MainShell.tab.value = 1,
                child: Text(
                  'View all',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF2563EB),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        tickets.isEmpty ? _buildEmptyTickets() : _buildTicketList(tickets),
      ],
    );
  }

  Widget _buildEmptyTickets() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, color: Colors.white12, size: 40),
          const SizedBox(height: 12),
          Text(
            'No tickets yet',
            style: GoogleFonts.inter(
              color: Colors.white24,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your support history will appear here',
            style: GoogleFonts.inter(color: Colors.white12, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketList(List<Ticket> tickets) {
    return Column(
      children: tickets.take(3).map(_buildTicketCard).toList(),
    );
  }

  Widget _buildTicketCard(Ticket ticket) {
    final urgencyColor = {
          'CRITICAL': const Color(0xFFDC2626),
          'HIGH': const Color(0xFFEA580C),
          'MEDIUM': const Color(0xFFD97706),
          'LOW': const Color(0xFF16A34A),
        }[ticket.urgency] ??
        const Color(0xFF2563EB);

    final statusColor = {
          'NEW': const Color(0xFF2563EB),
          'ASSIGNED': const Color(0xFF0891B2),
          'IN_PROGRESS': const Color(0xFFD97706),
          'WAITING': const Color(0xFF7C3AED),
          'RESOLVED': const Color(0xFF16A34A),
          'ESCALATED': const Color(0xFFDC2626),
        }[ticket.status] ??
        const Color(0xFF2563EB);

    return GestureDetector(
      onTap: () => MainShell.tab.value = 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1E35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1E3A5F), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket.aiTitle,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: urgencyColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    ticket.urgency,
                    style: GoogleFonts.inter(
                      color: urgencyColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ticket.aiSummary,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    ticket.status.replaceAll('_', ' '),
                    style: GoogleFonts.inter(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ...ticket.departments.toSet().take(2).map(
                      (dept) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A5F),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          dept,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                const Spacer(),
                Text(
                  _timeAgo(ticket.createdAt),
                  style: GoogleFonts.inter(
                    color: Colors.white24,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}