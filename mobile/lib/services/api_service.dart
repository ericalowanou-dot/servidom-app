import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/reservation_model.dart';
import '../models/service_model.dart';
import '../models/user_model.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

String toFrenchErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  final raw = error.toString();
  if (raw.startsWith('Exception: ')) {
    return raw.replaceFirst('Exception: ', '');
  }
  return 'Une erreur est survenue. Veuillez réessayer.';
}

/// Client HTTP ServiDom.
///
/// - **Web / Windows / macOS / Linux** : `http://localhost:3000/api`
/// - **Android réel (via `adb reverse`)** : `http://localhost:3000/api`
/// - **Émulateur Android** : `http://10.0.2.2:3000/api`
///
/// Override possible avec:
/// `--dart-define=API_BASE_URL=http://<ip-ou-host>:3000/api`
class ApiService {
  ApiService(this._prefs);

  final SharedPreferences _prefs;
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (kIsWeb) return 'http://localhost:3000/api';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/api';
      default:
        return 'http://localhost:3000/api';
    }
  }

  static const String _tokenKey = 'servidom_jwt';

  static String resolveMediaUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    final value = rawUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    final api = baseUrl;
    final root = api.endsWith('/api') ? api.substring(0, api.length - 4) : api;
    return value.startsWith('/') ? '$root$value' : '$root/$value';
  }

  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    await _prefs.remove(_tokenKey);
  }

  String? getToken() => _prefs.getString(_tokenKey);

  Map<String, String> _headers({bool jsonBody = false}) {
    final h = <String, String>{
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
    };
    final t = getToken();
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  void _throwIfError(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>?;
    } catch (_) {}
    final msg = body?['message']?.toString() ?? 'Erreur réseau (${res.statusCode})';
    throw ApiException(msg, statusCode: res.statusCode);
  }

  Future<http.Response> _safeRequest(Future<http.Response> Function() fn) async {
    try {
      return await fn().timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Impossible de contacter le serveur API.');
    }
  }

  /// Inscription — aligné sur `POST /api/auth/register`.
  Future<AuthResult> register({
    required String nom,
    required String prenom,
    required String telephone,
    required String motDePasse,
    required String role,
    String? quartier,
    String? email,
  }) async {
    final res = await _safeRequest(
      () => http.post(
        Uri.parse('${ApiService.baseUrl}/auth/register'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          'nom': nom,
          'prenom': prenom,
          'telephone': telephone,
          'mot_de_passe': motDePasse,
          'role': role,
          if (quartier != null && quartier.isNotEmpty) 'quartier': quartier,
          if (email != null && email.isNotEmpty) 'email': email,
        }),
      ),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final token = map['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Réponse inscription invalide.');
    }
    await saveToken(token);
    final user = UserModel.fromJson(map['user'] as Map<String, dynamic>);
    return AuthResult(token: token, user: user);
  }

  /// Connexion — `POST /api/auth/login`.
  Future<AuthResult> login({
    required String telephone,
    required String motDePasse,
  }) async {
    final res = await _safeRequest(
      () => http.post(
        Uri.parse('${ApiService.baseUrl}/auth/login'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          'telephone': telephone,
          'mot_de_passe': motDePasse,
        }),
      ),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final token = map['token']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Réponse connexion invalide.');
    }
    await saveToken(token);
    final user = UserModel.fromJson(map['user'] as Map<String, dynamic>);
    return AuthResult(token: token, user: user);
  }

  /// Profil connecté — `GET /api/auth/me`.
  Future<UserModel> getMe() async {
    final res = await _safeRequest(
      () => http.get(
        Uri.parse('${ApiService.baseUrl}/auth/me'),
        headers: _headers(),
      ),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return UserModel.fromJson(map);
  }

  /// Catégories — `GET /api/services/categories`.
  Future<List<CategoryModel>> getCategories() async {
    final res = await _safeRequest(
      () => http.get(
        Uri.parse('${ApiService.baseUrl}/services/categories'),
        headers: _headers(),
      ),
    );
    _throwIfError(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Prestataires — `GET /api/services/prestataires?categorie_id=`.
  Future<List<PrestataireListItem>> getPrestataires(int categorieId, {String? quartier}) async {
    final q = <String, String>{'categorie_id': '$categorieId'};
    if (quartier != null && quartier.trim().isNotEmpty) {
      q['quartier'] = quartier.trim();
    }
    final uri = Uri.parse('${ApiService.baseUrl}/services/prestataires').replace(queryParameters: q);
    final res = await _safeRequest(() => http.get(uri, headers: _headers()));
    _throwIfError(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => PrestataireListItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Détail prestataire — `GET /api/services/prestataires/:id`.
  Future<PrestataireDetailResponse> getPrestataire(int id) async {
    final res = await _safeRequest(
      () => http.get(
        Uri.parse('${ApiService.baseUrl}/services/prestataires/$id'),
        headers: _headers(),
      ),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final p = map['prestataire'] as Map<String, dynamic>;
    final services = (map['services'] as List<dynamic>? ?? [])
        .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final avis = (map['avis'] as List<dynamic>? ?? [])
        .map((e) => AvisItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return PrestataireDetailResponse(
      prestataire: UserModel.fromJson(p),
      services: services,
      avis: avis,
    );
  }

  /// Réservation — `POST /api/reservations` (client uniquement).
  Future<ReservationModel> createReservation({
    required int prestataireId,
    required int serviceId,
    required DateTime dateIntervention,
    required double dureeHeures,
    required String adresseIntervention,
    String? descriptionBesoin,
  }) async {
    final res = await _safeRequest(
      () => http.post(
        Uri.parse('${ApiService.baseUrl}/reservations'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          'prestataire_id': prestataireId,
          'service_id': serviceId,
          'date_intervention': dateIntervention.toUtc().toIso8601String(),
          'duree_heures': dureeHeures,
          'adresse_intervention': adresseIntervention,
          if (descriptionBesoin != null && descriptionBesoin.isNotEmpty) 'description_besoin': descriptionBesoin,
        }),
      ),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final r = map['reservation'] as Map<String, dynamic>?;
    if (r == null) {
      throw ApiException('Réponse réservation invalide.');
    }
    return ReservationModel.fromJson(r);
  }

  /// Historique — `GET /api/reservations/mes-reservations`.
  Future<List<ReservationModel>> getMesReservations() async {
    final res = await _safeRequest(
      () => http.get(
        Uri.parse('${ApiService.baseUrl}/reservations/mes-reservations'),
        headers: _headers(),
      ),
    );
    _throwIfError(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => ReservationModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ServiceModel> createService({
    required int categorieId,
    required String titre,
    String? description,
    required double tarifHoraire,
    XFile? imageFile,
  }) async {
    final req = http.MultipartRequest('POST', Uri.parse('${ApiService.baseUrl}/services'));
    req.headers.addAll(_headers());
    req.fields['categorie_id'] = '$categorieId';
    req.fields['titre'] = titre;
    req.fields['tarif_horaire'] = '$tarifHoraire';
    if (description != null && description.trim().isNotEmpty) {
      req.fields['description'] = description.trim();
    }
    if (imageFile != null) {
      final mimeType = _guessMimeType(imageFile.name);
      final mediaType = MediaType.parse(mimeType);
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        req.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: imageFile.name,
            contentType: mediaType,
          ),
        );
      } else {
        req.files.add(
          await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
            filename: imageFile.name,
            contentType: mediaType,
          ),
        );
      }
    }
    final res = await _safeMultipart(req);
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return ServiceModel.fromJson(map);
  }

  Future<http.Response> _safeMultipart(http.MultipartRequest request) async {
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      return http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException('Impossible de contacter le serveur API.');
    }
  }

  String _guessMimeType(String filename) {
    final n = filename.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

class AuthResult {
  const AuthResult({required this.token, required this.user});
  final String token;
  final UserModel user;
}

class PrestataireDetailResponse {
  const PrestataireDetailResponse({
    required this.prestataire,
    required this.services,
    required this.avis,
  });
  final UserModel prestataire;
  final List<ServiceModel> services;
  final List<AvisItem> avis;
}

class AvisItem {
  const AvisItem({
    required this.note,
    this.commentaire,
    this.createdAt,
    this.clientNom,
    this.clientPrenom,
  });
  final int note;
  final String? commentaire;
  final DateTime? createdAt;
  final String? clientNom;
  final String? clientPrenom;

  String get auteur => '${clientPrenom ?? ''} ${clientNom ?? ''}'.trim();

  factory AvisItem.fromJson(Map<String, dynamic> json) {
    return AvisItem(
      note: int.tryParse(json['note']?.toString() ?? '') ?? (json['note'] as num?)?.toInt() ?? 0,
      commentaire: json['commentaire']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      clientNom: json['nom']?.toString(),
      clientPrenom: json['prenom']?.toString(),
    );
  }
}
