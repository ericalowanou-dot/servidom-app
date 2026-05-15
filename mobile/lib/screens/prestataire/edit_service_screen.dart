import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/service_model.dart';
import '../../services/api_service.dart';

class EditServiceScreen extends StatefulWidget {
  const EditServiceScreen({super.key, required this.service});

  final ServiceModel service;
  static const routeName = '/prestataire/edit-service';

  @override
  State<EditServiceScreen> createState() => _EditServiceScreenState();
}

class _EditServiceScreenState extends State<EditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titre;
  late final TextEditingController _description;
  late final TextEditingController _tarif;
  Future<List<CategoryModel>>? _categoriesFuture;
  int? _categorieId;
  bool _disponible = true;
  bool _submitting = false;
  final _picker = ImagePicker();
  XFile? _newImage;
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _titre = TextEditingController(text: s.titre);
    _description = TextEditingController(text: s.description ?? '');
    _tarif = TextEditingController(text: s.tarifHoraire.toStringAsFixed(0));
    _categorieId = s.categorieId;
    _disponible = s.disponible ?? true;
    _categoriesFuture = context.read<ApiService>().getCategories();
  }

  @override
  void dispose() {
    _titre.dispose();
    _description.dispose();
    _tarif.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1600);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _newImage = image;
      _previewBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categorieId == null) return;
    final tarif = double.tryParse(_tarif.text.trim().replaceAll(',', '.'));
    if (tarif == null || tarif <= 0) return;

    setState(() => _submitting = true);
    try {
      await context.read<ApiService>().updateService(
            id: widget.service.id,
            categorieId: _categorieId,
            titre: _titre.text.trim(),
            description: _description.text.trim(),
            tarifHoraire: tarif,
            disponible: _disponible,
            imageFile: _newImage,
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
    final existingImg = widget.service.imageUrl != null && widget.service.imageUrl!.isNotEmpty
        ? ApiService.resolveMediaUrl(widget.service.imageUrl)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Modifier le service')),
      body: FutureBuilder<List<CategoryModel>>(
        future: _categoriesFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snap.data!;
          _categorieId ??= widget.service.categorieId;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_previewBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(_previewBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
                    )
                  else if (existingImg != null && existingImg.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(existingImg, height: 160, width: double.infinity, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Changer la photo'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _categorieId,
                    decoration: const InputDecoration(labelText: 'Catégorie', prefixIcon: Icon(Icons.category_outlined)),
                    items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nom))).toList(),
                    onChanged: (v) => setState(() => _categorieId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titre,
                    decoration: const InputDecoration(labelText: 'Titre', prefixIcon: Icon(Icons.work_outline)),
                    validator: (v) => (v == null || v.trim().length < 3) ? 'Titre requis' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tarif,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Tarif horaire (FCFA)', prefixIcon: Icon(Icons.payments_outlined)),
                    validator: (v) {
                      final p = double.tryParse((v ?? '').replaceAll(',', '.'));
                      return (p == null || p <= 0) ? 'Tarif invalide' : null;
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Service disponible'),
                    value: _disponible,
                    onChanged: _submitting ? null : (v) => setState(() => _disponible = v),
                  ),
                  const SizedBox(height: 20),
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
          );
        },
      ),
    );
  }
}
