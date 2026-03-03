import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InternetSettings {
  static const String _relayUrlKey = 'internet_relay_url';
  static const String _relayUrlFromDefine = String.fromEnvironment(
    'FANORONA_RELAY_URL',
    defaultValue: '',
  );

  static Future<String> loadRelayUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_relayUrlKey) ?? '').trim();
  }

  static Future<String> resolveRelayUrl() async {
    final fromEnvFile = dotenv.maybeGet('FANORONA_RELAY_URL')?.trim() ?? '';
    if (fromEnvFile.isNotEmpty) {
      return fromEnvFile;
    }

    final fromDefine = _relayUrlFromDefine.trim();
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    return loadRelayUrl();
  }

  static Future<void> saveRelayUrl(String relayUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_relayUrlKey, relayUrl.trim());
  }
}
