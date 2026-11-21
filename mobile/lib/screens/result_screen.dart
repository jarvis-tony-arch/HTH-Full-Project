import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/ticket.dart';
import '../providers/settings_provider.dart';
import '../providers/tickets_provider.dart';
import 'main_shell.dart';

class ResultScreen extends StatefulWidget {
  final String query;
  final Map<String, dynamic>? analysisResult;

  const ResultScreen({
    super.key,
    required this.query,
    this.analysisResult,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  List<_Issue> _issues = [];
  String _urgency = 'LOW';
  double _confidence = 0.0;
  Map<String, String> _entities = {};
  String _aiTitle = 'Unclear Request';
  String _aiSummary = '';
  List<String> _xaiReasons = [];
  List<String> _followUpQuestions = [];
  String _sentiment = 'Neutral';
  String _detectedLang = 'en';
  String _detectedLangName = 'English';
  String _translatedText = '';

  int _expandedIssue = -1;
  bool _ticketCreated = false;
  bool _xaiOpen = false;

  @override
  void initState() {
    super.initState();
    _translatedText = widget.query;
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _parseResult();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ───────────────────────── parsing ─────────────────────────

  static const _issueIcons = <String, IconData>{
    'delivery_issue': Icons.local_shipping_rounded,
    'duplicate_payment': Icons.credit_card_rounded,
    'refund_request': Icons.reply_rounded,
    'account_access': Icons.lock_rounded,
    'unauthorized_payment': Icons.security_rounded,
    'wrong_item': Icons.swap_horiz_rounded,
    'damaged_item': Icons.broken_image_rounded,
    'payment_failure': Icons.payment_rounded,
    'app_technical': Icons.phone_android_rounded,
    'order_cancellation': Icons.cancel_rounded,
    'order_status': Icons.track_changes_rounded,
  };

  static const _deptIcons = <String, IconData>{
    'Logistics': Icons.local_shipping_rounded,
    'Payments': Icons.account_balance_rounded,
    'Refunds': Icons.currency_rupee_rounded,
    'Account Security': Icons.lock_rounded,
    'Fraud & Security': Icons.security_rounded,
    'Order Management': Icons.inventory_2_rounded,
    'Technical Support': Icons.build_rounded,
  };

  static const _issueColors = <Color>[
    Color(0xFF2563EB),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF059669),
    Color(0xFFD97706),
  ];

  void _parseResult() {
    final result = widget.analysisResult;
    if (result == null) return;

    _detectedLang = result['detected_language'] as String? ?? 'en';
    _detectedLangName = result['detected_language_name'] as String? ?? 'English';
    _translatedText = result['translated_text'] as String? ?? widget.query;
    _urgency = result['urgency'] as String? ?? 'LOW';
    _sentiment = result['sentiment'] as String? ?? 'Neutral';
    _confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
    _aiTitle = result['ai_title'] as String? ?? 'Support Request';
    _aiSummary = result['ai_summary'] as String? ?? '';
    _xaiReasons = List<String>.from(result['xai_reasons'] as List? ?? []);
    _followUpQuestions =
        List<String>.from(result['follow_up_questions'] as List? ?? []);

    final rawEntities = result['entities'] as Map<String, dynamic>? ?? {};
    _entities = rawEntities.map((k, v) => MapEntry(k, v.toString()));

    final rawIssues = result['issues'] as List? ?? [];
    _issues = rawIssues.asMap().entries.map((entry) {
      final i = entry.key;
      final issue = Map<String, dynamic>.from(entry.value as Map);
      final intent = issue['intent'] as String? ?? '';
      final dept = issue['department'] as String? ?? 'Support';

      final translatedLabel = issue['display_translated'] as String?;
      final translatedDept = issue['department_translated'] as String?;

      return _Issue(
        label: (translatedLabel != null && translatedLabel.isNotEmpty)
            ? translatedLabel
            : (issue['display'] as String? ?? 'Unknown issue'),
        labelEn: issue['display'] as String? ?? 'Unknown issue',
        icon: _issueIcons[intent] ?? Icons.help_outline_rounded,
        color: _issueColors[i % _issueColors.length],
        plain: _issuePlain(intent),
        department: dept,
        departmentDisplay: (translatedDept != null && translatedDept.isNotEmpty)
            ? translatedDept
            : dept,
        deptIcon: _deptIcons[dept] ?? Icons.support_agent_rounded,
        action: _deptAction(dept),
        confidence: (issue['confidence'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();
  }

  String _issuePlain(String intent) {
    const map = {
      'delivery_issue': 'Your order has not arrived yet.',
      'duplicate_payment': 'You were charged twice for the same order.',
      'refund_request': 'You want a payment reversed or refunded.',
      'account_access': 'You cannot access your account.',
      'unauthorized_payment': 'A payment you did not make was detected.',
      'wrong_item': 'You received the wrong item.',
      'damaged_item': 'Your item arrived damaged.',
      'payment_failure': 'Your payment did not go through.',
      'app_technical': 'The app or website is not working.',
      'order_cancellation': 'You want to cancel your order.',
      'order_status': 'You want to know where your order is.',
    };
    return map[intent] ?? 'Issue detected in your message.';
  }

  String _deptAction(String dept) {
    const map = {
      'Logistics': 'Will track and expedite your shipment.',
      'Payments': 'Will verify and resolve the payment issue.',
      'Refunds': 'Will process your refund once verified.',
      'Account Security': 'Will help you regain account access.',
      'Fraud & Security': 'Will investigate the unauthorized activity.',
      'Order Management': 'Will review and resolve your order issue.',
      'Technical Support': 'Will investigate the technical problem.',
    };
    return map[dept] ?? 'Will handle your request.';
  }

  // ───────────────────────── ticket ─────────────────────────

  bool _needsHuman(double threshold) =>
      _issues.isEmpty || _confidence < threshold || _urgency == 'CRITICAL';

  void _createTicket() {
    final threshold = context.read<SettingsProvider>().confidenceThreshold;
    final escalated = _needsHuman(threshold);

    final ticket = Ticket(
      id: 'TKT-${DateTime.now().millisecondsSinceEpoch}',
      rawQuery: widget.query,
      aiTitle: _aiTitle,
      aiSummary: _aiSummary,
      status: escalated ? 'ESCALATED' : 'NEW',
      urgency: _urgency,
      sentiment: _sentiment,
      confidence: _confidence,
      escalated: escalated,
      issues: _issues.map((i) => i.labelEn).toList(),
      departments: _issues.map((i) => i.department).toList(),
      createdAt: DateTime.now(),
    );

    context.read<TicketsProvider>().addTicket(ticket);
    setState(() => _ticketCreated = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                escalated
                    ? 'Ticket created and sent for human review'
                    : 'Ticket created and auto-routed',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _goToTickets() {
    Navigator.of(context).popUntil((r) => r.isFirst);
    MainShell.tab.value = 1;
  }

  // ───────────────────────── build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final threshold = context.watch<SettingsProvider>().confidenceThreshold;

    return Scaffold(
      backgroundColor: const Color(0xFF060E1E),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildQueryBubble(),
                      const SizedBox(height: 24),
                      if (_issues.isEmpty) ...[
                        _buildNoIssuesCard(),
                      ] else ...[
                        _buildStep1(),
                        const SizedBox(height: 24),
                        _buildStep2(),
                        const SizedBox(height: 24),
                        if (_entities.isNotEmpty) ...[
                          _buildStep3(),
                          const SizedBox(height: 24),
                        ],
                        _buildStep4(threshold),
                        if (_xaiReasons.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildWhySection(),
                        ],
                        if (_followUpQuestions.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildFollowUpSection(),
                        ],
                      ],
                      const SizedBox(height: 32),
                      _buildTicketButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1E3A5F), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Case Summary',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _issues.isEmpty
                      ? 'Needs clarification'
                      : '${_issues.length} issue${_issues.length > 1 ? 's' : ''} detected',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_detectedLang != 'en') ...[
            _languageBadge(),
            const SizedBox(width: 6),
          ],
          _urgencyBadge(),
        ],
      ),
    );
  }

  Widget _languageBadge() {
    const c = Color(0xFF7C3AED);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.translate_rounded, color: c, size: 12),
          const SizedBox(width: 4),
          Text(
            _detectedLangName,
            style: GoogleFonts.inter(
              color: c,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _urgencyBadge() {
    final colors = {
      'CRITICAL': const Color(0xFFDC2626),
      'HIGH': const Color(0xFFEA580C),
      'MEDIUM': const Color(0xFFD97706),
      'LOW': const Color(0xFF16A34A),
    };
    final c = colors[_urgency] ?? const Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: c, size: 13),
          const SizedBox(width: 3),
          Text(
            _urgency,
            style: GoogleFonts.inter(
              color: c,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueryBubble() {
    final isTranslated = _detectedLang != 'en' &&
        _detectedLang != 'hinglish' &&
        _translatedText.trim() != widget.query.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your message',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.query,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isTranslated) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.translate_rounded,
                      color: Color(0xFF7C3AED), size: 13),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Translated to English for analysis',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF7C3AED),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _translatedText,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_detectedLang == 'hinglish') ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_fix_high_rounded,
                      color: Color(0xFF7C3AED), size: 13),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hinglish detected, normalized to English keywords before analysis',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFC4B5FD),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoIssuesCard() {
    const amber = Color(0xFFD97706);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.help_outline_rounded, color: amber, size: 40),
          const SizedBox(height: 12),
          Text(
            'Could not detect a specific issue',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A support agent will review your message. You can also try describing the problem with a few more details.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (_followUpQuestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final q in _followUpQuestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: amber.withOpacity(0.2)),
                  ),
                  child: Text(
                    q,
                    style: GoogleFonts.inter(color: amber, fontSize: 13),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // STEP 1: issues
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepLabel(
          '1',
          'We found ${_issues.length} issue${_issues.length > 1 ? 's' : ''}',
          'Tap each one to understand it',
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < _issues.length; i++) _issueCard(i, _issues[i]),
      ],
    );
  }

  Widget _issueCard(int i, _Issue issue) {
    final isExpanded = _expandedIssue == i;
    return GestureDetector(
      onTap: () => setState(() => _expandedIssue = isExpanded ? -1 : i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isExpanded
              ? issue.color.withOpacity(0.08)
              : const Color(0xFF0F1E35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded
                ? issue.color.withOpacity(0.4)
                : const Color(0xFF1E3A5F),
            width: isExpanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: issue.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(issue.icon, color: issue.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                issue.label,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: issue.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(issue.confidence * 100).toInt()}%',
                                style: GoogleFonts.inter(
                                  color: issue.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          issue.plain,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: issue.color.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_forward_rounded,
                        color: issue.color, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Routing to: ${issue.departmentDisplay}',
                        style: GoogleFonts.inter(
                          color: issue.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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

  // STEP 2: routing
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepLabel(
          '2',
          'Where each issue is going',
          'Each problem routed to the right team',
        ),
        const SizedBox(height: 14),
        for (final issue in _issues) _routingRow(issue),
      ],
    );
  }

  Widget _routingRow(_Issue issue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: issue.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(issue.icon, color: issue.color, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    issue.label,
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                    width: 14, height: 1, color: issue.color.withOpacity(0.4)),
                Icon(Icons.arrow_forward_rounded, color: issue.color, size: 14),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: issue.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(issue.deptIcon, color: issue.color, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.departmentDisplay,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        issue.action,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 10,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // STEP 3: entities
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepLabel(
          '3',
          'Key details we found',
          'Extracted automatically from your message',
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1E35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E3A5F)),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _entities.entries.map((e) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF060E1E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E3A5F)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.key.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: Colors.white30,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.value,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF34D399),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // STEP 4: confidence (uses the Settings threshold)
  Widget _buildStep4(double threshold) {
    final pct = (_confidence * 100).toInt();
    final needsHuman = _needsHuman(threshold);
    final stepNum = _entities.isNotEmpty ? '4' : '3';
    const green = Color(0xFF16A34A);
    const amber = Color(0xFFD97706);
    final accent = needsHuman ? amber : green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepLabel(
          stepNum,
          'How confident is our AI',
          'Based on NLP pattern matching results',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1E35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E3A5F)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct.toDouble()),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      '${v.round()}%',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          needsHuman ? 'Needs human review' : 'High confidence',
                          style: GoogleFonts.inter(
                            color: accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _urgency == 'CRITICAL'
                              ? 'Critical cases are always reviewed by a human agent.'
                              : needsHuman
                                  ? 'Confidence is below your ${(threshold * 100).round()}% threshold, so an agent will verify before routing.'
                                  : 'AI automatically routed your case. No human review needed.',
                          style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // progress bar with a threshold marker
              LayoutBuilder(
                builder: (context, c) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _confidence.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 1400),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return SizedBox(
                        height: 14,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E3A5F),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Container(
                              height: 8,
                              width: c.maxWidth * value,
                              decoration: BoxDecoration(
                                color: needsHuman
                                    ? amber
                                    : const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Positioned(
                              left: c.maxWidth * threshold - 1,
                              child: Container(
                                width: 2,
                                height: 14,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Threshold: ${(threshold * 100).round()}%',
                    style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
                  ),
                  Row(
                    children: [
                      Icon(
                        needsHuman
                            ? Icons.person_rounded
                            : Icons.check_circle_rounded,
                        color: accent,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        needsHuman ? 'Human review' : 'Auto-routed',
                        style: GoogleFonts.inter(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFF1E3A5F)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customer sentiment',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  ),
                  Row(
                    children: [
                      Icon(_sentimentIcon(_sentiment),
                          color: _sentimentColor(_sentiment), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _sentiment,
                        style: GoogleFonts.inter(
                          color: _sentimentColor(_sentiment),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_detectedLang != 'en') ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Input language',
                      style:
                          GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.translate_rounded,
                            color: Color(0xFF7C3AED), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          _detectedLangName,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF7C3AED),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  bool _hasAny(String s, List<String> keys) {
    final lower = s.toLowerCase();
    return keys.any((k) => lower.contains(k.toLowerCase()));
  }

  IconData _sentimentIcon(String s) {
    if (_hasAny(s, ['frustrat', 'निराश', 'నిరాశ'])) {
      return Icons.sentiment_very_dissatisfied_rounded;
    }
    if (_hasAny(s, ['negative', 'नकार', 'ప్రతికూల', 'எதிர்மறை', 'নেতিবাচক'])) {
      return Icons.sentiment_dissatisfied_rounded;
    }
    if (_hasAny(s, ['positive', 'सकार', 'సానుకూల', 'நேர்மறை'])) {
      return Icons.sentiment_satisfied_rounded;
    }
    return Icons.sentiment_neutral_rounded;
  }

  Color _sentimentColor(String s) {
    if (_hasAny(s, ['frustrat', 'निराश', 'నిరాశ'])) {
      return const Color(0xFFDC2626);
    }
    if (_hasAny(s, ['negative', 'नकार', 'ప్రతికూల', 'எதிர்மறை', 'নেতিবাচক'])) {
      return const Color(0xFFD97706);
    }
    if (_hasAny(s, ['positive', 'सकार', 'సానుకూల', 'நேர்மறை'])) {
      return const Color(0xFF16A34A);
    }
    return Colors.white38;
  }

  // Why this routing (explainable AI)
  Widget _buildWhySection() {
    const amber = Color(0xFFD97706);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepLabel('i', 'Why this routing?', 'The AI explains its decision'),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => _xaiOpen = !_xaiOpen),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1E35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: amber.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        color: amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _xaiOpen
                            ? 'Reasons for this decision'
                            : 'Tap to see why',
                        style: GoogleFonts.inter(
                          color: amber,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      _xaiOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white38,
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: _xaiOpen
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Column(
                            children: [
                              for (int i = 0; i < _xaiReasons.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: amber.withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${i + 1}',
                                            style: GoogleFonts.inter(
                                              color: amber,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _xaiReasons[i],
                                          style: GoogleFonts.inter(
                                            color: Colors.white60,
                                            fontSize: 12,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFollowUpSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepLabel('?', 'We need a bit more info', 'To resolve your case faster'),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1E35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFF2563EB).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              for (final q in _followUpQuestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.help_outline_rounded,
                          color: Color(0xFF2563EB), size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          q,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTicketButtons() {
    const green = Color(0xFF16A34A);
    return Column(
      children: [
        GestureDetector(
          onTap: _ticketCreated ? null : _createTicket,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: _ticketCreated
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    ),
              color: _ticketCreated ? const Color(0xFF0F1E35) : null,
              borderRadius: BorderRadius.circular(14),
              border: _ticketCreated
                  ? Border.all(color: green.withOpacity(0.4))
                  : null,
              boxShadow: _ticketCreated
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _ticketCreated
                      ? Icons.check_circle_rounded
                      : Icons.confirmation_number_rounded,
                  color: _ticketCreated ? green : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _ticketCreated
                      ? 'Ticket created successfully'
                      : 'Create Support Ticket',
                  style: GoogleFonts.inter(
                    color: _ticketCreated ? green : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_ticketCreated) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _goToTickets,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2563EB)),
              ),
              child: Center(
                child: Text(
                  'View in My Tickets',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF60A5FA),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _stepLabel(String num, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              num,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Issue {
  final String label; // shown to the user (translated if available)
  final String labelEn; // English label stored on the ticket
  final IconData icon;
  final Color color;
  final String plain;
  final String department; // English, used for routing and icons
  final String departmentDisplay; // translated if available
  final IconData deptIcon;
  final String action;
  final double confidence;

  const _Issue({
    required this.label,
    required this.labelEn,
    required this.icon,
    required this.color,
    required this.plain,
    required this.department,
    required this.departmentDisplay,
    required this.deptIcon,
    required this.action,
    required this.confidence,
  });
}