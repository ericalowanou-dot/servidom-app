import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  static const routeName = '/admin';

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<AdminStats> _statsFuture;
  late Future<List<AdminUserRow>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final api = context.read<ApiService>();
    _statsFuture = api.getAdminStats();
    _usersFuture = api.getAdminUsers();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.user?.role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: const Center(child: Text('Accès réservé aux administrateurs.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => setState(_reload)),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(_reload);
          await Future.wait([_statsFuture, _usersFuture]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<AdminStats>(
              future: _statsFuture,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
                }
                final s = snap.data!;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _statChip('Utilisateurs', s.utilisateurs),
                        _statChip('Clients', s.clients),
                        _statChip('Prestataires', s.prestataires),
                        _statChip('Services', s.services),
                        _statChip('Réservations', s.reservations),
                        _statChip('Avis', s.avis),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text('Utilisateurs récents', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<AdminUserRow>>(
              future: _usersFuture,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text(toFrenchErrorMessage(snap.error!));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snap.data!;
                return Column(
                  children: users.map((u) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(u.nomComplet),
                        subtitle: Text('${u.role} · ${u.telephone}${u.quartier != null ? '\n${u.quartier}' : ''}'),
                        trailing: u.role == 'prestataire'
                            ? Switch(
                                value: u.estVerifie ?? false,
                                onChanged: (v) async {
                                  try {
                                    await context.read<ApiService>().setPrestataireVerifie(u.id, v);
                                    setState(_reload);
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toFrenchErrorMessage(e))));
                                  }
                                },
                              )
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

  Widget _statChip(String label, int value) {
    return Chip(
      label: Text('$label : $value'),
      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
    );
  }
}
