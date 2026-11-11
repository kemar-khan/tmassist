// lib/features/customer/customer_main_screen.dart

import 'package:flutter/material.dart';

import '../../utils/image_picker_helper.dart';
import '../../utils/pending_photo.dart';

import '../../widgets/app_bottom_nav.dart';
import 'customer_home_screen.dart';
import 'my_tickets_screen.dart';
import 'profile_screen.dart';

class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPhoto());
  }

  // After Android killed the app during the camera: reopen Submit Ticket with
  // the photo attached. Runs once per app start; any failure is ignored.
  Future<void> _recoverPhoto() async {
    final RecoveredPhoto? photo = await recoverLostPhoto();
    if (!mounted || photo == null || photo.purpose != 'ticket') return;
    Navigator.pushNamed(context, '/customer/submit', arguments: photo);
  }

  static const List<AppNavItem> _navItems = [
    AppNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    AppNavItem(
      icon: Icons.confirmation_number_outlined,
      activeIcon: Icons.confirmation_number_rounded,
      label: 'Tickets',
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
    // The bar floats over the body (extendBody); each tab pads its own
    // content for it.
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const CustomerHomeScreen(),
          const MyTicketsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: _navItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
