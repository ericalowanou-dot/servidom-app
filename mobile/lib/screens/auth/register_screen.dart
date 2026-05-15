import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../profile/profile_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  static const routeName = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _tel = TextEditingController();
  final _pass = TextEditingController();
  final _quartier = TextEditingController();
  bool _obscure = true;
  String _role = 'client';

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _tel.dispose();
    _pass.dispose();
    _quartier.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    try {
      await auth.register(
        nom: _nom.text.trim(),
        prenom: _prenom.text.trim(),
        telephone: _tel.text.trim(),
        motDePasse: _pass.text,
        role: _role,
        quartier: _quartier.text.trim().isEmpty ? null : _quartier.text.trim(),
      );
      if (!mounted) return;
      final role = auth.user?.role;
      final route = role == 'prestataire' ? ProfileScreen.routeName : '/home';
      Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toFrenchErrorMessage(e)), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nom,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _prenom,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Prénom',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tel,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 8) return 'Numéro valide requis';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pass,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 4) return 'Au moins 4 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quartier,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Quartier (optionnel)',
                    hintText: 'Ex. Bè, Tokoin…',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Je suis', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'client', label: Text('Client'), icon: Icon(Icons.person)),
                    ButtonSegment(
                      value: 'prestataire',
                      label: Text('Prestataire'),
                      icon: Icon(Icons.handyman_outlined),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: auth.loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                  ),
                  child: auth.loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('S’inscrire'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Déjà un compte ? Se connecter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
