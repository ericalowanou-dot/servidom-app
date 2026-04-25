import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/service_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../reservation/reservation_screen.dart';

class PrestataireDetailArgs {
  const PrestataireDetailArgs({required this.prestataireId, this.initialServiceId});
  final int prestataireId;
  final int? initialServiceId;
}

class PrestataireDetailScreen extends StatefulWidget {
  const PrestataireDetailScreen({super.key, required this.prestataireId, this.initialServiceId});

  final int prestataireId;
  final int? initialServiceId;

  static const routeName = '/prestataire-detail';

  @override
  State<PrestataireDetailScreen> createState() => _PrestataireDetailScreenState();
}

class _PrestataireDetailScreenState extends State<PrestataireDetailScreen> {
  late Future<PrestataireDetailResponse> _future;
  int? _selectedServiceId;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().getPrestataire(widget.prestataireId).then((data) {
      if (!mounted) return data;
      final services = data.services;
      if (services.isEmpty) {
        setState(() => _selectedServiceId = null);
        return data;
      }
      final initial = widget.initialServiceId;
      if (initial != null && services.any((s) => s.id == initial)) {
        setState(() => _selectedServiceId = initial);
      } else {
        setState(() => _selectedServiceId = services.first.id);
      }
      return data;
    });
  }

  void _book(BuildContext context, UserModel prestataire, List<ServiceModel> services) {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour réserver.')),
      );
      Navigator.pushNamed(context, LoginScreen.routeName);
      return;
    }
    if (auth.user?.role != 'client') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seuls les clients peuvent réserver un service.')),
      );
      return;
    }
    final sid = _selectedServiceId;
    if (sid == null) return;
    final svc = services.firstWhere((s) => s.id == sid, orElse: () => services.first);
    Navigator.pushNamed(
      context,
      ReservationScreen.routeName,
      arguments: ReservationArgs(
        prestataireId: prestataire.id,
        serviceId: svc.id,
        prestataireNom: prestataire.nomComplet,
        serviceTitre: svc.titre,
        tarifHoraire: svc.tarifHoraire,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<PrestataireDetailResponse>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Prestataire')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          final message = toFrenchErrorMessage(snap.error!);
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(title: const Text('Prestataire')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message, textAlign: TextAlign.center),
              ),
            ),
          );
        }
        final data = snap.data!;
        final p = data.prestataire;
        final services = data.services;

        final hasPhoto = p.photoUrl != null && p.photoUrl!.isNotEmpty;
        final lieu = [
          if (p.quartier != null && p.quartier!.trim().isNotEmpty) p.quartier!.trim(),
          if (p.ville != null && p.ville!.trim().isNotEmpty) p.ville!.trim(),
        ].join(' · ');

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text('${p.prenom} ${p.nom}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasPhoto)
                        Image.network(
                          p.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: AppColors.primary.withValues(alpha: 0.2)),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.75),
                              ],
                            ),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.55)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text(
                            (p.noteMoyenne != null && p.noteMoyenne! > 0)
                                ? p.noteMoyenne!.toStringAsFixed(1)
                                : 'Nouveau',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (p.nombreAvis != null && p.nombreAvis! > 0)
                            Text(' · ${p.nombreAvis} avis', style: theme.textTheme.bodySmall),
                          const Spacer(),
                          if (p.estVerifie == true)
                            Chip(
                              avatar: const Icon(Icons.verified_rounded, size: 18, color: AppColors.primary),
                              label: const Text('Vérifié'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lieu.isNotEmpty ? lieu : 'Lomé',
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text('Services proposés', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (services.isEmpty)
                        Text('Aucune offre publiée pour le moment.', style: theme.textTheme.bodyMedium)
                      else
                        ...services.map((s) {
                          final selected = _selectedServiceId == s.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Material(
                              color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => setState(() => _selectedServiceId = s.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                        color: selected ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.titre, style: theme.textTheme.titleSmall),
                                            if (s.description != null && s.description!.isNotEmpty)
                                              Text(
                                                s.description!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${s.tarifHoraire.toStringAsFixed(0)} F/h',
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      if (data.avis.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Avis récents', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...data.avis.map(
                          (a) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                              child: Text('${a.note}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            title: Text(a.auteur.isEmpty ? 'Client' : a.auteur),
                            subtitle: Text(a.commentaire ?? ''),
                          ),
                        ),
                      ],
                      const SizedBox(height: 96),
                    ],
                  ),
                ),
              ),
            ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  onPressed: () {
                    if (data.services.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ce prestataire n’a pas encore de service en ligne.')),
                      );
                      return;
                    }
                    _book(context, data.prestataire, data.services);
                  },
                  icon: const Icon(Icons.event_available_rounded),
                  label: const Text('Réserver'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          );
      },
    );
  }
}
