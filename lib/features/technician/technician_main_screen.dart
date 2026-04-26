// lib/features/technician/technician_main_screen.dart

import 'package:flutter/material.dart';
import 'tech_home_screen.dart';
import 'assigned_ticket_list_screen.dart';
import 'profile_screen.dart';

class TechnicianMainScreen extends StatefulWidget {
  const TechnicianMainScreen({super.key});

  @override
  State<TechnicianMainScreen> createState() => _TechnicianMainScreenState();
}

class _TechnicianMainScreenState extends State<TechnicianMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    TechHomeScreen(),
    AssignedTicketsScreen(),
    TechnicianProfileScreen(),
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
                icon: Icon(Icons.home_outlined, size: 20),
                selectedIcon: Icon(Icons.home_rounded, size: 22),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_outlined, size: 20),
                selectedIcon: Icon(Icons.assignment_rounded, size: 22),
                label: 'Tasks',
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
