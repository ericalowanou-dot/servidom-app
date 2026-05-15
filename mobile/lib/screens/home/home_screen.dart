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

enum _CategorySort { apiOrder, nameAsc }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _scrollController = ScrollController();
  final GlobalKey _servicesSectionKey = GlobalKey();
  _CategorySort _sort = _CategorySort.apiOrder;
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
    _scrollController.dispose();
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

  List<CategoryModel> _sorted(List<CategoryModel> list) {
    switch (_sort) {
      case _CategorySort.apiOrder:
        return List<CategoryModel>.from(list);
      case _CategorySort.nameAsc:
        final copy = List<CategoryModel>.from(list);
        copy.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
        return copy;
    }
  }

  void _scrollToServicesSection() {
    final ctx = _servicesSectionKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  Future<void> _showSortSheet() async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Tri des catégories',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                RadioListTile<_CategorySort>(
                  title: const Text('Ordre par défaut'),
                  subtitle: Text(
                    'Comme renvoyé par le serveur',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  value: _CategorySort.apiOrder,
                  groupValue: _sort,
                  onChanged: (v) {
                    Navigator.pop(ctx);
                    if (v != null) setState(() => _sort = v);
                  },
                ),
                RadioListTile<_CategorySort>(
                  title: const Text('Nom (A → Z)'),
                  value: _CategorySort.nameAsc,
                  groupValue: _sort,
                  onChanged: (v) {
                    Navigator.pop(ctx);
                    if (v != null) setState(() => _sort = v);
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Text(
                    'Pour filtrer par quartier, utilisez la barre de recherche : le terme sera appliqué lorsque vous ouvrirez une catégorie.',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      // [REDESIGN] AppBar retirée — en-tête portée par SliverAppBar dans le CustomScrollView
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
              // [REDESIGN] État d'erreur — présentation modernisée
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.65,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Connexion impossible',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Vérifiez votre connexion et que l’API est accessible avant de réessayer.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.tonal(
                            onPressed: () => setState(_reload),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.refresh_rounded),
                                SizedBox(width: 8),
                                Text('Réessayer'),
                              ],
                            ),
                          ),
                        ],
                      ),
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
            final displayList = _sorted(filtered);
            final searchYieldsNothing = q.isNotEmpty && filtered.isEmpty && categories.isNotEmpty;

            return CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // [REDESIGN] SliverAppBar avec dégradé et accueil personnalisé
                SliverAppBar(
                  expandedHeight: 130,
                  floating: false,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          if (!auth.isAuthenticated) {
                            Navigator.pushNamed(context, LoginScreen.routeName);
                          } else {
                            Navigator.pushNamed(context, ProfileScreen.routeName);
                          }
                        },
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white24,
                          child: Icon(
                            auth.isAuthenticated ? Icons.person_rounded : Icons.login_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, Color(0xFFE07B00)],
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 0, 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.isAuthenticated
                                      ? 'Bonjour, ${auth.user?.prenom ?? ''} 👋'
                                      : 'Bienvenue sur ServiDom 👋',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'Quel service cherchez-vous ?',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // [REDESIGN] SearchBar flottante
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: SearchBar(
                      controller: _search,
                      hintText: 'Service, quartier…',
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
                      leading: Icon(Icons.search_rounded, color: AppColors.primary),
                      trailing: [
                        if (_search.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          )
                        else
                          IconButton(
                            tooltip: 'Tri et aide',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            icon: Icon(Icons.tune_rounded, color: AppColors.secondary, size: 20),
                            onPressed: _showSortSheet,
                          ),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                // [REDESIGN] En-tête de section catégories
                SliverToBoxAdapter(
                  key: _servicesSectionKey,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nos services',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                        InkWell(
                          onTap: _scrollToServicesSection,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Text(
                              'Voir tout',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (searchYieldsNothing)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Aucun service ne correspond à votre recherche',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Essayez un autre mot-clé ou effacez la recherche pour tout afficher.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.tonal(
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.clear_all_rounded),
                                  SizedBox(width: 8),
                                  Text('Effacer la recherche'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
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
                          final c = displayList[index];
                          final icon = c.icone != null && c.icone!.isNotEmpty
                              ? categoryIconFromKey(c.icone)
                              : categoryIconFromName(c.nom);
                          return _CategoryCard(
                            title: c.nom,
                            icon: icon,
                            onTap: () => _openCategory(c),
                          );
                        },
                        childCount: displayList.length,
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

// [REDESIGN] Carte catégorie avec animation au press (ScaleTransition)
class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.title, required this.icon, required this.onTap});

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_pressController);

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Material(
        color: AppColors.surface,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTapDown: (_) => _pressController.forward(),
          onTapUp: (_) => _pressController.reverse(),
          onTapCancel: () => _pressController.reverse(),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: AppColors.secondary, size: 26),
                ),
                const Spacer(),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Voir les pros',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.secondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
