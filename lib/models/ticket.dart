// lib/models/ticket.dart

import '../utils/enums.dart';

class Ticket {
  final String id;
  final String title;
  final String description;

  /// Ticket lifecycle status (New → Assigned → In Progress → Resolved → Closed)
  final TicketStatus status;

  /// Admin who created the ticket
  final String createdBy;

  /// Technician assigned to the ticket (nullable until assigned)
  final String? assignedTo;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional: store AI checklist in the ticket for dummy prototype (simple approach)
  final List<String> checklistItems;

  /// Optional: completion tracking aligned with checklistItems length
  final List<bool> checklistDone;

  const Ticket({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.assignedTo,
    this.checklistItems = const [],
    this.checklistDone = const [],
  });

  Ticket copyWith({
    String? id,
    String? title,
    String? description,
    TicketStatus? status,
    String? createdBy,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? checklistItems,
    List<bool>? checklistDone,
    bool clearAssignedTo = false,
  }) {
    return Ticket(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checklistItems: checklistItems ?? this.checklistItems,
      checklistDone: checklistDone ?? this.checklistDone,
    );
  }

  @override
  String toString() =>
      'Ticket(id: $id, title: $title, status: ${status.name}, assignedTo: $assignedTo)';
}