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

  /// Mise à jour profil — `PUT /api/users/profil`.
  Future<UserModel> updateProfile({
    String? nom,
    String? prenom,
    String? email,
    String? quartier,
    double? latitude,
    double? longitude,
    XFile? photoFile,
  }) async {
    if (photoFile != null) {
      final req = http.MultipartRequest('PUT', Uri.parse('${ApiService.baseUrl}/users/profil'));
      req.headers.addAll(_headers());
      if (nom != null) req.fields['nom'] = nom;
      if (prenom != null) req.fields['prenom'] = prenom;
      if (email != null) req.fields['email'] = email;
      if (quartier != null) req.fields['quartier'] = quartier;
      if (latitude != null) req.fields['latitude'] = '$latitude';
      if (longitude != null) req.fields['longitude'] = '$longitude';
      final mimeType = _guessMimeType(photoFile.name);
      final mediaType = MediaType.parse(mimeType);
      if (kIsWeb) {
        final bytes = await photoFile.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes('photo', bytes, filename: photoFile.name, contentType: mediaType));
      } else {
        req.files.add(await http.MultipartFile.fromPath('photo', photoFile.path, filename: photoFile.name, contentType: mediaType));
      }
      final res = await _safeMultipart(req);
      _throwIfError(res);
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return UserModel.fromJson(map['user'] as Map<String, dynamic>);
    }
    final res = await _safeRequest(
      () => http.put(
        Uri.parse('${ApiService.baseUrl}/users/profil'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          if (nom != null) 'nom': nom,
          if (prenom != null) 'prenom': prenom,
          if (email != null) 'email': email,
          if (quartier != null) 'quartier': quartier,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        }),
      ),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return UserModel.fromJson(map['user'] as Map<String, dynamic>);
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
  /// Mise à jour statut — `PATCH /api/reservations/:id/statut`.
  Future<ReservationModel> updateReservationStatut({required int id, required String statut}) async {
    final res = await _safeRequest(
      () => http.patch(
        Uri.parse('${ApiService.baseUrl}/reservations/$id/statut'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({'statut': statut}),
      ),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return ReservationModel.fromJson(map['reservation'] as Map<String, dynamic>);
  }

  /// Mise à jour paiement — `PATCH /api/reservations/:id/paiement`.
  Future<ReservationModel> updateReservationPaiement({required int id, required String statutPaiement}) async {
    final res = await _safeRequest(
      () => http.patch(
        Uri.parse('${ApiService.baseUrl}/reservations/$id/paiement'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({'statut_paiement': statutPaiement}),
      ),
    );
    _throwIfError(res);
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return ReservationModel.fromJson(map['reservation'] as Map<String, dynamic>);
  }

  /// Avis — `POST /api/reservations/avis`.
  Future<void> laisserAvis({required int reservationId, required int note, String? commentaire}) async {
    final res = await _safeRequest(
      () => http.post(
        Uri.parse('${ApiService.baseUrl}/reservations/avis'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({
          'reservation_id': reservationId,
          'note': note,
          if (commentaire != null && commentaire.isNotEmpty) 'commentaire': commentaire,
        }),
      ),
    );
    _throwIfError(res);
  }

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

  /// Mes services (prestataire) — `GET /api/services/mes-services`.
  Future<List<ServiceModel>> getMesServices() async {
    final res = await _safeRequest(
      () => http.get(Uri.parse('${ApiService.baseUrl}/services/mes-services'), headers: _headers()),
    );
    _throwIfError(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => ServiceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ServiceModel> updateService({
    required int id,
    int? categorieId,
    String? titre,
    String? description,
    double? tarifHoraire,
    bool? disponible,
    XFile? imageFile,
  }) async {
    final req = http.MultipartRequest('PUT', Uri.parse('${ApiService.baseUrl}/services/$id'));
    req.headers.addAll(_headers());
    if (categorieId != null) req.fields['categorie_id'] = '$categorieId';
    if (titre != null) req.fields['titre'] = titre;
    if (description != null) req.fields['description'] = description;
    if (tarifHoraire != null) req.fields['tarif_horaire'] = '$tarifHoraire';
    if (disponible != null) req.fields['disponible'] = disponible ? 'true' : 'false';
    if (imageFile != null) {
      final mimeType = _guessMimeType(imageFile.name);
      final mediaType = MediaType.parse(mimeType);
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        req.files.add(http.MultipartFile.fromBytes('image', bytes, filename: imageFile.name, contentType: mediaType));
      } else {
        req.files.add(await http.MultipartFile.fromPath('image', imageFile.path, filename: imageFile.name, contentType: mediaType));
      }
    }
    final res = await _safeMultipart(req);
    _throwIfError(res);
    return ServiceModel.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteService(int id) async {
    final res = await _safeRequest(
      () => http.delete(Uri.parse('${ApiService.baseUrl}/services/$id'), headers: _headers()),
    );
    _throwIfError(res);
  }

  /// Admin — statistiques.
  Future<AdminStats> getAdminStats() async {
    final res = await _safeRequest(
      () => http.get(Uri.parse('${ApiService.baseUrl}/admin/stats'), headers: _headers()),
    );
    _throwIfError(res);
    return AdminStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<AdminUserRow>> getAdminUsers() async {
    final res = await _safeRequest(
      () => http.get(Uri.parse('${ApiService.baseUrl}/admin/utilisateurs'), headers: _headers()),
    );
    _throwIfError(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => AdminUserRow.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setPrestataireVerifie(int userId, bool estVerifie) async {
    final res = await _safeRequest(
      () => http.patch(
        Uri.parse('${ApiService.baseUrl}/admin/utilisateurs/$userId/verifier'),
        headers: _headers(jsonBody: true),
        body: jsonEncode({'est_verifie': estVerifie}),
      ),
    );
    _throwIfError(res);
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

class AdminStats {
  const AdminStats({
    required this.utilisateurs,
    required this.prestataires,
    required this.clients,
    required this.services,
    required this.reservations,
    required this.avis,
  });
  final int utilisateurs;
  final int prestataires;
  final int clients;
  final int services;
  final int reservations;
  final int avis;

  factory AdminStats.fromJson(Map<String, dynamic> json) => AdminStats(
        utilisateurs: _adminInt(json['utilisateurs']),
        prestataires: _adminInt(json['prestataires']),
        clients: _adminInt(json['clients']),
        services: _adminInt(json['services']),
        reservations: _adminInt(json['reservations']),
        avis: _adminInt(json['avis']),
      );
}

class AdminUserRow {
  const AdminUserRow({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.role,
    this.quartier,
    this.estActif,
    this.estVerifie,
    this.createdAt,
  });
  final int id;
  final String nom;
  final String prenom;
  final String telephone;
  final String role;
  final String? quartier;
  final bool? estActif;
  final bool? estVerifie;
  final DateTime? createdAt;

  String get nomComplet => '$prenom $nom'.trim();

  factory AdminUserRow.fromJson(Map<String, dynamic> json) => AdminUserRow(
        id: _adminInt(json['id']),
        nom: json['nom']?.toString() ?? '',
        prenom: json['prenom']?.toString() ?? '',
        telephone: json['telephone']?.toString() ?? '',
        role: json['role']?.toString() ?? '',
        quartier: json['quartier']?.toString(),
        estActif: json['est_actif'] as bool?,
        estVerifie: json['est_verifie'] as bool?,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

int _adminInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
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
