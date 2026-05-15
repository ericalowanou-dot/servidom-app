import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static const routeName = '/profile/edit';

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _prenom;
  late final TextEditingController _email;
  late final TextEditingController _quartier;
  final _picker = ImagePicker();
  XFile? _photoFile;
  Uint8List? _previewBytes;
  double? _latitude;
  double? _longitude;
  bool _submitting = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user!;
    _nom = TextEditingController(text: u.nom);
    _prenom = TextEditingController(text: u.prenom);
    _email = TextEditingController(text: u.email ?? '');
    _quartier = TextEditingController(text: u.quartier ?? '');
    _latitude = u.latitude;
    _longitude = u.longitude;
  }

  @override
  void dispose() {
    _nom.dispose();
    _prenom.dispose();
    _email.dispose();
    _quartier.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1200);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photoFile = image;
      _previewBytes = bytes;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autorisez la localisation dans les paramètres.')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Position enregistrée (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})')),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<AuthProvider>().updateProfile(
            nom: _nom.text.trim(),
            prenom: _prenom.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            quartier: _quartier.text.trim().isEmpty ? null : _quartier.text.trim(),
            latitude: _latitude,
            longitude: _longitude,
            photoFile: _photoFile,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toFrenchErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.user!;
    final photoUrl = u.photoUrl != null && u.photoUrl!.isNotEmpty ? ApiService.resolveMediaUrl(u.photoUrl) : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      backgroundImage: _previewBytes != null
                          ? MemoryImage(_previewBytes!)
                          : (photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null),
                      child: _previewBytes == null && (photoUrl == null || photoUrl.isEmpty)
                          ? Text(u.prenom.isNotEmpty ? u.prenom[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 36, color: AppColors.primary, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: IconButton.filled(
                        onPressed: _submitting ? null : _pickPhoto,
                        icon: const Icon(Icons.camera_alt_rounded, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _prenom,
                decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Prénom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nom,
                decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (optionnel)', prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quartier,
                decoration: const InputDecoration(labelText: 'Quartier', prefixIcon: Icon(Icons.location_on_outlined)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _locating || _submitting ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location_rounded),
                label: Text(_latitude != null ? 'Position GPS enregistrée' : 'Utiliser ma position GPS'),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _save,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(_submitting ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
