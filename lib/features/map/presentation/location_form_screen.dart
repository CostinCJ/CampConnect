// lib/features/map/presentation/location_form_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class LocationFormScreen extends ConsumerStatefulWidget {
  /// Pass an existing location for edit mode, or null for add mode.
  final Location? existingLocation;

  const LocationFormScreen({super.key, this.existingLocation});

  @override
  ConsumerState<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends ConsumerState<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  LocationCategory _selectedCategory = LocationCategory.nature;
  XFile? _pickedImage;
  bool _isSaving = false;

  bool get _isEditMode => widget.existingLocation != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final loc = widget.existingLocation!;
      _nameController.text = loc.name;
      _descriptionController.text = loc.description;
      _latController.text = loc.latitude.toString();
      _lngController.text = loc.longitude.toString();
      _selectedCategory = loc.category;
    } else {
      _fillGpsCoordinates();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _fillGpsCoordinates() async {
    // Default to camp coordinates first
    _latController.text = AppConstants.defaultCampLatitude.toString();
    _lngController.text = AppConstants.defaultCampLongitude.toString();

    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission granted = permission;
      if (granted == LocationPermission.denied) {
        granted = await Geolocator.requestPermission();
      }

      if (granted == LocationPermission.denied ||
          granted == LocationPermission.deniedForever) {
        return; // Keep camp defaults
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _latController.text = position.latitude.toString();
          _lngController.text = position.longitude.toString();
        });
      }
    } catch (_) {
      // Keep camp defaults on error
    }
  }

  Future<void> _pickImage() async {
    final l10n = AppLocalizations.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.chooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 85);
    if (image != null) {
      setState(() => _pickedImage = image);
    }
  }

  Future<void> _saveLocation() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    final appUser = ref.read(appUserProvider).valueOrNull;

    if (appUser == null) return;

    setState(() => _isSaving = true);

    try {
      String? photoUrl = widget.existingLocation?.photoUrl;

      // Determine the location ID for the storage path
      final locationId = _isEditMode
          ? widget.existingLocation!.id
          : DateTime.now().millisecondsSinceEpoch.toString();

      // Upload new photo if picked
      if (_pickedImage != null) {
        // Delete old photo if editing
        if (_isEditMode && photoUrl != null) {
          await ref.read(imageUploadServiceProvider).deleteImage(photoUrl);
        }

        photoUrl = await ref.read(imageUploadServiceProvider).uploadImage(
          imageFile: _pickedImage!,
          storagePath:
              '${AppConstants.locationsCollection}/$locationId/photo.jpg',
        );
      }

      final location = Location(
        id: _isEditMode ? widget.existingLocation!.id : '',
        name: _nameController.text.trim(),
        latitude: double.tryParse(_latController.text) ??
            AppConstants.defaultCampLatitude,
        longitude: double.tryParse(_lngController.text) ??
            AppConstants.defaultCampLongitude,
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        photoUrl: photoUrl,
        knowledgeBase:
            widget.existingLocation?.knowledgeBase ?? const KnowledgeBase(),
        createdBy: appUser.uid,
        timestamp: DateTime.now(),
      );

      if (_isEditMode) {
        await ref.read(locationRepositoryProvider).updateLocation(location);
      } else {
        await ref.read(locationRepositoryProvider).addLocation(location);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isEditMode ? l10n.locationUpdated : l10n.locationCreated),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? l10n.editLocation : l10n.addLocation),
      ),
      body: _isSaving
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l10n.savingLocation),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Photo
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        image: _pickedImage != null
                            ? DecorationImage(
                                image: FileImage(File(_pickedImage!.path)),
                                fit: BoxFit.cover,
                              )
                            : (_isEditMode &&
                                    widget.existingLocation?.photoUrl != null)
                                ? DecorationImage(
                                    image: NetworkImage(
                                        widget.existingLocation!.photoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                      ),
                      child: (_pickedImage == null &&
                              !(_isEditMode &&
                                  widget.existingLocation?.photoUrl != null))
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo,
                                    size: 48,
                                    color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(height: 8),
                                Text(l10n.locationPhoto,
                                    style: theme.textTheme.bodyMedium),
                              ],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.locationName,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.enterLocationName
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Category
                  DropdownButtonFormField<LocationCategory>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: l10n.locationCategory,
                      border: const OutlineInputBorder(),
                    ),
                    items: LocationCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(cat.icon, color: cat.color, size: 20),
                            const SizedBox(width: 8),
                            Text(_categoryLabel(l10n, cat)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedCategory = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Coordinates
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lngController,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: l10n.locationDescription,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.enterDescription
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  FilledButton.icon(
                    onPressed: _saveLocation,
                    icon: const Icon(Icons.save),
                    label: Text(l10n.saveLocation),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, LocationCategory cat) {
    switch (cat) {
      case LocationCategory.nature:
        return l10n.categoryNature;
      case LocationCategory.historical:
        return l10n.categoryHistorical;
    }
  }
}
