// lib/features/supervisor/supervisor_main_screen.dart

import 'package:flutter/material.dart';
import '../../utils/ticket_filter_request.dart';
import '../../widgets/app_bottom_nav.dart';
import 'supervisor_home_screen.dart';
import 'incoming_tickets_screen.dart';
import 'profile_screen.dart';
import 'technician_performance_screen.dart';

class SupervisorMainScreen extends StatefulWidget {
  const SupervisorMainScreen({super.key});

  @override
  State<SupervisorMainScreen> createState() => _SupervisorMainScreenState();
}

class _SupervisorMainScreenState extends State<SupervisorMainScreen> {
  int _selectedIndex = 0;

  // Asks the Tickets tab to select a status filter (see TicketFilterRequest).
  TicketFilterRequest? _ticketsFilterRequest;

  void _openTicketsWithStatus(String status) {
    setState(() {
      _ticketsFilterRequest = TicketFilterRequest(
        status: status,
        id: (_ticketsFilterRequest?.id ?? 0) + 1,
      );
      _selectedIndex = 1;
    });
  }

  static const List<AppNavItem> _navItems = [
    AppNavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    AppNavItem(
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number_rounded,
      label: 'Tickets',
    ),
    AppNavItem(
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics_rounded,
      label: 'Analytics',
    ),
    AppNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The bar floats over the body (extendBody); every tab pads its own
    // content for it.
    // "View All" on the home screen jumps to the Tickets tab (index 1).
    final screens = <Widget>[
      SupervisorHomeScreen(
        onViewAllTickets: () => _onItemTapped(1),
        onOpenTicketsWithStatus: _openTicketsWithStatus,
      ),
      IncomingTicketsScreen(filterRequest: _ticketsFilterRequest),
      const TechnicianPerformanceScreen(),
      const SupervisorProfileScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: AppBottomNav(
        items: _navItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
