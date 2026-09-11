// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'KisanFlow';

  @override
  String get welcome => 'Welcome to KisanFlow';

  @override
  String get splashSubtitle =>
      'Smart Agriculture Queue Management & Procurement';

  @override
  String get selectRole => 'Select Your Role';

  @override
  String get farmerRole => 'Farmer';

  @override
  String get staffRole => 'Procurement Centre Staff';

  @override
  String get pacsRole => 'PACS Operator';

  @override
  String get adminRole => 'Administrator';

  @override
  String get changeLanguage => 'Language';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'An error occurred';

  @override
  String get retry => 'Retry';

  @override
  String get offlineMode => 'Offline Mode (Cached)';

  @override
  String get simulatedBadge => 'Demo / Simulated';
}
