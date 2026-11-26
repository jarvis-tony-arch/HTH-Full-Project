from pydantic import BaseModel, ConfigDict
from typing import Dict, List, Optional

class AnalyzeRequest(BaseModel):
    text: str
    language: Optional[str] = None

class IssueDetail(BaseModel):
    intent: str        # Changed from 'issue' to 'intent'
    display: str       # Added this
    department: str
    confidence: float
    matched_count: int # Added this

class AnalyzeResponse(BaseModel):
    original_text: str
    processed_text: str
    detected_language: str
    detected_language_name: str
    hinglish_detected: bool
    issues: List[IssueDetail]
    departments: List[str]
    urgency: str
    sentiment: str
    confidence: float
    xai_reasons: List[str]  # Changed from 'explanations' to 'xai_reasons'
    missing_info: List[str] # Added this
    follow_up_questions: List[str]
    translated_text: Optional[str] = None

class TicketCreate(BaseModel):
    ticket_id: str
    raw_query: str
    ai_title: str
    ai_summary: str
    urgency: str
    sentiment: str
    confidence: float
    issues: List[str]
    departments: List[str]

class TicketResponse(TicketCreate):
    status: str


# ─── Resolve (pivot) schemas ──────────────────────────
# These mirror the dicts built in services/resolve_service.py exactly.
# extra="forbid" makes any drift between the two fail loudly.

class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class ResolveRequest(BaseModel):
    text: str
    section: Optional[str] = None
    company: Optional[str] = None
    issue_type: Optional[str] = None


class Contact(_Strict):
    kind: str                      # phone | email | url | whatsapp | none
    label: str
    value: Optional[str] = None    # None when unverified -> app shows "Check the official page"
    verified: bool
    source_url: Optional[str] = None


class ResolveStep(_Strict):
    level: int
    id: str
    title: str
    instructions: str
    channel: str
    contact: Contact
    other_contacts: List[Contact]
    verified: bool
    deadline_hours: Optional[int] = None
    deadline_basis: str            # rule | default | final
    acknowledge_hours: Optional[int] = None
    is_current: bool
    is_done: bool


class Entitlement(_Strict):
    text: str
    status: str                    # owed | maybe | not_owed | info
    basis: str
    source_url: Optional[str] = None


class Complaint(_Strict):
    to: Optional[str] = None
    subject: str
    body: str


class ResolvedIssue(_Strict):
    issue_type: str
    title: str
    summary: str
    confidence: float
    xai_reasons: List[str]
    entities: Dict[str, str]
    urgency: str                   # low | medium | high
    entitlements: List[Entitlement]
    urgent_action: Optional[str] = None
    start_level: int
    start_reason: Optional[str] = None
    steps: List[ResolveStep]
    alternate_steps: List[ResolveStep]
    complaint: Complaint


class ClarificationOption(_Strict):
    label: str
    section: Optional[str] = None
    company: Optional[str] = None
    issue_type: Optional[str] = None


class ResolveResponse(_Strict):
    section: Optional[str] = None
    company: Optional[str] = None
    company_name: Optional[str] = None
    company_confidence: float
    needs_clarification: bool
    clarification_question: Optional[str] = None
    clarification_options: List[ClarificationOption]
    issues: List[ResolvedIssue]


class SectionCompany(_Strict):
    id: str
    name: str
    initial: str


class SectionIssue(_Strict):
    id: str
    title: str


class Section(_Strict):
    id: str
    title: str
    subtitle: str
    examples: List[str]
    companies: List[SectionCompany]
    issues: List[SectionIssue]


class SectionsResponse(_Strict):
    sections: List[Section]
    last_verified: str