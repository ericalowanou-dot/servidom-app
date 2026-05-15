import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/api_service.dart';

const _userJsonKey = 'servidom_user_json';

/// État de connexion ServiDom (Provider).
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api, this._prefs);

  final ApiService _api;
  final SharedPreferences _prefs;

  UserModel? _user;
  bool _initialized = false;
  bool _loading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null && (_api.getToken()?.isNotEmpty ?? false);
  bool get initialized => _initialized;
  bool get loading => _loading;
  String? get error => _error;

  /// Au démarrage : valide le JWT et charge le profil (`/api/auth/me`).
  Future<void> init() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();
    try {
      final token = _api.getToken();
      if (token == null || token.isEmpty) {
        _user = null;
        await _prefs.remove(_userJsonKey);
      } else {
        try {
          _user = await _api.getMe();
          await _prefs.setString(_userJsonKey, jsonEncode(_user!.toJson()));
        } catch (_) {
          await _api.clearToken();
          _user = null;
          await _prefs.remove(_userJsonKey);
        }
      }
    } finally {
      _loading = false;
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _persistUser(UserModel? u) async {
    if (u == null) {
      await _prefs.remove(_userJsonKey);
    } else {
      await _prefs.setString(_userJsonKey, jsonEncode(u.toJson()));
    }
  }

  Future<void> login(String telephone, String motDePasse) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      final r = await _api.login(telephone: telephone, motDePasse: motDePasse);
      _user = r.user;
      await _persistUser(_user);
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String nom,
    required String prenom,
    required String telephone,
    required String motDePasse,
    required String role,
    String? quartier,
  }) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      final r = await _api.register(
        nom: nom,
        prenom: prenom,
        telephone: telephone,
        motDePasse: motDePasse,
        role: role,
        quartier: quartier,
      );
      _user = r.user;
      await _persistUser(_user);
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? nom,
    String? prenom,
    String? email,
    String? quartier,
    double? latitude,
    double? longitude,
    XFile? photoFile,
  }) async {
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      _user = await _api.updateProfile(
        nom: nom,
        prenom: prenom,
        email: email,
        quartier: quartier,
        latitude: latitude,
        longitude: longitude,
        photoFile: photoFile,
      );
      await _persistUser(_user);
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (_api.getToken() == null || _api.getToken()!.isEmpty) return;
    try {
      _user = await _api.getMe();
      await _persistUser(_user);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _api.clearToken();
    _user = null;
    await _prefs.remove(_userJsonKey);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
