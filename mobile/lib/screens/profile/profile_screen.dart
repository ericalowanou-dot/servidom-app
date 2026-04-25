import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/reservation_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../prestataire/add_service_screen.dart';

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
                      backgroundImage:
                          (u.photoUrl != null && u.photoUrl!.isNotEmpty) ? NetworkImage(u.photoUrl!) : null,
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
              FilledButton.icon(
                onPressed: () async {
                  final created = await Navigator.pushNamed(
                    context,
                    AddServiceScreen.routeName,
                  );
                  if (!context.mounted) return;
                  if (created == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Service ajouté.')),
                    );
                  }
                },
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('Ajouter un service'),
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
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(r.serviceTitre ?? 'Service'),
                        subtitle: Text(
                          '${r.dateIntervention.day}/${r.dateIntervention.month}/${r.dateIntervention.year} · ${r.statutLabel}'
                          '${avec != null && avec.isNotEmpty ? '\n$avec' : ''}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: r.montantTotal != null
                            ? Text('${r.montantTotal!.toStringAsFixed(0)} F', style: theme.textTheme.labelLarge)
                            : null,
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
