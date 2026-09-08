import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'server_config.dart';

class AuthState extends ChangeNotifier {
  AuthState() : api = ApiClient();

  final ApiClient api;
  AuthUser? user;
  Spg? spgProfile;
  bool restoring = true;

  static const _tokenKey = 'sigraforce_token';
  static const _userKey = 'sigraforce_user';

  bool get isLoggedIn => user != null;

  /// Applies a new server address immediately (so it's ready before login) and remembers it
  /// for next launch — called from the login screen's "Pengaturan Server" dialog.
  Future<void> setServerUrl(String rawInput) async {
    final normalized = ServerConfig.normalize(rawInput);
    if (normalized.isEmpty) return;
    api.baseUrl = normalized;
    await ServerConfig.save(normalized);
    notifyListeners();
  }

  Future<void> restore() async {
    final savedServerUrl = await ServerConfig.load();
    if (savedServerUrl != null) api.baseUrl = savedServerUrl;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (token != null && userJson != null) {
      api.token = token;
      try {
        user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
        if (user?.spgId != null) {
          spgProfile = await api.getSpg(user!.spgId!);
        }
      } catch (_) {
        user = null;
        await prefs.remove(_tokenKey);
        await prefs.remove(_userKey);
      }
    }
    restoring = false;
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    try {
      final res = await api.login(username, password);
      final token = res['accessToken'] as String;
      final u = AuthUser.fromJson(res['user'] as Map<String, dynamic>);
      api.token = token;
      user = u;
      if (u.spgId != null) {
        spgProfile = await api.getSpg(u.spgId!);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(u.toJson()));
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Gagal terhubung ke server. Periksa koneksi Anda.';
    }
  }

  Future<void> logout() async {
    user = null;
    spgProfile = null;
    api.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }

  Future<void> refreshSpgProfile() async {
    if (user?.spgId == null) return;
    spgProfile = await api.getSpg(user!.spgId!);
    notifyListeners();
  }
}
