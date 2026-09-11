// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'किसानफ़्लो';

  @override
  String get welcome => 'किसानफ़्लो में आपका स्वागत है';

  @override
  String get splashSubtitle => 'स्मार्ट कृषि कतार प्रबंधन और खरीद प्रणाली';

  @override
  String get selectRole => 'अपनी भूमिका चुनें';

  @override
  String get farmerRole => 'किसान';

  @override
  String get staffRole => 'खरीद केंद्र स्टाफ';

  @override
  String get pacsRole => 'पैक्स (PACS) ऑपरेटर';

  @override
  String get adminRole => 'प्रशासक (एडमिन)';

  @override
  String get changeLanguage => 'भाषा';

  @override
  String get loading => 'लोड हो रहा है...';

  @override
  String get error => 'एक त्रुटि हुई';

  @override
  String get retry => 'पुनः प्रयास करें';

  @override
  String get offlineMode => 'ऑफ़लाइन मोड (कैश किया गया)';

  @override
  String get simulatedBadge => 'डेमो / सिमुलेटेड';
}
