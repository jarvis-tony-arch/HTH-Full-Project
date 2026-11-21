import 'dart:math';
import '../models/analysis_result.dart';
import '../models/ticket.dart';
import '../models/issue.dart';
import '../models/entity.dart';
import '../models/department.dart';
import '../models/similar_ticket.dart';

/// Mock API Service — provides realistic demo data without a backend.
/// Simulates the full NLP pipeline response with processing delay.
class MockApiService {
  static final _random = Random();

  // ─── Issue → Department Mapping ────────────────────────
  static const Map<String, String> _issueDeptMap = {
    'delivery_issue': 'logistics',
    'late_delivery': 'logistics',
    'missing_package': 'logistics',
    'wrong_item': 'logistics',
    'duplicate_payment': 'payments',
    'overcharge': 'payments',
    'refund_request': 'refund',
    'billing_error': 'billing',
    'subscription_issue': 'billing',
    'account_locked': 'security',
    'unauthorized_access': 'security',
    'password_reset': 'account',
    'account_update': 'account',
    'profile_issue': 'account',
    'product_defect': 'product',
    'product_inquiry': 'product',
    'technical_error': 'technical',
    'app_crash': 'technical',
    'login_issue': 'technical',
    'general_inquiry': 'general',
    'feedback': 'general',
  };

  // ─── Keyword → Issue Detection ─────────────────────────
  static const Map<String, List<String>> _keywordIssueMap = {
    'delivery_issue': ['deliver', 'arrived', 'shipping', 'ship', 'package', 'tracking'],
    'late_delivery': ['late', 'delay', 'waiting', 'slow', 'days', 'week'],
    'missing_package': ['missing', 'lost', 'never received', 'not received', 'where is'],
    'wrong_item': ['wrong', 'incorrect', 'different', 'not what'],
    'duplicate_payment': ['charged twice', 'double charge', 'duplicate', 'two times', 'charged again'],
    'overcharge': ['overcharg', 'too much', 'extra charge', 'incorrect amount'],
    'refund_request': ['refund', 'money back', 'return', 'reimburse'],
    'billing_error': ['bill', 'invoice', 'statement', 'receipt'],
    'account_locked': ['locked', 'blocked', 'suspended', 'disabled', 'frozen'],
    'unauthorized_access': ['hack', 'unauthorized', 'fraud', 'stolen', 'someone else', 'suspicious'],
    'password_reset': ['password', 'reset', 'forgot', 'can\'t log in', 'cannot login'],
    'product_defect': ['broken', 'defect', 'damaged', 'not working', 'faulty', 'malfunction'],
    'technical_error': ['error', 'bug', 'crash', 'glitch', 'not loading'],
    'app_crash': ['app crash', 'app not', 'force close', 'stopped working'],
    'general_inquiry': ['how to', 'what is', 'information', 'help', 'question'],
  };

  // ─── Urgency Keyword Detection ─────────────────────────
  static const List<String> _criticalKeywords = [
    'hack', 'fraud', 'unauthorized', 'stolen', 'security', 'breach', 'compromised',
  ];
  static const List<String> _highKeywords = [
    'urgent', 'immediately', 'asap', 'cannot wait', 'emergency', 'critical',
    'charged twice', 'overcharge', 'lost money',
  ];
  static const List<String> _mediumKeywords = [
    'broken', 'not working', 'missing', 'wrong', 'defect', 'error', 'late',
  ];

