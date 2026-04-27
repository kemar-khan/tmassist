// lib/data/dummy_data.dart

import '../models/user.dart';
import '../models/ticket.dart';
import '../utils/enums.dart';

class DummyData {
  static final List<AppUser> users = [
    const AppUser(id: 'u_admin_1', name: 'Admin Aisyah', role: UserRole.admin),
    const AppUser(
      id: 'u_tech_1',
      name: 'Tech Danish',
      role: UserRole.technician,
    ),
    const AppUser(
      id: 'u_tech_2',
      name: 'Tech Haziq',
      role: UserRole.technician,
    ),
  ];

  static List<Ticket> initialTickets() {
    final now = DateTime.now();

    return [
      Ticket(
        id: 't_1001',
        title: 'No Internet - ONU Red Light',
        description: 'Customer reports no internet. ONU blinking red (LOS).',
        status: TicketStatus.newTicket,
        createdBy: 'u_admin_1',
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
      Ticket(
        id: 't_1002',
        title: 'Slow Speed - Evening',
        description:
            'Customer reports speed drops at night. Need check signal level.',
        status: TicketStatus.assigned,
        createdBy: 'u_admin_1',
        assignedTo: 'u_tech_1',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        updatedAt: now.subtract(const Duration(days: 1, hours: 1)),
      ),
    ];
  }
}
