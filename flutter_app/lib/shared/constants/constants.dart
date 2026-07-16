// ─── App-wide Constants for Crew Intelligence Platform ───────────────────────

class AppConstants {
  AppConstants._();

  // ── App Metadata ────────────────────────────────────────────────────────────
  static const String appName = 'Najm';
  static const String appNameEn = 'Crew Intelligence Platform';

  // NOTE: do not read the app version from here — it drifts. The Profile
  // screen uses package_info_plus (packageInfoProvider), which reports the
  // REAL version and build number from the built artifact.
  static const String appVersion = '1.0.0';

  // These pointed at https://cip.app/… — a domain that does not exist. Nothing
  // consumed them (verified), so no live link was broken, but leaving a dead
  // domain lying around invites someone to wire it up one day. The real
  // documents ship in assets/legal/ and render offline, in-app.
  static const String supportEmail = 'NajmAssistance@gmail.com';
  static const String administratorEmail = 'NajmPlatform@gmail.com';
  static const String privacyPolicyRoute = '/legal/privacy';
  static const String termsRoute = '/legal/terms';

  // ── Saudi Airlines Bases ───────────────────────────────────────────────────
  static const List<String> saudiAirlinesBases = ['RUH', 'JED', 'DMM'];
  static const String defaultBase = 'RUH';

  // ── Domestic Saudi IATA codes ──────────────────────────────────────────────
  static const Set<String> domesticIata = {
    'RUH', 'JED', 'DMM', 'MED', 'AHB', 'TIF', 'GIZ',
    'ELQ', 'URY', 'TUU', 'AQI', 'HOF', 'EAM', 'RAE',
    'SHW', 'WAE', 'DWD', 'ULH', 'YNB', 'NBE',
  };

  // ── Common International Destinations ─────────────────────────────────────
  static const Map<String, String> popularDestinations = {
    'LHR': 'London Heathrow',
    'CDG': 'Paris Charles de Gaulle',
    'FRA': 'Frankfurt',
    'AMS': 'Amsterdam',
    'DXB': 'Dubai',
    'DOH': 'Doha',
    'IST': 'Istanbul',
    'CAI': 'Cairo',
    'BKK': 'Bangkok',
    'SIN': 'Singapore',
    'KUL': 'Kuala Lumpur',
    'NRT': 'Tokyo Narita',
    'LAX': 'Los Angeles',
    'JFK': 'New York JFK',
    'ZRH': 'Zurich',
    'GVA': 'Geneva',
    'FCO': 'Rome',
    'MAD': 'Madrid',
    'MXP': 'Milan',
    'MAN': 'Manchester',
  };

  // ── GACA FTL Rule Defaults — ⚠️ DISPLAY-ONLY ────────────────────────────────
  // These mirror the server's canonical defaults (python_services/legality/
  // rules_source.py, GACA-GOM-7.5.3-TF) for UI hints ONLY. They are NOT used
  // for any legality verdict: all legality checks are computed server-side,
  // where admin overrides from the Firestore `legalityRules` collection apply.
  // Live effective values: GET /v1/legality/rules. Do NOT branch app logic on
  // these constants — they can silently drift from the admin-configured rules.
  static const double minRestDomesticHours = 14.0;       // from release time
  static const double minRestInternationalHours = 15.0;  // from release time
  static const double maxFdpBaseHours = 13.0;
  static const double maxFdpExtendedHours = 14.0;
  static const double maxDailyBlockHours = 8.0;
  static const double maxWeeklyFlightHours = 60.0;
  static const double maxMonthlyDutyHours = 120.0;
  static const double maxMonthlyBlockHours = 100.0;
  static const double annualMaxFlightHours = 900.0;
  static const int minDaysOffPer7Days = 1;
  static const double releaseTimeBufferMinutes = 30.0;

