// lib/data/in_memory_store.dart

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../models/ticket.dart';
import '../models/report.dart';
import '../utils/enums.dart';
import 'dummy_data.dart';

class InMemoryStore extends ChangeNotifier {
  InMemoryStore() {
    _users = List<AppUser>.from(DummyData.users);
    _tickets = DummyData.initialTickets();
  }

  late final List<AppUser> _users;
  late List<Ticket> _tickets;
  final List<Report> _reports = [];

  AppUser? _currentUser;

  // ----------------------------
  // Getters
  // ----------------------------
  List<AppUser> get users => List.unmodifiable(_users);
  List<Ticket> get tickets => List.unmodifiable(_tickets);
  List<Report> get reports => List.unmodifiable(_reports);

  AppUser? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.role == UserRole.admin;
  bool get isTechnician => _currentUser?.role == UserRole.technician;

  List<AppUser> get technicians =>
      _users.where((u) => u.role == UserRole.technician).toList(growable: false);

  // Admin sees all tickets; technician sees only assigned tickets.
  List<Ticket> get visibleTickets {
    final user = _currentUser;
    if (user == null) return [];

    if (user.role == UserRole.admin) {
      return List.unmodifiable(_tickets);
    }

    return List.unmodifiable(
      _tickets.where((t) => t.assignedTo == user.id),
    );
  }

  Ticket? getTicketById(String ticketId) {
    try {
      return _tickets.firstWhere((t) => t.id == ticketId);
    } catch (_) {
      return null;
    }
  }

  // ----------------------------
  // Session
  // ----------------------------
  void loginAs(AppUser user) {
    _currentUser = user;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  // ----------------------------
  // Admin actions
  // ----------------------------
  Ticket createTicket({
    required String title,
    required String description,
  }) {
    final user = _currentUser;
    if (user == null || user.role != UserRole.admin) {
      throw StateError('Only Admin can create tickets.');
    }

    final now = DateTime.now();
    final id = 't_${now.millisecondsSinceEpoch}';

    final ticket = Ticket(
      id: id,
      title: title.trim(),
      description: description.trim(),
      status: TicketStatus.newTicket,
      createdBy: user.id,
      createdAt: now,
      updatedAt: now,
    );

    _tickets = [ticket, ..._tickets];
    notifyListeners();
    return ticket;
  }

  void assignTicket({
    required String ticketId,
    required String technicianId,
  }) {
    final user = _currentUser;
    if (user == null || user.role != UserRole.admin) {
      throw StateError('Only Admin can assign tickets.');
    }

    final now = DateTime.now();

    _tickets = _tickets.map((t) {
      if (t.id != ticketId) return t;

      return t.copyWith(
        assignedTo: technicianId,
        status: TicketStatus.assigned,
        updatedAt: now,
      );
    }).toList();

    notifyListeners();
  }

  // ----------------------------
  // Technician actions
  // ----------------------------
  void updateTicketStatus({
    required String ticketId,
    required TicketStatus status,
  }) {
    final user = _currentUser;
    if (user == null || user.role != UserRole.technician) {
      throw StateError('Only Technician can update ticket status.');
    }

    final ticket = getTicketById(ticketId);
    if (ticket == null) return;

    // Technician can only update their assigned tickets.
    if (ticket.assignedTo != user.id) {
      throw StateError('Technician can only update their own assigned tickets.');
    }

    final now = DateTime.now();
    _tickets = _tickets.map((t) {
      if (t.id != ticketId) return t;
      return t.copyWith(status: status, updatedAt: now);
    }).toList();

    notifyListeners();
  }

  // ----------------------------
  // Mock AI - Checklist
  // ----------------------------
  void generateChecklistMock({
    required String ticketId,
  }) {
    final user = _currentUser;
    if (user == null) throw StateError('Login required.');

    final ticket = getTicketById(ticketId);
    if (ticket == null) return;

    // Optional: Only assigned technician can generate checklist
    if (user.role == UserRole.technician && ticket.assignedTo != user.id) {
      throw StateError('Only assigned technician can generate checklist.');
    }

    final steps = <String>[
      'Verify power supply and indicator LEDs (PON/LOS).',
      'Check fiber patch cord condition and connections.',
      'Perform basic signal level test (if available).',
      'Restart ONU/router and confirm internet session.',
      'If unresolved, escalate for line inspection / replacement.',
    ];

    final done = List<bool>.filled(steps.length, false);
    final now = DateTime.now();

    _tickets = _tickets.map((t) {
      if (t.id != ticketId) return t;
      return t.copyWith(
        checklistItems: steps,
        checklistDone: done,
        updatedAt: now,
      );
    }).toList();

    notifyListeners();
  }

  void toggleChecklistItem({
    required String ticketId,
    required int index,
    required bool value,
  }) {
    final ticket = getTicketById(ticketId);
    if (ticket == null) return;
    if (index < 0 || index >= ticket.checklistDone.length) return;

    final updatedDone = List<bool>.from(ticket.checklistDone);
    updatedDone[index] = value;

    _tickets = _tickets.map((t) {
      if (t.id != ticketId) return t;
      return t.copyWith(checklistDone: updatedDone, updatedAt: DateTime.now());
    }).toList();

    notifyListeners();
  }

  // ----------------------------
  // Mock AI - Report
  // ----------------------------
  Report generateReportMock({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final user = _currentUser;
    if (user == null || user.role != UserRole.technician) {
      throw StateError('Technician must be logged in to generate report.');
    }

    final from = dateFrom ?? DateTime.now().subtract(const Duration(days: 7));
    final to = dateTo ?? DateTime.now();

    final techTickets = _tickets.where((t) {
      final inRange = t.createdAt.isAfter(from) && t.createdAt.isBefore(to);
      return t.assignedTo == user.id && inRange;
    }).toList();

    final ticketIds = techTickets.map((t) => t.id).toList();

    final content = _buildReportContent(
      technicianName: user.name,
      from: from,
      to: to,
      tickets: techTickets,
    );

    final report = Report(
      id: 'r_${DateTime.now().millisecondsSinceEpoch}',
      createdBy: user.id,
      ticketIds: ticketIds,
      content: content,
      createdAt: DateTime.now(),
      dateFrom: from,
      dateTo: to,
    );

    _reports.insert(0, report);
    notifyListeners();
    return report;
  }

  String _buildReportContent({
    required String technicianName,
    required DateTime from,
    required DateTime to,
    required List<Ticket> tickets,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Technician: $technicianName');
    buffer.writeln('Period: ${from.toLocal()}  -  ${to.toLocal()}');
    buffer.writeln('');
    buffer.writeln('Summary:');
    buffer.writeln('- Total tickets handled: ${tickets.length}');
    buffer.writeln('');

    for (final t in tickets) {
      buffer.writeln('Ticket: ${t.title}');
      buffer.writeln('Status: ${t.status.displayName}');
      buffer.writeln('Issue: ${t.description}');
      if (t.checklistItems.isNotEmpty) {
        final doneCount = t.checklistDone.where((x) => x).length;
        buffer.writeln('Checklist: $doneCount / ${t.checklistItems.length} steps completed');
      }
      buffer.writeln('---');
    }

    buffer.writeln('');
    buffer.writeln('Note: This is a mock generated report (dummy app).');
    return buffer.toString();
  }
}