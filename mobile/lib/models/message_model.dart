class MessageModel {
  const MessageModel({
    required this.id,
    required this.reservationId,
    required this.senderId,
    required this.contenu,
    this.lu,
    required this.createdAt,
    this.senderNom,
    this.senderPrenom,
  });

  final int id;
  final int reservationId;
  final int senderId;
  final String contenu;
  final bool? lu;
  final DateTime createdAt;
  final String? senderNom;
  final String? senderPrenom;

  String get senderNomComplet => '${senderPrenom ?? ''} ${senderNom ?? ''}'.trim();

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: _int(json['id']),
      reservationId: _int(json['reservation_id']),
      senderId: _int(json['sender_id']),
      contenu: json['contenu']?.toString() ?? '',
      lu: json['lu'] as bool?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      senderNom: json['sender_nom']?.toString(),
      senderPrenom: json['sender_prenom']?.toString(),
    );
  }

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

class ConversationModel {
  const ConversationModel({
    required this.reservationId,
    this.statut,
    required this.dateIntervention,
    this.serviceTitre,
    this.autreNom,
    this.autrePrenom,
    this.dernierMessage,
    this.dernierMessageAt,
    this.nonLus,
  });

  final int reservationId;
  final String? statut;
  final DateTime dateIntervention;
  final String? serviceTitre;
  final String? autreNom;
  final String? autrePrenom;
  final String? dernierMessage;
  final DateTime? dernierMessageAt;
  final int? nonLus;

  String get autrePartie => '${autrePrenom ?? ''} ${autreNom ?? ''}'.trim();

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      reservationId: MessageModel._int(json['reservation_id']),
      statut: json['statut']?.toString(),
      dateIntervention: DateTime.tryParse(json['date_intervention']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      serviceTitre: json['service_titre']?.toString(),
      autreNom: json['autre_nom']?.toString(),
      autrePrenom: json['autre_prenom']?.toString(),
      dernierMessage: json['dernier_message']?.toString(),
      dernierMessageAt: DateTime.tryParse(json['dernier_message_at']?.toString() ?? ''),
      nonLus: json['non_lus'] != null ? MessageModel._int(json['non_lus']) : null,
    );
  }
}
