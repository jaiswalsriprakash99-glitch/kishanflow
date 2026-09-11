import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'staff_service.dart';
import 'staff_auth_screen.dart';
import 'staff_dashboard_screen.dart';
import 'today_schedule_screen.dart';
import 'staff_live_queue_screen.dart';
import 'daily_summary_screen.dart';

class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _handleLogout() {
    StaffService().logout();
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final staff = StaffService();

    // If staff is not authenticated, show StaffAuthScreen
    if (!staff.isAuthenticated) {
      return StaffAuthScreen(
        onLoginSuccess: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      );
    }

    final pages = [
      StaffDashboardScreen(
        onNavigateToSchedule: () => _onItemTapped(1),
        onNavigateToQueue: () => _onItemTapped(2),
      ),
      const TodayScheduleScreen(),
      const StaffLiveQueueScreen(),
      const DailySummaryScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.staffRole} Terminal', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              '${staff.fullName ?? "Operator"} (${staff.role ?? "STAFF"})',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout Staff',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF1B5E20),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarStateItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarStateItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          BottomNavigationBarStateItem(
            icon: Icon(Icons.queue_outlined),
            activeIcon: Icon(Icons.queue),
            label: 'Live Queue',
          ),
          BottomNavigationBarStateItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Summary',
          ),
        ],
      ),
    );
  }
}

class BottomNavigationBarStateItem extends BottomNavigationBarItem {
  const BottomNavigationBarStateItem({
    required Widget icon,
    required Widget activeIcon,
    required String label,
  }) : super(
          icon: icon,
          activeIcon: activeIcon,
          label: label,
        );
}
