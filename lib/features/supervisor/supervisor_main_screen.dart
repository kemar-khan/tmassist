// lib/features/supervisor/supervisor_main_screen.dart

import 'package:flutter/material.dart';
import 'supervisor_home_screen.dart';
import 'incoming_tickets_screen.dart';
import 'profile_screen.dart';

class SupervisorMainScreen extends StatefulWidget {
  const SupervisorMainScreen({super.key});

  @override
  State<SupervisorMainScreen> createState() => _SupervisorMainScreenState();
}

class _SupervisorMainScreenState extends State<SupervisorMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    AdminHomeScreen(), // Supervisor Home
    IncomingTicketsScreen(),
    SupervisorProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: NavigationBar(
            height: 56,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFF005CAB).withOpacity(0.10),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, size: 20),
                selectedIcon: Icon(Icons.dashboard_rounded, size: 22),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.confirmation_number_outlined, size: 20),
                selectedIcon: Icon(Icons.confirmation_number_rounded, size: 22),
                label: 'Tickets',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, size: 20),
                selectedIcon: Icon(Icons.person_rounded, size: 22),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
