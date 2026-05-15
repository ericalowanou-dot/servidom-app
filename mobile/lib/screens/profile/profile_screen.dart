import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/reservation_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../admin/admin_screen.dart';
import '../auth/login_screen.dart';
import '../prestataire/add_service_screen.dart';
import '../prestataire/my_services_screen.dart';
import '../messages/conversations_screen.dart';
import '../reservation/reservation_detail_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const routeName = '/profile';

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<List<ReservationModel>> _resaFuture;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  void _load() {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      _resaFuture = context.read<ApiService>().getMesReservations();
    } else {
      _resaFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final u = auth.user;

    if (!auth.isAuthenticated || u == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline_rounded, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text('Connectez-vous pour voir votre profil et vos réservations.'),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, LoginScreen.routeName),
                  child: const Text('Se connecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon profil'),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            onPressed: () async {
              final updated = await Navigator.pushNamed(context, EditProfileScreen.routeName);
              if (updated == true && context.mounted) {
                await auth.refreshProfile();
                setState(_load);
              }
            },
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
              }
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await auth.refreshProfile();
          setState(_load);
          await _resaFuture;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      backgroundImage: (u.photoUrl != null && u.photoUrl!.isNotEmpty)
                          ? NetworkImage(ApiService.resolveMediaUrl(u.photoUrl))
                          : null,
                      child: (u.photoUrl == null || u.photoUrl!.isEmpty)
                          ? Text(
                              u.prenom.isNotEmpty ? u.prenom[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.nomComplet, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(u.telephone, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(u.role == 'prestataire' ? 'Prestataire' : 'Client'),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (u.quartier != null && u.quartier!.isNotEmpty)
                            Text(u.quartier!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (u.role == 'prestataire') ...[
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final created = await Navigator.pushNamed(context, AddServiceScreen.routeName);
                        if (!context.mounted) return;
                        if (created == true) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service ajouté.')));
                          setState(_load);
                        }
                      },
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text('Ajouter'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, MyServicesScreen.routeName),
                      icon: const Icon(Icons.list_alt_rounded),
                      label: const Text('Mes services'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            if (u.role == 'admin') ...[
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, AdminScreen.routeName),
                icon: const Icon(Icons.admin_panel_settings_rounded),
                label: const Text('Tableau de bord admin'),
              ),
              const SizedBox(height: 20),
            ],
            if (u.role == 'client' || u.role == 'prestataire') ...[
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, ConversationsScreen.routeName),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Mes messages'),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              u.role == 'client' ? 'Mes réservations' : 'Demandes reçues',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<ReservationModel>>(
              future: _resaFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Text(snap.error.toString());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Aucune réservation pour le moment.'),
                  );
                }
                return Column(
                  children: list.map((r) {
                    final avec = r.autrePartieNom;
                    final tel = r.telephoneContact;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () async {
                          final changed = await Navigator.pushNamed(
                            context,
                            ReservationDetailScreen.routeName,
                            arguments: ReservationDetailArgs(reservation: r),
                          );
                          if (changed == true && context.mounted) setState(_load);
                        },
                        title: Text(r.serviceTitre ?? 'Service'),
                        subtitle: Text(
                          '${r.dateIntervention.day}/${r.dateIntervention.month}/${r.dateIntervention.year} · ${r.statutLabel}'
                          '${avec != null && avec.isNotEmpty ? '\n$avec' : ''}'
                          '${tel != null && tel.isNotEmpty ? '\n$tel' : ''}',
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (r.montantTotal != null)
                              Text('${r.montantTotal!.toStringAsFixed(0)} F', style: theme.textTheme.labelLarge),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
