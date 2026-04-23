// lib/router.dart

import 'package:flutter/material.dart';

import 'features/auth/login_screen.dart';
import 'features/admin/admin_home_screen.dart';
import 'features/admin/create_ticket_screen.dart';
import 'features/admin/assign_ticket_screen.dart';
import 'features/technician/tech_home_screen.dart';
import 'features/technician/ticket_detail_screen.dart';
import 'features/technician/checklist_screen.dart';
import 'features/technician/report_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name;

    switch (name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      // Admin
      case '/admin':
        return MaterialPageRoute(builder: (_) => const AdminHomeScreen());
      case '/admin/create':
        return MaterialPageRoute(builder: (_) => const CreateTicketScreen());
      case '/admin/assign':
        // args: ticketId (String)
        final ticketId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => AssignTicketScreen(ticketId: ticketId),
        );

      // Technician
      case '/tech':
        return MaterialPageRoute(builder: (_) => const TechHomeScreen());
      case '/tech/ticket':
        final ticketId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: ticketId),
        );
      case '/tech/checklist':
        final ticketId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => ChecklistScreen(ticketId: ticketId),
        );
      case '/tech/report':
        return MaterialPageRoute(builder: (_) => const ReportScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}