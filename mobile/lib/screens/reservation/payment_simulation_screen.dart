import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/reservation_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class PaymentSimulationArgs {
  const PaymentSimulationArgs({required this.reservation});
  final ReservationModel reservation;
}

class PaymentSimulationScreen extends StatefulWidget {
  const PaymentSimulationScreen({super.key, required this.reservation});

  final ReservationModel reservation;
  static const routeName = '/payment-simulation';

  @override
  State<PaymentSimulationScreen> createState() => _PaymentSimulationScreenState();
}

class _PaymentSimulationScreenState extends State<PaymentSimulationScreen> {
  String _mode = 'flooz';
  late final TextEditingController _tel;
  bool _processing = false;
  PaymentSimulationResult? _result;

  @override
  void initState() {
    super.initState();
    _tel = TextEditingController(text: context.read<AuthProvider>().user?.telephone ?? '');
  }

  @override
  void dispose() {
    _tel.dispose();
    super.dispose();
  }

  Future<void> _payer() async {
    if (_tel.text.trim().length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez un numéro Mobile Money valide.')),
      );
      return;
    }
    setState(() {
      _processing = true;
      _result = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    try {
      final result = await context.read<ApiService>().simulerPaiement(
            reservationId: widget.reservation.id,
            modePaiement: _mode,
            telephone: _tel.text.trim(),
          );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toFrenchErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final montant = widget.reservation.montantTotal ?? 0;

    if (_result != null) {
      final r = _result!;
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Paiement réussi')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.check_circle_rounded, size: 80, color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Paiement simulé', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Ceci est une démonstration : aucun débit réel n’a été effectué.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Montant', '${montant.toStringAsFixed(0)} FCFA'),
                      _row('Opérateur', r.reservation.modePaiementLabel.isNotEmpty ? r.reservation.modePaiementLabel : r.modePaiement),
                      _row('Référence', r.referencePaiement),
                      _row('Téléphone', _tel.text.trim()),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.pop(context, r.reservation),
                child: const Text('Retour à la réservation'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Paiement Mobile Money')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: AppColors.secondary.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.secondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mode simulation : aucun argent ne sera débité. Utile pour la démo du séminaire.',
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Montant à payer', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '${montant.toStringAsFixed(0)} FCFA',
              style: theme.textTheme.headlineMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text('Choisir l’opérateur', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'flooz', label: Text('Flooz'), icon: Icon(Icons.phone_android)),
                ButtonSegment(value: 'tmoney', label: Text('T-Money'), icon: Icon(Icons.payments_outlined)),
                ButtonSegment(value: 'mix', label: Text('Mix'), icon: Icon(Icons.account_balance_wallet_outlined)),
              ],
              selected: {_mode},
              onSelectionChanged: _processing ? null : (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro Mobile Money',
                prefixIcon: Icon(Icons.phone_rounded),
                hintText: '90 XX XX XX',
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _processing ? null : _payer,
              icon: _processing
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.lock_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_processing ? 'Traitement en cours…' : 'Confirmer le paiement simulé'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
