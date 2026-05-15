import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/service_model.dart';
import '../../services/api_service.dart';
import '../../utils/category_icons.dart';
import 'prestataire_detail_screen.dart';

class PrestatairesArgs {
  const PrestatairesArgs({required this.category, this.quartierFilter});
  final CategoryModel category;
  final String? quartierFilter;
}

class PrestatairesScreen extends StatefulWidget {
  const PrestatairesScreen({super.key, required this.category, this.quartierFilter});

  final CategoryModel category;
  final String? quartierFilter;

  static const routeName = '/prestataires';

  @override
  State<PrestatairesScreen> createState() => _PrestatairesScreenState();
}

class _PrestatairesScreenState extends State<PrestatairesScreen> {
  late Future<List<PrestataireListItem>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<ApiService>().getPrestataires(
          widget.category.id,
          quartier: widget.quartierFilter,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.category.nom),
        bottom: widget.quartierFilter != null && widget.quartierFilter!.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(28),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      'Quartier : ${widget.quartierFilter}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.onAppBarMuted),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(_load);
          await _future;
        },
        child: FutureBuilder<List<PrestataireListItem>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              final message = toFrenchErrorMessage(snap.error!);
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 100),
                  Center(child: Text(message, textAlign: TextAlign.center)),
                  const SizedBox(height: 16),
                  Center(
                    child: FilledButton.tonal(onPressed: () => setState(_load), child: const Text('Réessayer')),
                  ),
                ],
              );
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.person_search_rounded, size: 56, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Aucun prestataire pour cette catégorie pour le moment.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final p = list[i];
                return _PrestataireCard(
                  item: p,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      PrestataireDetailScreen.routeName,
                      arguments: PrestataireDetailArgs(
                        prestataireId: p.userId,
                        initialServiceId: p.serviceId,
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PrestataireCard extends StatelessWidget {
  const _PrestataireCard({required this.item, required this.onTap});

  final PrestataireListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = item.noteMoyenne;
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;
    final serviceImage = ApiService.resolveMediaUrl(item.imageUrl);
    final hasServiceImage = serviceImage.isNotEmpty;
    final fallbackIcon = item.categorieIcone != null && item.categorieIcone!.isNotEmpty
        ? categoryIconFromKey(item.categorieIcone)
        : categoryIconFromName(item.categorieNom ?? item.titreService);

    return Card(
      elevation: 0.5,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: hasServiceImage
                      ? Image.network(
                          serviceImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _placeholder(),
                        )
                      : hasPhoto
                          ? Image.network(
                              ApiService.resolveMediaUrl(item.photoUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => _placeholder(icon: fallbackIcon),
                            )
                          : _placeholder(icon: fallbackIcon),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.nomComplet,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (item.estVerifie == true)
                          const Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.titreService,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 18, color: AppColors.secondary),
                        Text(
                          note != null && note > 0 ? note.toStringAsFixed(1) : '—',
                          style: theme.textTheme.labelLarge,
                        ),
                        if (item.nombreAvis != null && item.nombreAvis! > 0) ...[
                          Text(' (${item.nombreAvis})', style: theme.textTheme.bodySmall),
                        ],
                        const Spacer(),
                        Text(
                          '${item.tarifHoraire.toStringAsFixed(0)} FCFA/h',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.localisation,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder({IconData icon = Icons.person_rounded}) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(icon, size: 40, color: AppColors.primary.withValues(alpha: 0.5)),
    );
  }
}
