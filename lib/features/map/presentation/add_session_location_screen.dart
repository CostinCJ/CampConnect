// lib/features/map/presentation/add_session_location_screen.dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/features/map/domain/session_location.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class AddSessionLocationScreen extends ConsumerStatefulWidget {
  const AddSessionLocationScreen({super.key});

  @override
  ConsumerState<AddSessionLocationScreen> createState() =>
      _AddSessionLocationScreenState();
}

class _AddSessionLocationScreenState
    extends ConsumerState<AddSessionLocationScreen> {
  Location? _selectedLocation;
  XFile? _pickedImage;
  bool _isSaving = false;

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

  Future<void> _saveSessionLocation() async {
    final l10n = AppLocalizations.of(context);
    final campId = ref.read(activeCampIdProvider);
    final appUser = ref.read(appUserProvider).valueOrNull;

    if (_selectedLocation == null || _pickedImage == null) return;
    if (campId == null || appUser == null) return;

    setState(() => _isSaving = true);

    try {
      // Check if already in session
      final alreadyInSession = await ref
          .read(sessionLocationRepositoryProvider)
          .isLocationInSession(campId, _selectedLocation!.id);

      if (alreadyInSession) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.locationAlreadyInSession)),
          );
        }
        return;
      }

      // Generate a unique ID for the storage path
      final sessionLocId =
          DateTime.now().millisecondsSinceEpoch.toString();

      // Upload group photo
      final photoUrl =
          await ref.read(imageUploadServiceProvider).uploadImage(
        imageFile: _pickedImage!,
        storagePath:
            '${AppConstants.campsCollection}/$campId/${AppConstants.sessionLocationsSubcollection}/$sessionLocId/group_photo.jpg',
      );

      // Create and save session location
      final sessionLocation = SessionLocation(
        id: '',
        masterLocationId: _selectedLocation!.id,
        photoUrl: photoUrl,
        addedBy: appUser.uid,
        visitedAt: DateTime.now(),
      );

      await ref
          .read(sessionLocationRepositoryProvider)
          .addSessionLocation(campId, sessionLocation);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationAddedToSession)),
        );
        Navigator.pop(context);
      }
    } catch (_) {
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
    final locationsAsync = ref.watch(masterLocationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addToSession),
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
          : locationsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(l10n.somethingWentWrong),
              ),
              data: (locations) {
                if (locations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noMasterLocations,
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Section header: select location
                    Text(
                      l10n.selectLocation,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),

                    // Location cards
                    ...locations.map((location) =>
                        _buildLocationCard(location, theme)),

                    // Photo picker section (visible once a location is selected)
                    if (_selectedLocation != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        l10n.groupPhoto,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.groupPhotoHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            image: _pickedImage != null
                                ? DecorationImage(
                                    image:
                                        FileImage(File(_pickedImage!.path)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _pickedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo,
                                      size: 48,
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.groupPhoto,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save button
                      FilledButton.icon(
                        onPressed:
                            _pickedImage != null ? _saveSessionLocation : null,
                        icon: const Icon(Icons.add_location_alt),
                        label: Text(l10n.addToSession),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Widget _buildLocationCard(Location location, ThemeData theme) {
    final isSelected = _selectedLocation?.id == location.id;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLocation = location;
            // Reset picked image when location changes
            _pickedImage = null;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Location photo or category icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: location.photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: location.photoUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color:
                                theme.colorScheme.surfaceContainerHighest,
                            child: Icon(location.category.icon,
                                color: location.category.color),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color:
                                theme.colorScheme.surfaceContainerHighest,
                            child: Icon(location.category.icon,
                                color: location.category.color),
                          ),
                        )
                      : Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(location.category.icon,
                              color: location.category.color),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.onPrimaryContainer
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location.description.isNotEmpty)
                      Text(
                        location.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Check icon when selected
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
