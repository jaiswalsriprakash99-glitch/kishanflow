import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'pacs_service.dart';
import 'pacs_auth_screen.dart';
import 'pacs_dashboard_screen.dart';
import 'pacs_collection_screen.dart';
import 'pacs_dispatch_screen.dart';
import 'pacs_status_screen.dart';

class PacsShell extends StatefulWidget {
  const PacsShell({super.key});

  @override
  State<PacsShell> createState() => _PacsShellState();
}

class _PacsShellState extends State<PacsShell> {
  int _currentIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _handleLogout() {
    PacsService().logout();
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pacs = PacsService();

    // Guard: If PACS Operator is not authenticated, render auth screen
    if (!pacs.isAuthenticated) {
      return PacsAuthScreen(
        onLoginSuccess: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      );
    }

    final pages = [
      PacsDashboardScreen(
        onNavigateToCollection: () => _onItemTapped(1),
        onNavigateToForwarding: () => _onItemTapped(2),
        onNavigateToPayments: () => _onItemTapped(3),
      ),
      const PacsCollectionScreen(),
      const PacsDispatchScreen(),
      const PacsStatusScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.pacsRole} Hub', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              '${pacs.pacsName ?? "PACS"} | ${pacs.fullName ?? "Operator"}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout PACS Operator',
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
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_shopping_cart_outlined),
            activeIcon: Icon(Icons.add_shopping_cart),
            label: 'Collection',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Forwarding',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payments_outlined),
            activeIcon: Icon(Icons.payments),
            label: 'Status',
          ),
        ],
      ),
    );
  }
}
