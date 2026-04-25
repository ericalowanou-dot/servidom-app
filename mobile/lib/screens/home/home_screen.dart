import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/service_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/category_icons.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../services/prestataires_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  late Future<List<CategoryModel>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _categoriesFuture = context.read<ApiService>().getCategories();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openCategory(CategoryModel c) {
    Navigator.pushNamed(
      context,
      PrestatairesScreen.routeName,
      arguments: PrestatairesArgs(category: c, quartierFilter: _search.text.trim().isEmpty ? null : _search.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ServiDom', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              auth.isAuthenticated ? 'Bonjour, ${auth.user?.prenom ?? ''}' : 'Trouvez un pro près de chez vous',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Profil',
            onPressed: () {
              if (!auth.isAuthenticated) {
                Navigator.pushNamed(context, LoginScreen.routeName);
              } else {
                Navigator.pushNamed(context, ProfileScreen.routeName);
              }
            },
            icon: Icon(auth.isAuthenticated ? Icons.person_rounded : Icons.login_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(_reload);
          await _categoriesFuture;
        },
        child: FutureBuilder<List<CategoryModel>>(
          future: _categoriesFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.error),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Impossible de charger les catégories.\nVérifiez que l’API tourne (${ApiService.baseUrl}) et que le backend est démarré.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.tonal(
                      onPressed: () => setState(_reload),
                      child: const Text('Réessayer'),
                    ),
                  ),
                ],
              );
            }
            final categories = snap.data ?? [];
            final q = _search.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? categories
                : categories.where((c) => c.nom.toLowerCase().contains(q)).toList();

            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SearchBar(
                      controller: _search,
                      hintText: 'Rechercher un service ou un quartier…',
                      leading: const Icon(Icons.search_rounded),
                      trailing: [
                        if (_search.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                      ],
                      onChanged: (_) => setState(() {}),
                      elevation: const WidgetStatePropertyAll(0.5),
                      backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
                      side: const WidgetStatePropertyAll(BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.05,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final c = filtered[index];
                        final icon = c.icone != null && c.icone!.isNotEmpty
                            ? categoryIconFromKey(c.icone)
                            : categoryIconFromName(c.nom);
                        return _CategoryCard(
                          title: c.nom,
                          icon: icon,
                          onTap: () => _openCategory(c),
                        );
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.title, required this.icon, required this.onTap});

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      elevation: 0.5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EAED)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.06),
                AppColors.secondary.withValues(alpha: 0.08),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(icon, color: AppColors.primary, size: 28),
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Voir les pros',
                      style: theme.textTheme.labelMedium?.copyWith(color: AppColors.secondary),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.secondary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
