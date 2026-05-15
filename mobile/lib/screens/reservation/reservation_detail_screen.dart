import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../models/reservation_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../messages/chat_screen.dart';

class ReservationDetailArgs {
  const ReservationDetailArgs({required this.reservation});
  final ReservationModel reservation;
}

class ReservationDetailScreen extends StatefulWidget {
  const ReservationDetailScreen({super.key, required this.reservation});

  final ReservationModel reservation;
  static const routeName = '/reservation-detail';

  @override
  State<ReservationDetailScreen> createState() => _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  late ReservationModel _r;
  bool _busy = false;
  int _noteAvis = 5;
  final _commentaireCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _r = widget.reservation;
  }

  @override
  void dispose() {
    _commentaireCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toFrenchErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatut(String statut) async {
    await _run(() async {
      final updated = await context.read<ApiService>().updateReservationStatut(id: _r.id, statut: statut);
      setState(() => _r = _mergeReservation(updated));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Statut mis à jour.')));
      Navigator.pop(context, true);
    });
  }

  Future<void> _changePaiement(String statutPaiement) async {
    await _run(() async {
      final updated = await context.read<ApiService>().updateReservationPaiement(id: _r.id, statutPaiement: statutPaiement);
      setState(() => _r = _mergeReservation(updated));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paiement mis à jour.')));
    });
  }

  ReservationModel _mergeReservation(ReservationModel updated) {
    return ReservationModel(
      id: updated.id,
      clientId: updated.clientId,
      prestataireId: updated.prestataireId,
      serviceId: updated.serviceId,
      dateIntervention: updated.dateIntervention,
      dureeHeures: updated.dureeHeures,
      adresseIntervention: updated.adresseIntervention,
      descriptionBesoin: _r.descriptionBesoin ?? updated.descriptionBesoin,
      statut: updated.statut,
      montantTotal: updated.montantTotal ?? _r.montantTotal,
      statutPaiement: updated.statutPaiement,
      createdAt: updated.createdAt ?? _r.createdAt,
      prestataireNom: _r.prestataireNom,
      prestatairePrenom: _r.prestatairePrenom,
      prestataireTel: _r.prestataireTel,
      photoUrl: _r.photoUrl,
      categorieNom: _r.categorieNom,
      categorieIcone: _r.categorieIcone,
      serviceTitre: _r.serviceTitre,
      clientNom: _r.clientNom,
      clientPrenom: _r.clientPrenom,
      clientTel: _r.clientTel,
    );
  }

  Future<void> _submitAvis() async {
    await _run(() async {
      await context.read<ApiService>().laisserAvis(
            reservationId: _r.id,
            note: _noteAvis,
            commentaire: _commentaireCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Merci pour votre avis !')));
      Navigator.pop(context, true);
    });
  }

  Future<void> _call(String? tel) async {
    if (tel == null || tel.isEmpty) return;
    final uri = Uri.parse('tel:$tel');
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d’ouvrir l’appel.')));
    }
  }

  List<Widget> _statutActions(String role) {
    final s = _r.statut ?? 'en_attente';
    final actions = <Widget>[];

    if (role == 'prestataire') {
      if (s == 'en_attente') {
        actions.add(_actionBtn('Confirmer', 'confirme', Icons.check_circle_outline));
      }
      if (s == 'confirme') {
        actions.add(_actionBtn('Démarrer', 'en_cours', Icons.play_circle_outline));
      }
      if (s == 'en_cours') {
        actions.add(_actionBtn('Terminer', 'termine', Icons.task_alt_rounded));
      }
    }
    if (s != 'annule' && s != 'termine') {
      actions.add(_actionBtn('Annuler', 'annule', Icons.cancel_outlined, isDestructive: true));
    }
    return actions;
  }

  Widget _actionBtn(String label, String statut, IconData icon, {bool isDestructive = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: FilledButton.tonalIcon(
        onPressed: _busy ? null : () => _changeStatut(statut),
        style: isDestructive
            ? FilledButton.styleFrom(backgroundColor: AppColors.error.withValues(alpha: 0.12), foregroundColor: AppColors.error)
            : null,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = context.watch<AuthProvider>().user?.role ?? 'client';
    final tel = _r.telephoneContact;
    final canAvis = role == 'client' && _r.statut == 'termine';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Détail réservation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_r.serviceTitre ?? 'Service', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (_r.autrePartieNom != null && _r.autrePartieNom!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(_r.autrePartieNom!, style: theme.textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 12),
                  _infoRow(Icons.calendar_today_rounded, '${_r.dateIntervention.day}/${_r.dateIntervention.month}/${_r.dateIntervention.year} · ${_r.dureeHeures}h'),
                  _infoRow(Icons.place_outlined, _r.adresseIntervention),
                  if (_r.descriptionBesoin != null && _r.descriptionBesoin!.isNotEmpty)
                    _infoRow(Icons.notes_rounded, _r.descriptionBesoin!),
                  _infoRow(Icons.info_outline_rounded, 'Statut : ${_r.statutLabel}'),
                  _infoRow(Icons.payments_outlined, 'Paiement : ${_r.statutPaiementLabel}'),
                  if (_r.montantTotal != null)
                    _infoRow(Icons.attach_money_rounded, '${_r.montantTotal!.toStringAsFixed(0)} FCFA'),
                ],
              ),
            ),
          ),
          if (_r.statut != 'annule') ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  ChatScreen.routeName,
                  arguments: ChatArgs(
                    reservationId: _r.id,
                    titre: _r.serviceTitre ?? 'Messages',
                    autrePartie: _r.autrePartieNom,
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Envoyer un message'),
            ),
          ],
          if (tel != null && tel.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _call(tel),
              icon: const Icon(Icons.phone_rounded),
              label: Text('Appeler $tel'),
            ),
          ],
          const SizedBox(height: 16),
          Text('Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(children: _statutActions(role)),
          const SizedBox(height: 16),
          Text('Paiement', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final p in ['non_paye', 'paye', 'rembourse'])
                ChoiceChip(
                  label: Text(p == 'non_paye' ? 'Non payé' : p == 'paye' ? 'Payé' : 'Remboursé'),
                  selected: _r.statutPaiement == p || (_r.statutPaiement == null && p == 'non_paye'),
                  onSelected: _busy ? null : (_) => _changePaiement(p),
                ),
            ],
          ),
          if (canAvis) ...[
            const SizedBox(height: 24),
            Text('Laisser un avis', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _noteAvis = star),
                  icon: Icon(star <= _noteAvis ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.secondary, size: 32),
                );
              }),
            ),
            TextField(
              controller: _commentaireCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Commentaire (optionnel)', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _submitAvis,
              icon: const Icon(Icons.rate_review_rounded),
              label: const Text('Envoyer l’avis'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}
