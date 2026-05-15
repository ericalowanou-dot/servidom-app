import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/service_model.dart';
import '../../services/api_service.dart';
import 'edit_service_screen.dart';

class MyServicesScreen extends StatefulWidget {
  const MyServicesScreen({super.key});

  static const routeName = '/prestataire/mes-services';

  @override
  State<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends State<MyServicesScreen> {
  late Future<List<ServiceModel>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<ApiService>().getMesServices();
  }

  Future<void> _delete(ServiceModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce service ?'),
        content: Text('« ${s.titre} » sera définitivement supprimé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiService>().deleteService(s.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service supprimé.')));
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toFrenchErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mes services')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(_reload);
          await _future;
        },
        child: FutureBuilder<List<ServiceModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 200,
                    child: Center(child: Text(toFrenchErrorMessage(snap.error!))),
                  ),
                ],
              );
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('Aucun service publié.')),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final s = list[i];
                final img = s.imageUrl != null && s.imageUrl!.isNotEmpty ? ApiService.resolveMediaUrl(s.imageUrl) : null;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: img != null && img.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(img, width: 56, height: 56, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.work_outline)),
                          )
                        : const CircleAvatar(child: Icon(Icons.work_outline)),
                    title: Text(s.titre, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${s.categorieNom ?? ''} · ${s.tarifHoraire.toStringAsFixed(0)} F/h\n'
                      '${s.disponible == false ? 'Indisponible' : 'Disponible'}',
                      maxLines: 2,
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') {
                          final changed = await Navigator.pushNamed(context, EditServiceScreen.routeName, arguments: s);
                          if (changed == true && mounted) setState(_reload);
                        } else if (v == 'delete') {
                          await _delete(s);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Modifier')),
                        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
