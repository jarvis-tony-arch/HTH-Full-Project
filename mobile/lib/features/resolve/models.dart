// Models for the /sections and /resolve API.
// Field names mirror backend/app/schemas.py (ResolveResponse etc.).

List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    (v as List? ?? []).map((e) => f(e as Map<String, dynamic>)).toList();

class SectionCompany {
  final String id, name, initial;
  SectionCompany(this.id, this.name, this.initial);
  factory SectionCompany.fromJson(Map<String, dynamic> j) =>
      SectionCompany(j['id'], j['name'], j['initial']);
}

class SectionInfo {
  final String id, title, subtitle;
  final List<String> examples;
  final List<SectionCompany> companies;
  SectionInfo(this.id, this.title, this.subtitle, this.examples, this.companies);
  factory SectionInfo.fromJson(Map<String, dynamic> j) => SectionInfo(
        j['id'], j['title'], j['subtitle'],
        (j['examples'] as List).cast<String>(),
        _list(j['companies'], SectionCompany.fromJson),
      );
}

class Contact {
  final String kind; // phone | email | url | whatsapp | none
  final String label;
  final String? value;
  final bool verified;
  final String? sourceUrl;
  Contact(this.kind, this.label, this.value, this.verified, this.sourceUrl);
  factory Contact.fromJson(Map<String, dynamic> j) =>
      Contact(j['kind'], j['label'], j['value'], j['verified'], j['source_url']);
  Map<String, dynamic> toJson() => {
        'kind': kind, 'label': label, 'value': value,
        'verified': verified, 'source_url': sourceUrl,
      };
}

class FixStep {
  final int level;
  final String id, title, instructions, channel, deadlineBasis;
  final Contact contact;
  final List<Contact> otherContacts;
  final bool verified;
  final int? deadlineHours, acknowledgeHours;
  FixStep({
    required this.level, required this.id, required this.title,
    required this.instructions, required this.channel, required this.contact,
    required this.otherContacts, required this.verified,
    required this.deadlineHours, required this.deadlineBasis, this.acknowledgeHours,
  });
  factory FixStep.fromJson(Map<String, dynamic> j) => FixStep(
        level: j['level'], id: j['id'], title: j['title'],
        instructions: j['instructions'], channel: j['channel'],
        contact: Contact.fromJson(j['contact']),
        otherContacts: _list(j['other_contacts'], Contact.fromJson),
        verified: j['verified'], deadlineHours: j['deadline_hours'],
        deadlineBasis: j['deadline_basis'], acknowledgeHours: j['acknowledge_hours'],
      );
  Map<String, dynamic> toJson() => {
        'level': level, 'id': id, 'title': title, 'instructions': instructions,
        'channel': channel, 'contact': contact.toJson(),
        'other_contacts': otherContacts.map((c) => c.toJson()).toList(),
        'verified': verified, 'deadline_hours': deadlineHours,
        'deadline_basis': deadlineBasis, 'acknowledge_hours': acknowledgeHours,
        'is_current': false, 'is_done': false,
      };
}

class Entitlement {
  final String text, status, basis; // status: owed | maybe | not_owed | info
  final String? sourceUrl;
  Entitlement(this.text, this.status, this.basis, this.sourceUrl);
  factory Entitlement.fromJson(Map<String, dynamic> j) =>
      Entitlement(j['text'], j['status'], j['basis'], j['source_url']);
  Map<String, dynamic> toJson() =>
      {'text': text, 'status': status, 'basis': basis, 'source_url': sourceUrl};
}

class Complaint {
  final String? to;
  final String subject, body;
  Complaint(this.to, this.subject, this.body);
  factory Complaint.fromJson(Map<String, dynamic> j) =>
      Complaint(j['to'], j['subject'], j['body']);
  Map<String, dynamic> toJson() => {'to': to, 'subject': subject, 'body': body};
}

