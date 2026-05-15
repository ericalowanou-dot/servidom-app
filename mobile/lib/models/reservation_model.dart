class ReservationModel {
  const ReservationModel({
    required this.id,
    required this.clientId,
    required this.prestataireId,
    required this.serviceId,
    required this.dateIntervention,
    required this.dureeHeures,
    required this.adresseIntervention,
    this.descriptionBesoin,
    this.statut,
    this.montantTotal,
    this.statutPaiement,
    this.referencePaiement,
    this.modePaiement,
    this.createdAt,
    this.prestataireNom,
    this.prestatairePrenom,
    this.prestataireTel,
    this.photoUrl,
    this.categorieNom,
    this.categorieIcone,
    this.serviceTitre,
    this.clientNom,
    this.clientPrenom,
    this.clientTel,
  });

  final int id;
  final int clientId;
  final int prestataireId;
  final int serviceId;
  final DateTime dateIntervention;
  final double dureeHeures;
  final String adresseIntervention;
  final String? descriptionBesoin;
  final String? statut;
  final double? montantTotal;
  final String? statutPaiement;
  final String? referencePaiement;
  final String? modePaiement;
  final DateTime? createdAt;

  final String? prestataireNom;
  final String? prestatairePrenom;
  final String? prestataireTel;
  final String? photoUrl;
  final String? categorieNom;
  final String? categorieIcone;
  final String? serviceTitre;
  final String? clientNom;
  final String? clientPrenom;
  final String? clientTel;

  String? get autrePartieNom {
    final n = prestataireNom ?? clientNom;
    final p = prestatairePrenom ?? clientPrenom;
    if (n == null && p == null) return null;
    return '${p ?? ''} ${n ?? ''}'.trim();
  }

  String get statutLabel {
    switch (statut) {
      case 'confirme':
        return 'Confirmée';
      case 'en_cours':
        return 'En cours';
      case 'termine':
        return 'Terminée';
      case 'annule':
        return 'Annulée';
      case 'en_attente':
      default:
        return 'En attente';
    }
  }

  String get statutPaiementLabel {
    switch (statutPaiement) {
      case 'paye':
        return 'Payé';
      case 'rembourse':
        return 'Remboursé';
      case 'non_paye':
      default:
        return 'Non payé';
    }
  }

  String get modePaiementLabel {
    switch (modePaiement) {
      case 'flooz':
        return 'Flooz';
      case 'tmoney':
        return 'T-Money';
      case 'mix':
        return 'Mix by YAS';
      default:
        return modePaiement ?? '';
    }
  }

  bool get estPaye => statutPaiement == 'paye';

  String? get telephoneContact => prestataireTel ?? clientTel;

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    return ReservationModel(
      id: _asInt(json['id']),
      clientId: _asInt(json['client_id']),
      prestataireId: _asInt(json['prestataire_id']),
      serviceId: _asInt(json['service_id']),
      dateIntervention: DateTime.tryParse(json['date_intervention']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      dureeHeures: _asDouble(json['duree_heures']) ?? 0,
      adresseIntervention: json['adresse_intervention']?.toString() ?? '',
      descriptionBesoin: json['description_besoin']?.toString(),
      statut: json['statut']?.toString(),
      montantTotal: _asDouble(json['montant_total']),
      statutPaiement: json['statut_paiement']?.toString(),
      referencePaiement: json['reference_paiement']?.toString(),
      modePaiement: json['mode_paiement']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      prestataireNom: json['prestataire_nom']?.toString(),
      prestatairePrenom: json['prestataire_prenom']?.toString(),
      prestataireTel: json['prestataire_tel']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      categorieNom: json['categorie_nom']?.toString(),
      categorieIcone: json['categorie_icone']?.toString(),
      serviceTitre: json['service_titre']?.toString() ?? json['titre']?.toString(),
      clientNom: json['client_nom']?.toString(),
      clientPrenom: json['client_prenom']?.toString(),
      clientTel: json['client_tel']?.toString(),
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
