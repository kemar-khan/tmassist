// lib/models/report.dart

class Report {
  final String id;

  /// User (technician) who generated this report
  final String createdBy;

  /// Tickets included in the report
  final List<String> ticketIds;

  /// Report content (editable)
  final String content;

  final DateTime createdAt;

  /// Optional date range for the report
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const Report({
    required this.id,
    required this.createdBy,
    required this.ticketIds,
    required this.content,
    required this.createdAt,
    this.dateFrom,
    this.dateTo,
  });

  Report copyWith({
    String? id,
    String? createdBy,
    List<String>? ticketIds,
    String? content,
    DateTime? createdAt,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    return Report(
      id: id ?? this.id,
      createdBy: createdBy ?? this.createdBy,
      ticketIds: ticketIds ?? this.ticketIds,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
    );
  }

  @override
  String toString() => 'Report(id: $id, createdBy: $createdBy, tickets: ${ticketIds.length})';
}