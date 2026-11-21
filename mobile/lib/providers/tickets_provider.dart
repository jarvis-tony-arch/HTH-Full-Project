import 'package:flutter/material.dart';
import '../models/ticket.dart';
import '../services/api_service.dart';

class TicketsProvider extends ChangeNotifier {
  List<Ticket> _tickets = [];
  bool _isLoading = false;
  String? _error;

  List<Ticket> get tickets => _tickets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  TicketsProvider() {
    fetchTickets();
  }

  Future<void> fetchTickets() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.getTickets();
      
      _tickets = data.map((json) {
        List<String> issuesList = (json['issues'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [];
        List<String> deptsList = (json['departments'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [];
        
        return Ticket(
          id: json['ticket_id'] ?? '',
          rawQuery: json['raw_query'] ?? '',
          aiTitle: json['ai_title'] ?? '',
          aiSummary: json['ai_summary'] ?? '',
          urgency: json['urgency'] ?? 'LOW',
          sentiment: json['sentiment'] ?? 'Neutral',
          confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
          status: json['status'] ?? 'NEW',
          escalated: json['status'] == 'ESCALATED',
          issues: issuesList,
          departments: deptsList,
          createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : DateTime.now(),
        );
      }).toList();

    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTicket(Ticket ticket) async {
    _tickets.insert(0, ticket);
    notifyListeners();

    final success = await ApiService.createTicket(ticket.toBackendJson());
    
    if (!success) {
      _error = "Failed to save ticket to cloud.";
      notifyListeners();
    }
  }

  // --- Added back for the UI ---
  void updateTicketStatus(String ticketId, String status) {
    // For now, update the UI locally. 
    // In the future, this should call a PUT request to the backend.
    final index = _tickets.indexWhere((t) => t.id == ticketId);
    if (index != -1) {
      _tickets[index] = _tickets[index].copyWith(
        status: status, 
        escalated: status == 'ESCALATED'
      );
      notifyListeners();
    }
  }

  // --- Placeholder so the Settings screen doesn't crash ---
  void addDemoData() {
    // Do nothing. We have real data now!
    print("Demo data is disabled because we are using the real cloud database.");
  }

  void clearAll() {
    _tickets = [];
    notifyListeners();
  }
}