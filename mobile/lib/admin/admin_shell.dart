import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_login_screen.dart';
import 'admin_dashboard_view.dart';
import 'centre_monitoring_view.dart';
import 'farmer_booking_search_view.dart';
import 'pacs_monitoring_view.dart';
import 'analytics_procurement_view.dart';
import 'analytics_payment_view.dart';
import 'prediction_monitoring_view.dart';
import 'admin_reports_view.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;

  void _onLoginSuccess() {
    setState(() {
      _currentIndex = 0;
    });
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to exit the Administrator session?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ApiService().logout();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Authentication Gate
    if (!ApiService().isAuthenticated) {
      return AdminLoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    // 2. Authenticated Shell
    final titles = [
      'Admin Dashboard',
      'Centre Monitoring',
      'Search & PACS Oversight',
      'Analytics & AI Engine',
      'Reports & Security Audit',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          AdminDashboardView(onNavigateTab: _navigateToTab),
          const CentreMonitoringView(),
          const _SearchAndPacsView(),
          const _AnalyticsAndMlView(),
          const AdminReportsView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF1B5E20)),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store, color: Color(0xFF1B5E20)),
            label: 'Centres',
          ),
          NavigationDestination(
            icon: Icon(Icons.manage_search_outlined),
            selectedIcon: Icon(Icons.manage_search, color: Color(0xFF1B5E20)),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics, color: Color(0xFF1B5E20)),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.summarize_outlined),
            selectedIcon: Icon(Icons.summarize, color: Color(0xFF1B5E20)),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

// Internal Wrapper for Search & PACS tabs
class _SearchAndPacsView extends StatelessWidget {
  const _SearchAndPacsView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: const [
          TabBar(
            labelColor: Color(0xFF1B5E20),
            indicatorColor: Color(0xFF1B5E20),
            tabs: [
              Tab(icon: Icon(Icons.search, size: 18), text: 'Farmer / Booking Search'),
              Tab(icon: Icon(Icons.storefront, size: 18), text: 'PACS Monitoring'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                FarmerBookingSearchView(),
                PacsMonitoringView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Internal Wrapper for Analytics & ML tabs
class _AnalyticsAndMlView extends StatelessWidget {
  const _AnalyticsAndMlView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          TabBar(
            labelColor: Color(0xFF1B5E20),
            indicatorColor: Color(0xFF1B5E20),
            tabs: [
              Tab(icon: Icon(Icons.grain, size: 18), text: 'Procurement'),
              Tab(icon: Icon(Icons.payments, size: 18), text: 'DBT Payments'),
              Tab(icon: Icon(Icons.auto_graph, size: 18), text: 'AI Model'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                AnalyticsProcurementView(),
                AnalyticsPaymentView(),
                PredictionMonitoringView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
