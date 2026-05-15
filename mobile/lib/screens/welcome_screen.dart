import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';

/// Page d’accueil « marketing » : présentation courte et accès rapide aux offres ou à la connexion.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const routeName = '/welcome';

  void _goToServices(BuildContext context) {
    Navigator.of(context).pushReplacementNamed(HomeScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 56, 24, 48),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.secondary,
                        AppColors.secondary.withValues(alpha: 0.85),
                        const Color(0xFFE07B00),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'ServiDom',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Trouvez des professionnels de confiance pour vos besoins à domicile au Togo.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: -72,
                  child: Material(
                    elevation: 6,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                    color: AppColors.surface,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (auth.isAuthenticated) ...[
                            Text(
                              'Bonjour, ${auth.user?.prenom ?? 'à vous'}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Retrouvez vos services et vos réservations en un geste.',
                              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                          ] else ...[
                            Text(
                              'Comment ça marche ?',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _FeatureRow(
                              icon: Icons.verified_user_outlined,
                              color: AppColors.primary,
                              title: 'Pros à portée de main',
                              subtitle: 'Parcourez les catégories et les quartiers.',
                            ),
                            const SizedBox(height: 12),
                            _FeatureRow(
                              icon: Icons.event_available_outlined,
                              color: AppColors.secondary,
                              title: 'Réservez en ligne',
                              subtitle: 'Créez un compte quand vous êtes prêt.',
                            ),
                            const SizedBox(height: 12),
                            _FeatureRow(
                              icon: Icons.payments_outlined,
                              color: AppColors.primary,
                              title: 'Tarifs clairs',
                              subtitle: 'Comparez les offres avant de choisir.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: auth.isAuthenticated ? 88 : 92)),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () => _goToServices(context),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Découvrir les offres'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!auth.isAuthenticated) ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(LoginScreen.routeName);
                      },
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Se connecter'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(RegisterScreen.routeName);
                        },
                        child: Text(
                          'Pas encore de compte ? Créer un compte',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed(ProfileScreen.routeName);
                      },
                      icon: const Icon(Icons.person_rounded),
                      label: const Text('Mon profil'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.2),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
