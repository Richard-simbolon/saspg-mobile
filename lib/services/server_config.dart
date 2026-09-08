import 'package:shared_preferences/shared_preferences.dart';

/// Persists the SPG's chosen server address across app restarts — the LAN IP the office
/// server runs on changes often, so this is meant to be editable from the login screen
/// instead of baked into the app at build time.
class ServerConfig {
  static const _key = 'sigraforce_server_base_url';

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<void> save(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, baseUrl);
  }

  /// Accepts whatever an SPG is likely to type — a bare IP ("192.168.1.4"), an IP with port
  /// ("192.168.1.4:3000"), or a full URL — and normalizes it to `http(s)://host:port/api`.
  static String normalize(String raw) {
    var input = raw.trim();
    if (input.isEmpty) return input;
    if (!input.contains('://')) input = 'http://$input';

    final uri = Uri.tryParse(input);
    if (uri == null || uri.host.isEmpty) return raw.trim();

    final port = uri.hasPort ? uri.port : 3000;
    var path = uri.path;
    if (!path.endsWith('/api')) {
      path = path.endsWith('/') ? '${path}api' : '$path/api';
    }
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: port,
      path: path,
    ).toString();
  }
}
