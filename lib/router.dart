// lib/router.dart

import 'package:flutter/material.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/register_customer_screen.dart';
import 'features/supervisor/supervisor_home_screen.dart';
import 'features/supervisor/create_ticket_screen.dart';
import 'features/supervisor/assign_ticket_screen.dart';
import 'features/supervisor/ticket_detail_screen.dart';
import 'features/supervisor/supervisor_main_screen.dart';
import 'features/technician/tech_home_screen.dart';
import 'features/technician/technician_main_screen.dart';
import 'features/technician/ticket_detail_screen.dart';
import 'features/technician/checklist_screen.dart';
import 'features/technician/report_screen.dart';
import 'features/customer/customer_main_screen.dart';
import 'features/customer/my_tickets_screen.dart';
import 'features/customer/submit_ticket_screen.dart';
import 'features/customer/profile_screen.dart';
import 'features/customer/ticket_details_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name;

    switch (name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/register':
        return MaterialPageRoute(builder: (_) => const RegisterCustomerScreen());

      // Admin
      case '/admin':
        return MaterialPageRoute(builder: (_) => const SupervisorMainScreen());
      case '/admin/create':
        return MaterialPageRoute(builder: (_) => const CreateTicketScreen());
      case '/admin/assign':
        final args = settings.arguments;

        if (args == null || args is! String) {
          return MaterialPageRoute(
            builder: (_) =>
                const Scaffold(body: Center(child: Text('Invalid ticket ID'))),
          );
        }

        return MaterialPageRoute(
          builder: (_) => AssignTicketScreen(ticketId: args),
        );
      case '/admin/ticket':
        final ticketId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => SupervisorTicketDetailScreen(ticketId: ticketId),
        );

      // Technician
      case '/tech':
        return MaterialPageRoute(builder: (_) => const TechnicianMainScreen());
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

      // Customer
      case '/customer':
        return MaterialPageRoute(builder: (_) => const CustomerMainScreen());
      case '/customer/tickets':
        return MaterialPageRoute(builder: (_) => const MyTicketsScreen());
      case '/customer/submit':
        return MaterialPageRoute(builder: (_) => const SubmitTicketScreen());
      case '/customer/profile':
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case '/customer/ticket_details':
        final ticketId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => TicketDetailsScreen(ticketId: ticketId),
        );

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}
