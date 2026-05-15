import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

class ReservationArgs {
  const ReservationArgs({
    required this.prestataireId,
    required this.serviceId,
    required this.prestataireNom,
    required this.serviceTitre,
    required this.tarifHoraire,
  });

  final int prestataireId;
  final int serviceId;
  final String prestataireNom;
  final String serviceTitre;
  final double tarifHoraire;
}

class ReservationScreen extends StatefulWidget {
  const ReservationScreen({
    super.key,
    required this.prestataireId,
    required this.serviceId,
    required this.prestataireNom,
    required this.serviceTitre,
    required this.tarifHoraire,
  });

  final int prestataireId;
  final int serviceId;
  final String prestataireNom;
  final String serviceTitre;
  final double tarifHoraire;

  static const routeName = '/reservation';

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adresse = TextEditingController();
  final _description = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  double _duree = 2;
  bool _submitting = false;
  bool _locating = false;

  Future<void> _useGpsForAddress() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autorisez la localisation pour utiliser le GPS.')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _adresse.text = 'GPS: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Coordonnées GPS ajoutées à l’adresse. Complétez si besoin.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’obtenir la position.')),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void dispose() {
    _adresse.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _time = t);
  }

  DateTime? _combine() {
    final d = _date;
    final t = _time;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final when = _combine();
    if (when == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez la date et l’heure d’intervention.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await context.read<ApiService>().createReservation(
            prestataireId: widget.prestataireId,
            serviceId: widget.serviceId,
            dateIntervention: when,
            dureeHeures: _duree,
            adresseIntervention: _adresse.text.trim(),
            descriptionBesoin: _description.text.trim().isEmpty ? null : _description.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réservation envoyée avec succès !')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toFrenchErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final estime = widget.tarifHoraire * _duree;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Réservation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.prestataireNom, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(widget.serviceTitre, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text(
                        'Tarif : ${widget.tarifHoraire.toStringAsFixed(0)} FCFA / h',
                        style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Date d’intervention', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today_rounded),
                      label: Text(_date == null ? 'Choisir' : '${_date!.day}/${_date!.month}/${_date!.year}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_rounded),
                      label: Text(_time == null ? 'Heure' : _time!.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Durée : ${_duree.toStringAsFixed(1)} h', style: theme.textTheme.titleSmall),
              Slider(
                value: _duree,
                min: 1,
                max: 8,
                divisions: 14,
                label: '${_duree.toStringAsFixed(1)} h',
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _duree = v),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimation : ${estime.toStringAsFixed(0)} FCFA',
                style: theme.textTheme.titleSmall?.copyWith(color: AppColors.secondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _adresse,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Adresse d’intervention',
                  hintText: 'Quartier, rue, repères…',
                  prefixIcon: Icon(Icons.home_work_outlined),
                ),
                validator: (v) => (v == null || v.trim().length < 5) ? 'Adresse plus précise requise' : null,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _locating || _submitting ? null : _useGpsForAddress,
                icon: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded),
                label: const Text('Ajouter ma position GPS'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description du besoin (optionnel)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmer la réservation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