  /// Analyze a customer query — simulates the full NLP pipeline.
  static Future<AnalysisResult> analyzeQuery(String query) async {
    // Simulate processing delay (1.5–2.5 seconds)
    final delayMs = 1500 + _random.nextInt(1000);
    await Future.delayed(Duration(milliseconds: delayMs));

    final queryLower = query.toLowerCase();

    // Detect issues (multi-label)
    final detectedIssues = <Issue>[];
    for (final entry in _keywordIssueMap.entries) {
      for (final keyword in entry.value) {
        if (queryLower.contains(keyword)) {
          final confidence = 0.70 + _random.nextDouble() * 0.28;
          detectedIssues.add(Issue(
            label: entry.key,
            confidence: confidence,
          ));
          break;
        }
      }
    }

    // Default to general inquiry if nothing detected
    if (detectedIssues.isEmpty) {
      detectedIssues.add(const Issue(
        label: 'general_inquiry',
        confidence: 0.55,
      ));
    }

    // Extract entities
    final entities = _extractEntities(query);

    // Determine urgency
    final urgency = _classifyUrgency(queryLower);

    // Determine sentiment
    final sentiment = _classifySentiment(queryLower);

    // Calculate overall confidence (average of issue confidences)
    final avgConfidence =
        detectedIssues.fold<double>(0, (s, i) => s + i.confidence) /
            detectedIssues.length;

    final escalated = avgConfidence < 0.65;

    // Build routing
    final departments = <Department>[];
    final seenDepts = <String>{};
    for (var i = 0; i < detectedIssues.length; i++) {
      final dept = _issueDeptMap[detectedIssues[i].label] ?? 'general';
      if (!seenDepts.contains(dept)) {
        seenDepts.add(dept);
        departments.add(Department(
          name: dept,
          isPrimary: i == 0,
        ));
      }
    }

    // Build word importance map
    final wordImportance = _buildWordImportance(query, detectedIssues);

    // Build explanation
    final explanation = _buildExplanation(detectedIssues, departments, urgency, escalated);

    // AI title
    final aiTitle = _generateTitle(detectedIssues, entities);

    // AI summary
    final aiSummary = _generateSummary(detectedIssues, entities, urgency, sentiment);

    // Similar tickets
    final similarTickets = _generateSimilarTickets(detectedIssues);

    return AnalysisResult(
      issues: detectedIssues,
      entities: entities,
      urgency: urgency,
      sentiment: sentiment,
      confidence: avgConfidence,
      escalatedToHuman: escalated,
      routing: departments,
      explanation: explanation,
      wordImportance: wordImportance,
      aiTitle: aiTitle,
      aiSummary: aiSummary,
      similarTickets: similarTickets,
      inferenceMs: delayMs,
    );
  }

  static List<Entity> _extractEntities(String query) {
    final entities = <Entity>[];

    // Order ID pattern: #1234 or order 1234 or ORD-1234
    final orderIdRegex = RegExp(r'#(\d{4,})|(?:order|ORD)[-\s]?(\d{4,})', caseSensitive: false);
    for (final match in orderIdRegex.allMatches(query)) {
      entities.add(Entity(
        type: 'ORDER_ID',
        value: '#${match.group(1) ?? match.group(2)}',
      ));
    }

    // Amount pattern: $123, ₹456, Rs.789
    final amountRegex = RegExp(r'[\$₹][\d,]+\.?\d*|Rs\.?\s*[\d,]+\.?\d*', caseSensitive: false);
    for (final match in amountRegex.allMatches(query)) {
      entities.add(Entity(
        type: 'AMOUNT',
        value: match.group(0)!,
      ));
    }

    // Date patterns
    final dateRegex = RegExp(
      r'\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}|'
      r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+\d{1,2}(?:,?\s+\d{4})?|'
      r'(?:yesterday|today|last\s+week|last\s+month)',
      caseSensitive: false,
    );
    for (final match in dateRegex.allMatches(query)) {
      entities.add(Entity(
        type: 'DATE',
        value: match.group(0)!,
      ));
    }

    // Email
    final emailRegex = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
    for (final match in emailRegex.allMatches(query)) {
      entities.add(Entity(
        type: 'EMAIL',
        value: match.group(0)!,
      ));
    }

    // Phone
    final phoneRegex = RegExp(r'(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}');
    for (final match in phoneRegex.allMatches(query)) {
      entities.add(Entity(
        type: 'PHONE',
        value: match.group(0)!,
      ));
    }

    // If no entities found, add a placeholder product mention if query mentions a product
    if (entities.isEmpty) {
      final productWords = ['phone', 'laptop', 'headphones', 'tablet', 'watch', 'earbuds', 'charger', 'cable'];
      for (final word in productWords) {
        if (query.toLowerCase().contains(word)) {
          entities.add(Entity(type: 'PRODUCT', value: word[0].toUpperCase() + word.substring(1)));
          break;
        }
      }
    }

    return entities;
  }

