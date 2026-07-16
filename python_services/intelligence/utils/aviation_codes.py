"""Aviation codes, IATA→timezone mapping, country lookups."""

# IATA → (city, country, timezone, UTC offset hours)
AIRPORT_DATA: dict[str, dict] = {
    # Saudi Arabia
    "RUH": {"city": "Riyadh",       "country": "SA", "tz": "Asia/Riyadh",     "utc": 3},
    "JED": {"city": "Jeddah",       "country": "SA", "tz": "Asia/Riyadh",     "utc": 3},
    "DMM": {"city": "Dammam",       "country": "SA", "tz": "Asia/Riyadh",     "utc": 3},
    "MED": {"city": "Medina",       "country": "SA", "tz": "Asia/Riyadh",     "utc": 3},
    "TUU": {"city": "Tabuk",        "country": "SA", "tz": "Asia/Riyadh",     "utc": 3},
    "AHB": {"city": "Abha",         "country": "SA", "tz": "Asia/Riyadh",     "utc": 3},
    "GIZ": {"city": "Jizan",        "country": "SA", "tz": "Asia/Riyadh",     "utc": 3},
    "HOF": {"city": "Al-Ahsa",      "country": "SA", "tz": "Asia/Riyadh",     "utc": 3},
    "YNB": {"city": "Yanbu",        "country": "SA", "tz": "Asia/Riyadh",     "utc": 3},

    # UAE
    "DXB": {"city": "Dubai",        "country": "AE", "tz": "Asia/Dubai",      "utc": 4},
    "AUH": {"city": "Abu Dhabi",    "country": "AE", "tz": "Asia/Dubai",      "utc": 4},
    "SHJ": {"city": "Sharjah",      "country": "AE", "tz": "Asia/Dubai",      "utc": 4},

    # GCC
    "DOH": {"city": "Doha",         "country": "QA", "tz": "Asia/Qatar",      "utc": 3},
    "KWI": {"city": "Kuwait City",  "country": "KW", "tz": "Asia/Kuwait",     "utc": 3},
    "BAH": {"city": "Manama",       "country": "BH", "tz": "Asia/Bahrain",    "utc": 3},
    "MCT": {"city": "Muscat",       "country": "OM", "tz": "Asia/Muscat",     "utc": 4},

    # Middle East
    "AMM": {"city": "Amman",        "country": "JO", "tz": "Asia/Amman",      "utc": 2},
    "BEY": {"city": "Beirut",       "country": "LB", "tz": "Asia/Beirut",     "utc": 2},
    "CAI": {"city": "Cairo",        "country": "EG", "tz": "Africa/Cairo",    "utc": 2},
    "IST": {"city": "Istanbul",     "country": "TR", "tz": "Europe/Istanbul", "utc": 3},
    "TLV": {"city": "Tel Aviv",     "country": "IL", "tz": "Asia/Jerusalem",  "utc": 2},

    # Asia
    "KUL": {"city": "Kuala Lumpur", "country": "MY", "tz": "Asia/Kuala_Lumpur","utc": 8},
    "SIN": {"city": "Singapore",    "country": "SG", "tz": "Asia/Singapore",  "utc": 8},
    "BKK": {"city": "Bangkok",      "country": "TH", "tz": "Asia/Bangkok",    "utc": 7},
    "DEL": {"city": "New Delhi",    "country": "IN", "tz": "Asia/Kolkata",    "utc": 5.5},
    "BOM": {"city": "Mumbai",       "country": "IN", "tz": "Asia/Kolkata",    "utc": 5.5},
    "KHI": {"city": "Karachi",      "country": "PK", "tz": "Asia/Karachi",    "utc": 5},
    "MNL": {"city": "Manila",       "country": "PH", "tz": "Asia/Manila",     "utc": 8},
    "CGK": {"city": "Jakarta",      "country": "ID", "tz": "Asia/Jakarta",    "utc": 7},
    "NRT": {"city": "Tokyo",        "country": "JP", "tz": "Asia/Tokyo",      "utc": 9},
    "ICN": {"city": "Seoul",        "country": "KR", "tz": "Asia/Seoul",      "utc": 9},
    "PEK": {"city": "Beijing",      "country": "CN", "tz": "Asia/Shanghai",   "utc": 8},
    "PVG": {"city": "Shanghai",     "country": "CN", "tz": "Asia/Shanghai",   "utc": 8},
    "HKG": {"city": "Hong Kong",    "country": "HK", "tz": "Asia/Hong_Kong",  "utc": 8},

    # Europe
    "LHR": {"city": "London",       "country": "GB", "tz": "Europe/London",   "utc": 0},
    "LGW": {"city": "London Gatwick","country":"GB", "tz": "Europe/London",   "utc": 0},
    "CDG": {"city": "Paris",        "country": "FR", "tz": "Europe/Paris",    "utc": 1},
    "FRA": {"city": "Frankfurt",    "country": "DE", "tz": "Europe/Berlin",   "utc": 1},
    "MUC": {"city": "Munich",       "country": "DE", "tz": "Europe/Berlin",   "utc": 1},
    "AMS": {"city": "Amsterdam",    "country": "NL", "tz": "Europe/Amsterdam","utc": 1},
    "MXP": {"city": "Milan",        "country": "IT", "tz": "Europe/Rome",     "utc": 1},
    "FCO": {"city": "Rome",         "country": "IT", "tz": "Europe/Rome",     "utc": 1},
    "MAD": {"city": "Madrid",       "country": "ES", "tz": "Europe/Madrid",   "utc": 1},
    "BCN": {"city": "Barcelona",    "country": "ES", "tz": "Europe/Madrid",   "utc": 1},
    "ZRH": {"city": "Zurich",       "country": "CH", "tz": "Europe/Zurich",   "utc": 1},
    "VIE": {"city": "Vienna",       "country": "AT", "tz": "Europe/Vienna",   "utc": 1},
    "ATH": {"city": "Athens",       "country": "GR", "tz": "Europe/Athens",   "utc": 2},
    "CPH": {"city": "Copenhagen",   "country": "DK", "tz": "Europe/Copenhagen","utc":1},
    "SVO": {"city": "Moscow",       "country": "RU", "tz": "Europe/Moscow",   "utc": 3},

    # Africa
    "ADD": {"city": "Addis Ababa",  "country": "ET", "tz": "Africa/Addis_Ababa","utc":3},
    "NBO": {"city": "Nairobi",      "country": "KE", "tz": "Africa/Nairobi",  "utc": 3},
    "JNB": {"city": "Johannesburg", "country": "ZA", "tz": "Africa/Johannesburg","utc":2},
    "CMN": {"city": "Casablanca",   "country": "MA", "tz": "Africa/Casablanca","utc": 1},
    "TUN": {"city": "Tunis",        "country": "TN", "tz": "Africa/Tunis",    "utc": 1},
    "ALG": {"city": "Algiers",      "country": "DZ", "tz": "Africa/Algiers",  "utc": 1},
    "KRT": {"city": "Khartoum",     "country": "SD", "tz": "Africa/Khartoum", "utc": 3},

    # Americas
    "JFK": {"city": "New York",     "country": "US", "tz": "America/New_York","utc": -5},
    "EWR": {"city": "Newark",       "country": "US", "tz": "America/New_York","utc": -5},
    "LAX": {"city": "Los Angeles",  "country": "US", "tz": "America/Los_Angeles","utc":-8},
    "ORD": {"city": "Chicago",      "country": "US", "tz": "America/Chicago", "utc": -6},
    "YYZ": {"city": "Toronto",      "country": "CA", "tz": "America/Toronto", "utc": -5},
    "GRU": {"city": "São Paulo",    "country": "BR", "tz": "America/Sao_Paulo","utc": -3},

    # Oceania
    "SYD": {"city": "Sydney",       "country": "AU", "tz": "Australia/Sydney","utc": 10},
    "MEL": {"city": "Melbourne",    "country": "AU", "tz": "Australia/Melbourne","utc":10},
}

SAUDI_AIRPORTS = {k for k, v in AIRPORT_DATA.items() if v["country"] == "SA"}


def get_airport(iata: str) -> dict:
    return AIRPORT_DATA.get(iata.upper(), {
        "city": iata, "country": "??", "tz": "UTC", "utc": 0
    })


def get_timezone(iata: str) -> str:
    return get_airport(iata).get("tz", "UTC")


def get_utc_offset(iata: str) -> float:
    return get_airport(iata).get("utc", 0)


def is_international(origin: str, destination: str) -> bool:
    return (origin.upper() not in SAUDI_AIRPORTS or
            destination.upper() not in SAUDI_AIRPORTS)


def timezone_delta(origin: str, destination: str) -> float:
    """Hours of timezone shift between two airports."""
    return abs(get_utc_offset(destination) - get_utc_offset(origin))


def get_city(iata: str) -> str:
    return get_airport(iata).get("city", iata)