class ResolvedIssue {
  final String issueType, title, summary, urgency;
  final double confidence;
  final List<String> xaiReasons;
  final Map<String, String> entities;
  final List<Entitlement> entitlements;
  final String? urgentAction, startReason;
  final int startLevel;
  final List<FixStep> steps, alternateSteps;
  final Complaint complaint;
  ResolvedIssue({
    required this.issueType, required this.title, required this.summary,
    required this.urgency, required this.confidence, required this.xaiReasons,
    required this.entities, required this.entitlements, required this.urgentAction,
    required this.startReason, required this.startLevel, required this.steps,
    required this.alternateSteps, required this.complaint,
  });
  factory ResolvedIssue.fromJson(Map<String, dynamic> j) => ResolvedIssue(
        issueType: j['issue_type'], title: j['title'], summary: j['summary'],
        urgency: j['urgency'], confidence: (j['confidence'] as num).toDouble(),
        xaiReasons: (j['xai_reasons'] as List).cast<String>(),
        entities: (j['entities'] as Map).map((k, v) => MapEntry('$k', '$v')),
        entitlements: _list(j['entitlements'], Entitlement.fromJson),
        urgentAction: j['urgent_action'], startReason: j['start_reason'],
        startLevel: j['start_level'],
        steps: _list(j['steps'], FixStep.fromJson),
        alternateSteps: _list(j['alternate_steps'], FixStep.fromJson),
        complaint: Complaint.fromJson(j['complaint']),
      );
  Map<String, dynamic> toJson() => {
        'issue_type': issueType, 'title': title, 'summary': summary,
        'urgency': urgency, 'confidence': confidence, 'xai_reasons': xaiReasons,
        'entities': entities,
        'entitlements': entitlements.map((e) => e.toJson()).toList(),
        'urgent_action': urgentAction, 'start_reason': startReason,
        'start_level': startLevel,
        'steps': steps.map((s) => s.toJson()).toList(),
        'alternate_steps': alternateSteps.map((s) => s.toJson()).toList(),
        'complaint': complaint.toJson(),
      };
}

class ClarifyOption {
  final String label;
  final String? section, company, issueType;
  ClarifyOption(this.label, this.section, this.company, this.issueType);
  factory ClarifyOption.fromJson(Map<String, dynamic> j) =>
      ClarifyOption(j['label'], j['section'], j['company'], j['issue_type']);
}

class ResolveResult {
  final String? section, company, companyName, clarificationQuestion;
  final bool needsClarification;
  final List<ClarifyOption> options;
  final List<ResolvedIssue> issues;
  ResolveResult({
    required this.section, required this.company, required this.companyName,
    required this.needsClarification, required this.clarificationQuestion,
    required this.options, required this.issues,
  });
  factory ResolveResult.fromJson(Map<String, dynamic> j) => ResolveResult(
        section: j['section'], company: j['company'], companyName: j['company_name'],
        needsClarification: j['needs_clarification'],
        clarificationQuestion: j['clarification_question'],
        options: _list(j['clarification_options'], ClarifyOption.fromJson),
        issues: _list(j['issues'], ResolvedIssue.fromJson),
      );
}

/// One evidence-log entry: what was done, when, and any ticket number.
class EvidenceEntry {
  final DateTime at;
  final String what;
  final String? ticket;
  EvidenceEntry(this.at, this.what, [this.ticket]);
  factory EvidenceEntry.fromJson(Map<String, dynamic> j) =>
      EvidenceEntry(DateTime.parse(j['at']), j['what'], j['ticket']);
  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'what': what, 'ticket': ticket};
}

/// A case saved on the phone (no server tables, per the plan).
class SavedCase {
  final String id;
  final String section;
  final String? companyId, companyName;
  final String userText;
  final ResolvedIssue issue;
  int currentLevel;
  DateTime stepStartedAt;
  bool solved;
  final DateTime createdAt;
  final List<EvidenceEntry> evidence;

  SavedCase({
    required this.id, required this.section, required this.companyId,
    required this.companyName, required this.userText, required this.issue,
    required this.currentLevel, required this.stepStartedAt,
    required this.createdAt, this.solved = false, List<EvidenceEntry>? evidence,
  }) : evidence = evidence ?? [];

  FixStep get currentStep =>
      issue.steps.firstWhere((s) => s.level == currentLevel, orElse: () => issue.steps.last);
  bool get hasNextStep => currentLevel < issue.steps.last.level;

  /// When the current step's deadline passes (null for the last step).
  DateTime? get deadline {
    final h = currentStep.deadlineHours;
    return h == null ? null : stepStartedAt.add(Duration(hours: h));
  }

  factory SavedCase.fromJson(Map<String, dynamic> j) => SavedCase(
        id: j['id'], section: j['section'], companyId: j['company_id'],
        companyName: j['company_name'], userText: j['user_text'],
        issue: ResolvedIssue.fromJson(j['issue']),
        currentLevel: j['current_level'],
        stepStartedAt: DateTime.parse(j['step_started_at']),
        createdAt: DateTime.parse(j['created_at']),
        solved: j['solved'] ?? false,
        evidence: _list(j['evidence'], EvidenceEntry.fromJson),
      );
  Map<String, dynamic> toJson() => {
        'id': id, 'section': section, 'company_id': companyId,
        'company_name': companyName, 'user_text': userText,
        'issue': issue.toJson(), 'current_level': currentLevel,
        'step_started_at': stepStartedAt.toIso8601String(),
        'created_at': createdAt.toIso8601String(), 'solved': solved,
        'evidence': evidence.map((e) => e.toJson()).toList(),
      };
}