  static String _classifyUrgency(String queryLower) {
    for (final kw in _criticalKeywords) {
      if (queryLower.contains(kw)) return 'CRITICAL';
    }
    for (final kw in _highKeywords) {
      if (queryLower.contains(kw)) return 'HIGH';
    }
    for (final kw in _mediumKeywords) {
      if (queryLower.contains(kw)) return 'MEDIUM';
    }
    return 'LOW';
  }

  static String _classifySentiment(String queryLower) {
    const frustratedWords = ['furious', 'terrible', 'worst', 'unacceptable', 'ridiculous', 'disgusting', 'awful', 'scam'];
    const negativeWords = ['upset', 'angry', 'annoyed', 'disappointed', 'frustrated', 'unhappy', 'bad', 'poor', 'hate'];
    const positiveWords = ['thanks', 'great', 'good', 'happy', 'love', 'excellent', 'amazing', 'appreciate'];

    for (final w in frustratedWords) {
      if (queryLower.contains(w)) return 'FRUSTRATED';
    }
    for (final w in negativeWords) {
      if (queryLower.contains(w)) return 'NEGATIVE';
    }
    for (final w in positiveWords) {
      if (queryLower.contains(w)) return 'POSITIVE';
    }
    return 'NEUTRAL';
  }

  static Map<String, double> _buildWordImportance(String query, List<Issue> issues) {
    final words = query.split(RegExp(r'\s+'));
    final importance = <String, double>{};

    // Common issue keywords get higher importance
    final issueLabels = issues.map((i) => i.label).toSet();
    for (final word in words) {
      final wordLower = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
      if (wordLower.isEmpty) continue;

      double score = 0.1 + _random.nextDouble() * 0.2; // base importance

      // Check if word matches any issue keywords
      for (final entry in _keywordIssueMap.entries) {
        if (issueLabels.contains(entry.key)) {
          for (final kw in entry.value) {
            if (kw.contains(wordLower) || wordLower.contains(kw)) {
              score = 0.6 + _random.nextDouble() * 0.4;
              break;
            }
          }
        }
      }

      // Urgency keywords get high importance
      if (_criticalKeywords.any((k) => wordLower.contains(k))) {
        score = 0.9 + _random.nextDouble() * 0.1;
      } else if (_highKeywords.any((k) => wordLower.contains(k) || k.contains(wordLower))) {
        score = 0.7 + _random.nextDouble() * 0.2;
      }

      importance[word] = score;
    }

    return importance;
  }

  static String _buildExplanation(
    List<Issue> issues, List<Department> departments, String urgency, bool escalated,
  ) {
    final issueNames = issues.map((i) => i.formattedLabel).join(', ');
    final deptNames = departments.map((d) => d.formattedName).join(' and ');

    var explanation = 'Detected ${issues.length} issue${issues.length > 1 ? 's' : ''}: '
        '$issueNames. ';

    if (issues.length > 1) {
      explanation += 'This query contains multiple independent issues that require attention from different teams. ';
    }

    explanation += 'Routing to $deptNames department${departments.length > 1 ? 's' : ''} '
        'based on keyword analysis and intent classification. ';

    explanation += 'Urgency classified as $urgency ';

    switch (urgency) {
      case 'CRITICAL':
        explanation += 'due to security/fraud-related language detected in the query. ';
        break;
      case 'HIGH':
        explanation += 'due to explicit urgency markers or financial impact indicators. ';
        break;
      case 'MEDIUM':
        explanation += 'based on service failure indicators in the query. ';
        break;
      case 'LOW':
        explanation += 'as the query appears to be an informational request. ';
        break;
    }

    if (escalated) {
      explanation += '⚠ Confidence below threshold — routed to human review for verification.';
    }

    return explanation;
  }

