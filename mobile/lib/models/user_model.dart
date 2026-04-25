class UserModel {
  const UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.role,
    this.quartier,
    this.ville,
    this.noteMoyenne,
    this.email,
    this.photoUrl,
    this.nombreAvis,
    this.estVerifie,
  });

  final int id;
  final String nom;
  final String prenom;
  final String telephone;
  final String role;
  final String? quartier;
  final String? ville;
  final double? noteMoyenne;
  final String? email;
  final String? photoUrl;
  final int? nombreAvis;
  final bool? estVerifie;

  String get nomComplet => '$prenom $nom'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: _asInt(json['id']),
      nom: json['nom']?.toString() ?? '',
      prenom: json['prenom']?.toString() ?? '',
      telephone: json['telephone']?.toString() ?? '',
      role: json['role']?.toString() ?? 'client',
      quartier: json['quartier']?.toString(),
      ville: json['ville']?.toString(),
      noteMoyenne: _asDouble(json['note_moyenne']),
      email: json['email']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      nombreAvis: _asIntNullable(json['nombre_avis']),
      estVerifie: json['est_verifie'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'prenom': prenom,
        'telephone': telephone,
        'role': role,
        'quartier': quartier,
        'ville': ville,
        'note_moyenne': noteMoyenne,
        'email': email,
        'photo_url': photoUrl,
        'nombre_avis': nombreAvis,
        'est_verifie': estVerifie,
      };

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int? _asIntNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