  // ── Salary Defaults (SAR) ──────────────────────────────────────────────────
  static const double defaultHourlyRate = 50.0;
  static const double internationalPerDiem = 150.0;
  static const double domesticPerDiem = 50.0;
  static const double overtimeMultiplier = 1.5;
  static const double overtimeThresholdHours = 85.0;  // monthly block hours

  // ── Subscription Pricing (SAR) ────────────────────────────────────────────
  static const double proMonthlyPrice = 39.0;
  static const double proYearlyPrice = 349.0;
  static const double eliteMonthlyPrice = 79.0;
  static const double eliteYearlyPrice = 699.0;
  static const double enterpriseMonthlyPrice = 249.0;
  static const int proTrialDays = 30;
  static const int freeBidsPerMonth = 3;

  // ── AI / NLP ───────────────────────────────────────────────────────────────
  static const int freeAiQueriesPerDay = 5;
  static const int maxAssistantHistoryMessages = 10;
  static const int maxAssistantMessageLength = 500;
  static const int aiResponseTimeoutSeconds = 30;

  // ── Trade Settings ─────────────────────────────────────────────────────────
  static const int tradeExpiryHours = 72;
  static const int maxOpenTradesPerUser = 5;

  // ── UI ─────────────────────────────────────────────────────────────────────
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 12.0;
  static const double pageHorizontalPadding = 16.0;
  static const double cardElevation = 0.0;
  static const Duration animationDuration = Duration(milliseconds: 200);
  static const Duration snackBarDuration = Duration(seconds: 3);

  // ── Caching ────────────────────────────────────────────────────────────────
  static const String hiveBoxSettings = 'settings';
  static const String hiveBoxLines = 'flightLines';
  static const String hiveBoxBids = 'bids';
  static const String hiveBoxPreferences = 'userPreferences';
  static const String hiveBoxAiSessions = 'aiSessions';
  static const Duration cacheExpiry = Duration(hours: 6);

  // ── Regex Patterns ─────────────────────────────────────────────────────────
  static final RegExp iataCodeRegex = RegExp(r'^[A-Z]{3}$');
  static final RegExp flightNumberRegex = RegExp(r'^[A-Z]{2}\d{1,4}[A-Z]?$');
  static final RegExp crewIdRegex = RegExp(r'^\d{5,8}$');

  // ── Weekday Labels (KSA: Sun=0) ───────────────────────────────────────────
  
  static const List<String> weekdaysEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // ── Rank Labels ────────────────────────────────────────────────────────────
  static const Map<String, String> rankLabels = {
    'GD':  'Guest Director',
    'PCA': 'Premium Cabin Crew',
    'BUT': 'Butler',
    'CHF': 'Chef',
    'SNF': 'Senior Cabin Attendant',
    'YCA': 'Economy Cabin Attendant',
    'CA':  'Captain',
    'FO':  'First Officer',
  };

  // ── Disclaimer (shown on onboarding and in settings) ──────────────────────
  static const String disclaimer = '''
Crew Intelligence Platform (Najm) is an UNOFFICIAL, independent tool 
created to assist Saudi Airlines cabin crew with monthly scheduling decisions.

THIS APP IS NOT affiliated with, endorsed by, or connected to Saudi Arabian 
Airlines Corporation (Saudia) or any of its internal systems.

All flight schedule data is user-supplied via Excel upload. The platform does 
not access, transmit, or store any data from Saudi Airlines' internal systems.

LEGALITY CHECKS are based on publicly available GACA/ICAO regulations and 
standard industry rules. Always verify compliance through official channels.

Use of this app is at your own risk. CIP provides no warranty of accuracy.
''';
}

// ─── Environment Configuration ────────────────────────────────────────────────
class AppConfig {
  AppConfig._();

  static const String aiServiceUrl = String.fromEnvironment(
    'AI_SERVICE_URL',
    defaultValue: 'https://cip-ai-xxxx.run.app',
  );

  static const bool isProduction = bool.fromEnvironment(
    'IS_PRODUCTION',
    defaultValue: false,
  );

  static const String environment = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );
}