  static String _generateTitle(List<Issue> issues, List<Entity> entities) {
    if (issues.isEmpty) return 'Customer Support Query';

    final mainIssue = issues.first.formattedLabel;
    if (entities.isNotEmpty) {
      final entityStr = entities.first.value;
      return '$mainIssue — $entityStr';
    }
    if (issues.length > 1) {
      return '$mainIssue + ${issues.length - 1} More Issue${issues.length > 2 ? 's' : ''}';
    }
    return mainIssue;
  }

  static String _generateSummary(
    List<Issue> issues, List<Entity> entities, String urgency, String sentiment,
  ) {
    final issueNames = issues.map((i) => i.formattedLabel.toLowerCase()).join(', ');
    final entityStr = entities.isNotEmpty
        ? ' involving ${entities.map((e) => '${e.formattedType}: ${e.value}').join(', ')}'
        : '';

    return 'Customer reports $issueNames$entityStr '
        'with ${urgency.toLowerCase()} urgency. '
        'Sentiment: ${sentiment.toLowerCase()}.';
  }

  static List<SimilarTicket> _generateSimilarTickets(List<Issue> issues) {
    if (issues.isEmpty) return [];

    final templates = <Map<String, String>>[
      {'title': 'Late delivery for order #7832', 'summary': 'Package delayed by 5 days, customer requesting tracking update', 'urgency': 'MEDIUM'},
      {'title': 'Double charge on credit card', 'summary': 'Customer charged twice for single order, refund requested', 'urgency': 'HIGH'},
      {'title': 'Account security concern', 'summary': 'Suspicious login attempt detected, password reset needed', 'urgency': 'CRITICAL'},
      {'title': 'Product arrived damaged', 'summary': 'Laptop screen cracked during shipping, replacement requested', 'urgency': 'MEDIUM'},
      {'title': 'Refund not received after 15 days', 'summary': 'Refund approved but not yet credited to bank account', 'urgency': 'HIGH'},
      {'title': 'Wrong item shipped', 'summary': 'Received blue headphones instead of black, exchange needed', 'urgency': 'MEDIUM'},
      {'title': 'App login failure', 'summary': 'Unable to login after app update, error code 403', 'urgency': 'LOW'},
      {'title': 'Subscription auto-renewed', 'summary': 'Subscription renewed without consent, cancellation requested', 'urgency': 'HIGH'},
    ];

    templates.shuffle(_random);
    final count = min(3, templates.length);
    return List.generate(count, (i) {
      final t = templates[i];
      return SimilarTicket(
        id: 'TKT-${1000 + _random.nextInt(9000)}',
        title: t['title']!,
        summary: t['summary']!,
        similarityScore: 0.75 + _random.nextDouble() * 0.20,
        status: ['resolved', 'closed'][_random.nextInt(2)],
        urgency: t['urgency']!,
      );
    });
  }

  // ─── Ticket Management ────────────────────────────────
  static final List<Ticket> _tickets = _generateInitialTickets();

