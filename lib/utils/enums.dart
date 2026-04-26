/// Defines the different roles in the system
enum UserRole {
  admin,
  technician,
  customer,
}

/// Defines the lifecycle of a service ticket
enum TicketStatus {
  newTicket,
  assigned,
  inProgress,
  resolved,
  closed,
}

/// Extension to convert UserRole to readable string
extension UserRoleExtension on UserRole {
  String get displayName { 
    switch (this) {
      case UserRole.admin:
        return "Admin";
      case UserRole.technician:
        return "Technician";
      case UserRole.customer:
        return "Customer";
    }
  }
}

/// Extension to convert TicketStatus to readable string
extension TicketStatusExtension on TicketStatus {
  String get displayName {
    switch (this) {
      case TicketStatus.newTicket:
        return "New";
      case TicketStatus.assigned:
        return "Assigned";
      case TicketStatus.inProgress:
        return "In Progress";
      case TicketStatus.resolved:
        return "Resolved";
      case TicketStatus.closed:
        return "Closed";
    }
  }

  /// Optional: useful later for color-coded UI badges
  bool get isFinal {
    return this == TicketStatus.closed;
  }
}