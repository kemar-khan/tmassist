import 'package:flutter/material.dart';
import '../../utils/image_picker_helper.dart';
import '../../utils/pending_photo.dart';
import '../../utils/ticket_filter_request.dart';
import '../../widgets/app_bottom_nav.dart';
import 'tech_home_screen.dart';
import 'assigned_ticket_list_screen.dart';
import 'tech_analytics_screen.dart';
import 'profile_screen.dart';

class TechnicianMainScreen extends StatefulWidget {
  const TechnicianMainScreen({super.key});

  @override
  State<TechnicianMainScreen> createState() => _TechnicianMainScreenState();
}

class _TechnicianMainScreenState extends State<TechnicianMainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverPhoto());
  }

  // After Android killed the app during the camera: reopen the report the
  // photo was for. Runs once per app start; any failure is ignored.
  Future<void> _recoverPhoto() async {
    final RecoveredPhoto? photo = await recoverLostPhoto();
    if (!mounted || photo == null) return;
    if (photo.purpose != 'report' || photo.ticketId == null) return;
    Navigator.pushNamed(context, '/tech/report', arguments: photo);
  }

  // Asks the Tasks tab to select a status filter (see TicketFilterRequest).
  TicketFilterRequest? _tasksFilterRequest;

  static const List<AppNavItem> _navItems = [
    AppNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    AppNavItem(
      icon: Icons.assignment_outlined,
      activeIcon: Icons.assignment_rounded,
      label: 'Tasks',
    ),
    AppNavItem(
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
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

  void _openTasksWithStatus(String status) {
    setState(() {
      _tasksFilterRequest = TicketFilterRequest(
        status: status,
        id: (_tasksFilterRequest?.id ?? 0) + 1,
      );
      _selectedIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The bar floats over the body (extendBody); every tab pads its own
    // content for it.
    final screens = <Widget>[
      TechHomeScreen(
        onOpenTasksWithStatus: _openTasksWithStatus,
        onOpenProfile: () => _onItemTapped(3),
      ),
      AssignedTicketsScreen(filterRequest: _tasksFilterRequest),
      const TechAnalyticsScreen(),
      const TechnicianProfileScreen(),
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