  static List<Ticket> _generateInitialTickets() {
    final now = DateTime.now();
    return [
      Ticket(
        id: 'TKT-1001',
        rawQuery: 'My order #4521 hasn\'t arrived and it\'s been 10 days',
        aiTitle: 'Late Delivery — #4521',
        aiSummary: 'Customer reports late delivery involving Order Id: #4521 with high urgency.',
        status: 'open',
        urgency: 'HIGH',
        sentiment: 'NEGATIVE',
        confidence: 0.89,
        escalated: false,
        issues: [const Issue(label: 'late_delivery', confidence: 0.91)],
        entities: [const Entity(type: 'ORDER_ID', value: '#4521')],
        departments: [const Department(name: 'logistics', isPrimary: true)],
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      Ticket(
        id: 'TKT-1002',
        rawQuery: 'I was charged twice for my subscription and I want a refund immediately',
        aiTitle: 'Duplicate Payment + Refund Request',
        aiSummary: 'Customer reports duplicate payment, refund request with high urgency. Sentiment: frustrated.',
        status: 'in_progress',
        urgency: 'HIGH',
        sentiment: 'FRUSTRATED',
        confidence: 0.85,
        escalated: false,
        issues: [
          const Issue(label: 'duplicate_payment', confidence: 0.88),
          const Issue(label: 'refund_request', confidence: 0.82),
        ],
        entities: [],
        departments: [
          const Department(name: 'payments', isPrimary: true),
          const Department(name: 'refund'),
        ],
        createdAt: now.subtract(const Duration(hours: 5)),
        updatedAt: now.subtract(const Duration(hours: 3)),
      ),
      Ticket(
        id: 'TKT-1003',
        rawQuery: 'Someone hacked into my account and made unauthorized purchases',
        aiTitle: 'Unauthorized Access — Security Breach',
        aiSummary: 'Customer reports unauthorized access with critical urgency. Sentiment: frustrated.',
        status: 'escalated',
        urgency: 'CRITICAL',
        sentiment: 'FRUSTRATED',
        confidence: 0.92,
        escalated: true,
        issues: [const Issue(label: 'unauthorized_access', confidence: 0.94)],
        entities: [],
        departments: [const Department(name: 'security', isPrimary: true)],
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
      ),
      Ticket(
        id: 'TKT-1004',
        rawQuery: 'The laptop I received has a cracked screen and the charger cable is missing',
        aiTitle: 'Product Defect + Missing Package',
        aiSummary: 'Customer reports product defect, missing package involving Product: Laptop with medium urgency.',
        status: 'open',
        urgency: 'MEDIUM',
        sentiment: 'NEGATIVE',
        confidence: 0.78,
        escalated: false,
        issues: [
          const Issue(label: 'product_defect', confidence: 0.86),
          const Issue(label: 'missing_package', confidence: 0.72),
        ],
        entities: [const Entity(type: 'PRODUCT', value: 'Laptop')],
        departments: [
          const Department(name: 'product', isPrimary: true),
          const Department(name: 'logistics'),
        ],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 20)),
      ),
      Ticket(
        id: 'TKT-1005',
        rawQuery: 'How do I update my shipping address?',
        aiTitle: 'Account Update — General Inquiry',
        aiSummary: 'Customer reports general inquiry with low urgency. Sentiment: neutral.',
        status: 'resolved',
        urgency: 'LOW',
        sentiment: 'NEUTRAL',
        confidence: 0.91,
        escalated: false,
        issues: [const Issue(label: 'account_update', confidence: 0.88)],
        entities: [],
        departments: [const Department(name: 'account', isPrimary: true)],
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Ticket(
        id: 'TKT-1006',
        rawQuery: 'I received the wrong item — ordered blue headphones but got red ones, also the bill shows \$149 but I was charged \$199',
        aiTitle: 'Wrong Item + Overcharge',
        aiSummary: 'Customer reports wrong item, overcharge involving Amount: \$149, Amount: \$199 with medium urgency.',
        status: 'in_progress',
        urgency: 'MEDIUM',
        sentiment: 'NEGATIVE',
        confidence: 0.83,
        escalated: false,
        issues: [
          const Issue(label: 'wrong_item', confidence: 0.90),
          const Issue(label: 'overcharge', confidence: 0.79),
        ],
        entities: [
          const Entity(type: 'PRODUCT', value: 'Headphones'),
          const Entity(type: 'AMOUNT', value: '\$149'),
          const Entity(type: 'AMOUNT', value: '\$199'),
        ],
        departments: [
          const Department(name: 'logistics', isPrimary: true),
          const Department(name: 'payments'),
        ],
        createdAt: now.subtract(const Duration(days: 1, hours: 6)),
        updatedAt: now.subtract(const Duration(hours: 18)),
      ),
      Ticket(
        id: 'TKT-1007',
        rawQuery: 'The app keeps crashing every time I try to check my order status',
        aiTitle: 'App Crash — Technical Error',
        aiSummary: 'Customer reports app crash, technical error with medium urgency.',
        status: 'open',
        urgency: 'MEDIUM',
        sentiment: 'NEGATIVE',
        confidence: 0.87,
        escalated: false,
        issues: [
          const Issue(label: 'app_crash', confidence: 0.91),
          const Issue(label: 'technical_error', confidence: 0.84),
        ],
        entities: [],
        departments: [const Department(name: 'technical', isPrimary: true)],
        createdAt: now.subtract(const Duration(hours: 8)),
        updatedAt: now.subtract(const Duration(hours: 7)),
      ),
    ];
  }

