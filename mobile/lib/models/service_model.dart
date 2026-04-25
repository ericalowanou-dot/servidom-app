/// Catégorie de service (table `categories`).
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.nom,
    this.description,
    this.icone,
    this.estActif,
  });

  final int id;
  final String nom;
  final String? description;
  final String? icone;
  final bool? estActif;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: _asInt(json['id']),
      nom: json['nom']?.toString() ?? '',
      description: json['description']?.toString(),
      icone: json['icone']?.toString(),
      estActif: json['est_actif'] as bool?,
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// Offre d’un prestataire (table `services`).
class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.prestataireId,
    required this.categorieId,
    required this.titre,
    this.description,
    required this.tarifHoraire,
    this.imageUrl,
    this.disponible,
    this.categorieNom,
    this.categorieIcone,
  });

  final int id;
  final int prestataireId;
  final int categorieId;
  final String titre;
  final String? description;
  final double tarifHoraire;
  final String? imageUrl;
  final bool? disponible;
  final String? categorieNom;
  final String? categorieIcone;

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: _asInt(json['id']),
      prestataireId: _asInt(json['prestataire_id']),
      categorieId: _asInt(json['categorie_id']),
      titre: json['titre']?.toString() ?? '',
      description: json['description']?.toString(),
      tarifHoraire: _asDouble(json['tarif_horaire']) ?? 0,
      imageUrl: json['image_url']?.toString(),
      disponible: json['disponible'] as bool?,
      categorieNom: json['categorie_nom']?.toString(),
      categorieIcone: json['categorie_icone']?.toString() ?? json['icone']?.toString(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}

/// Ligne renvoyée par `GET /api/services/prestataires` (jointure user + service).
class PrestataireListItem {
  const PrestataireListItem({
    required this.userId,
    required this.nom,
    required this.prenom,
    this.photoUrl,
    this.quartier,
    this.ville,
    this.noteMoyenne,
    this.nombreAvis,
    this.estVerifie,
    required this.serviceId,
    required this.titreService,
    this.descriptionService,
    this.imageUrl,
    required this.tarifHoraire,
    this.categorieNom,
    this.categorieIcone,
  });

  final int userId;
  final String nom;
  final String prenom;
  final String? photoUrl;
  final String? quartier;
  final String? ville;
  final double? noteMoyenne;
  final int? nombreAvis;
  final bool? estVerifie;
  final int serviceId;
  final String titreService;
  final String? descriptionService;
  final String? imageUrl;
  final double tarifHoraire;
  final String? categorieNom;
  final String? categorieIcone;

  String get nomComplet => '$prenom $nom'.trim();

  String get localisation {
    final q = quartier?.trim();
    final v = ville?.trim();
    if (q != null && q.isNotEmpty && v != null && v.isNotEmpty) {
      return '$q · $v';
    }
    return q ?? v ?? 'Lomé';
  }

  factory PrestataireListItem.fromJson(Map<String, dynamic> json) {
    return PrestataireListItem(
      userId: _pInt(json['id']),
      nom: json['nom']?.toString() ?? '',
      prenom: json['prenom']?.toString() ?? '',
      photoUrl: json['photo_url']?.toString(),
      quartier: json['quartier']?.toString(),
      ville: json['ville']?.toString(),
      noteMoyenne: _pDouble(json['note_moyenne']),
      nombreAvis: _pIntNullable(json['nombre_avis']),
      estVerifie: json['est_verifie'] as bool?,
      serviceId: _pInt(json['service_id']),
      titreService: json['titre']?.toString() ?? '',
      descriptionService: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      tarifHoraire: _pDouble(json['tarif_horaire']) ?? 0,
      categorieNom: json['categorie_nom']?.toString(),
      categorieIcone: json['icone']?.toString(),
    );
  }
}

int _pInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

int? _pIntNullable(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _pDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
