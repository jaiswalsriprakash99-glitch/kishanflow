import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'farmer_profile_screen.dart';
import 'farmer_crop_screen.dart';
import 'centre_discovery_screen.dart';
import 'slot_booking_screen.dart';
import 'live_queue_screen.dart';
import 'procurement_timeline_screen.dart';
import 'payment_status_screen.dart';
import 'voice_assistant_widget.dart';

class FarmerShell extends StatefulWidget {
  const FarmerShell({super.key});

  @override
  State<FarmerShell> createState() => _FarmerShellState();
}

class _FarmerShellState extends State<FarmerShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    _FarmerDashboardHome(),
    CentreDiscoveryScreen(),
    LiveQueueScreen(),
    ProcurementTimelineScreen(
      bookingRef: 'BK-MND-20260912-0042',
      currentStatus: 'VERIFICATION',
    ),
    PaymentStatusScreen(bookingRef: 'BK-MND-20260912-0042'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (idx) => setState(() => _selectedIndex = idx),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1B5E20),
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarViewItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarViewItem(icon: Icon(Icons.storefront_outlined), activeIcon: Icon(Icons.storefront), label: 'Discovery'),
          BottomNavigationBarViewItem(icon: Icon(Icons.confirmation_number_outlined), activeIcon: Icon(Icons.confirmation_number), label: 'Live Queue'),
          BottomNavigationBarViewItem(icon: Icon(Icons.timeline_outlined), activeIcon: Icon(Icons.timeline), label: 'Timeline'),
          BottomNavigationBarViewItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Payments'),
        ],
      ),
    );
  }
}

// Temporary compatibility typedef for bottom bar items
class BottomNavigationBarViewItem extends BottomNavigationBarItem {
  const BottomNavigationBarViewItem({
    required super.icon,
    super.activeIcon,
    required String label,
  }) : super(label: label);
}

class _FarmerDashboardHome extends StatelessWidget {
  const _FarmerDashboardHome();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.farmerRole} Executive Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const FarmerProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Card(
              elevation: 2,
              color: const Color(0xFF1B5E20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ramesh Gowda',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Mandya, KA', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Linked Crop: Paddy (Grade-A) | 45.0 Quintals',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Active Live Queue Card Banner
            Card(
              elevation: 2,
              color: Colors.green.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: const Color(0xFF1B5E20).withOpacity(0.4)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.confirmation_number, color: Color(0xFF1B5E20)),
                            SizedBox(width: 8),
                            Text('Queue Ticket #7', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('ARRIVED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('AI Predicted Wait: 25.0 min', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueAccent)),
                        Text('Rec. Arrival: 09:15 AM', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.amber)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        minimumSize: const Size.fromHeight(40),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const LiveQueueScreen()),
                        );
                      },
                      child: const Text('View Live Queue & AI Arrival Guidance', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Farmer Actions & Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Grid of Farmer Actions
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionCard(
                  icon: Icons.search,
                  title: 'Centre Discovery',
                  subtitle: 'Rank mandis by distance & queue',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CentreDiscoveryScreen()),
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.calendar_month,
                  title: 'Slot Booking',
                  subtitle: 'Book slot & get queue ticket',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SlotBookingScreen(centreId: 1, centreName: 'Mandya Main Mandi'),
                      ),
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.grass,
                  title: 'Register Crops',
                  subtitle: 'Add produce & acreage',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const FarmerCropScreen()),
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.person_outline,
                  title: 'Farmer Profile',
                  subtitle: 'Update land & bank details',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const FarmerProfileScreen()),
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.timeline,
                  title: 'Procurement Timeline',
                  subtitle: 'Track 9-stage progress',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ProcurementTimelineScreen(
                          bookingRef: 'BK-MND-20260912-0042',
                          currentStatus: 'VERIFICATION',
                        ),
                      ),
                    );
                  },
                ),
                _ActionCard(
                  icon: Icons.account_balance_wallet,
                  title: 'DBT Payment Status',
                  subtitle: 'Check direct bank transfer',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PaymentStatusScreen(bookingRef: 'BK-MND-20260912-0042'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Voice Assistant Widget Card
            const VoiceAssistantWidget(),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE8F5E9),
                child: Icon(icon, color: const Color(0xFF1B5E20)),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