  static Future<List<Ticket>> getTickets() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_tickets);
  }

  static Future<Ticket?> getTicketById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _tickets.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<Ticket> createTicket(AnalysisResult result, String rawQuery) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final ticket = Ticket(
      id: 'TKT-${2000 + _tickets.length}',
      rawQuery: rawQuery,
      aiTitle: result.aiTitle,
      aiSummary: result.aiSummary,
      status: result.escalatedToHuman ? 'escalated' : 'open',
      urgency: result.urgency,
      sentiment: result.sentiment,
      confidence: result.confidence,
      escalated: result.escalatedToHuman,
      issues: result.issues,
      entities: result.entities,
      departments: result.routing,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _tickets.insert(0, ticket);
    return ticket;
  }

  static Future<Ticket> updateTicketStatus(String id, String status) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _tickets.indexWhere((t) => t.id == id);
    if (index >= 0) {
      _tickets[index] = _tickets[index].copyWithStatus(status);
      return _tickets[index];
    }
    throw Exception('Ticket not found: $id');
  }

  // ─── Dashboard Analytics ──────────────────────────────
  static Future<Map<String, dynamic>> getDashboardStats() async {
    await Future.delayed(const Duration(milliseconds: 300));

    final tickets = _tickets;
    final total = tickets.length;
    final open = tickets.where((t) => t.status == 'open').length;
    final inProgress = tickets.where((t) => t.status == 'in_progress').length;
    final escalated = tickets.where((t) => t.escalated).length;
    final resolved = tickets.where((t) => t.status == 'resolved' || t.status == 'closed').length;

    // Issue distribution
    final issueCounts = <String, int>{};
    for (final t in tickets) {
      for (final i in t.issues) {
        issueCounts[i.formattedLabel] = (issueCounts[i.formattedLabel] ?? 0) + 1;
      }
    }

    // Urgency distribution
    final urgencyCounts = <String, int>{};
    for (final t in tickets) {
      urgencyCounts[t.urgency] = (urgencyCounts[t.urgency] ?? 0) + 1;
    }

    // Department distribution
    final deptCounts = <String, int>{};
    for (final t in tickets) {
      for (final d in t.departments) {
        deptCounts[d.formattedName] = (deptCounts[d.formattedName] ?? 0) + 1;
      }
    }

    // Average confidence
    final avgConfidence = tickets.fold<double>(0, (s, t) => s + t.confidence) / total;

    return {
      'total': total,
      'open': open,
      'in_progress': inProgress,
      'escalated': escalated,
      'resolved': resolved,
      'avg_confidence': avgConfidence,
      'issue_distribution': issueCounts,
      'urgency_distribution': urgencyCounts,
      'department_distribution': deptCounts,
    };
  }
}
