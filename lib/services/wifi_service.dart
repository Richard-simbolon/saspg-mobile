import 'package:network_info_plus/network_info_plus.dart';

class WifiService {
  static final _networkInfo = NetworkInfo();

  /// Best-effort currently-connected WiFi network name, or null if not on
  /// WiFi (cellular data) or the platform/permissions don't allow reading
  /// it (e.g. iOS without the "Access WiFi Information" entitlement, or
  /// Flutter web). Never throws — a caller-visible connection error here
  /// would incorrectly block check-in for something that's meant to be an
  /// optional extra signal, not a hard requirement.
  static Future<String?> currentSsid() async {
    try {
      final raw = await _networkInfo.getWifiName();
      if (raw == null) return null;
      // Android/iOS sometimes wrap the SSID in quotes (e.g. `"Sentosa-Guest"`).
      final cleaned = raw.replaceAll('"', '').trim();
      if (cleaned.isEmpty || cleaned == '<unknown ssid>') return null;
      return cleaned;
    } catch (_) {
      return null;
    }
  }
}
