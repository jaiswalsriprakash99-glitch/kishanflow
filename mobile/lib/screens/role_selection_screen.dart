import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../farmer/farmer_shell.dart';
import '../staff/staff_shell.dart';
import '../pacs/pacs_shell.dart';
import '../admin/admin_shell.dart';

class RoleSelectionScreen extends StatelessWidget {
  final Function(Locale) onLanguageChanged;
  final Locale currentLocale;

  const RoleSelectionScreen({
    super.key,
    required this.onLanguageChanged,
    required this.currentLocale,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectRole),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (langCode) {
              onLanguageChanged(Locale(langCode));
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'en', child: Text('English')),
              const PopupMenuItem(value: 'hi', child: Text('हिन्दी (Hindi)')),
              const PopupMenuItem(value: 'kn', child: Text('ಕನ್ನಡ (Kannada)')),
              const PopupMenuItem(value: 'mr', child: Text('मराठी (Marathi)')),
              const PopupMenuItem(value: 'te', child: Text('తెలుగు (Telugu)')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.welcome,
              key: const Key('welcomeText'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.selectRole,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _RoleCard(
              icon: Icons.agriculture,
              title: l10n.farmerRole,
              subtitle: 'Book slots, track queue status & crop details',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const FarmerShell()),
                );
              },
            ),
            const SizedBox(height: 16),
            _RoleCard(
              icon: Icons.badge_outlined,
              title: l10n.staffRole,
              subtitle: 'Operate queue counters, verification & weighing',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const StaffShell()),
                );
              },
            ),
            const SizedBox(height: 16),
            _RoleCard(
              icon: Icons.storefront_outlined,
              title: l10n.pacsRole,
              subtitle: 'Manage PACS collection & forwarding workflow',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const PacsShell()),
                );
              },
            ),
            const SizedBox(height: 16),
            _RoleCard(
              icon: Icons.analytics_outlined,
              title: l10n.adminRole,
              subtitle: 'Analytics dashboard & centre management',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AdminShell()),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE8F5E9),
          child: Icon(icon, color: const Color(0xFF1B5E20)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
