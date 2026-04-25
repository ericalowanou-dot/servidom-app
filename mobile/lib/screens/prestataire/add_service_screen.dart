import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/service_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  static const routeName = '/prestataire/add-service';

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titreController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tarifController = TextEditingController();

  Future<List<CategoryModel>>? _categoriesFuture;
  int? _selectedCategorieId;
  bool _submitting = false;
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = context.read<ApiService>().getCategories();
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _tarifController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _previewBytes = bytes;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de sélectionner l’image.')),
      );
    }
  }

  Future<void> _showImageSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choisir depuis la galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Prendre une photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategorieId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une catégorie.')),
      );
      return;
    }
    final tarif = double.tryParse(_tarifController.text.trim().replaceAll(',', '.'));
    if (tarif == null || tarif <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarif horaire invalide.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<ApiService>().createService(
            categorieId: _selectedCategorieId!,
            titre: _titreController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            tarifHoraire: tarif,
            imageFile: _selectedImage,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service ajouté avec succès.')),
      );
      Navigator.of(context).pop(true);
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
    final auth = context.watch<AuthProvider>();
    final isPrestataire = auth.user?.role == 'prestataire';

    if (!isPrestataire) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ajouter un service')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Cette section est réservée aux prestataires.'),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ajouter un service')),
      body: FutureBuilder<List<CategoryModel>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = toFrenchErrorMessage(snapshot.error!);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: () => setState(() {
                        _categoriesFuture = context.read<ApiService>().getCategories();
                      }),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Aucune catégorie active trouvée.'),
              ),
            );
          }
          _selectedCategorieId ??= categories.first.id;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _showImageSourcePicker,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_selectedImage == null ? 'Ajouter une photo' : 'Changer la photo'),
                  ),
                  if (_previewBytes != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Image.memory(
                          _previewBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _submitting
                          ? null
                          : () => setState(() {
                                _selectedImage = null;
                                _previewBytes = null;
                              }),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Retirer la photo'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategorieId,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c.id,
                            child: Text(c.nom),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCategorieId = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titreController,
                    decoration: const InputDecoration(
                      labelText: 'Titre du service',
                      prefixIcon: Icon(Icons.work_outline_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().length < 3) {
                        return 'Titre requis (3 caractères minimum)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tarifController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Tarif horaire (FCFA)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (value) {
                      final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Entrez un tarif valide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_submitting ? 'Enregistrement...' : 'Enregistrer'),
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
