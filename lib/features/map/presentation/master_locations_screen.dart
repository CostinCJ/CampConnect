// lib/features/map/presentation/master_locations_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';

class MasterLocationsScreen extends ConsumerWidget {
  const MasterLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final locationsAsync = ref.watch(masterLocationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mapLocations),
      ),
      body: locationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(l10n.somethingWentWrong),
        ),
        data: (locations) {
          if (locations.isEmpty) {
            return EmptyState(
              icon: Icons.location_off,
              title: l10n.noMasterLocations,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: locations.length,
            itemBuilder: (context, index) {
              final location = locations[index];
              return _LocationCard(location: location);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/guide/settings/locations/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LocationCard extends ConsumerWidget {
  final Location location;

  const _LocationCard({required this.location});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () =>
            context.push('/guide/settings/locations/knowledge', extra: location),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Optional photo header
            if (location.photoUrl != null)
              SizedBox(
                height: 140,
                child: CachedNetworkImage(
                  imageUrl: location.photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),

            // Info row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Category icon
                  Icon(
                    location.category.icon,
                    color: location.category.color,
                    size: 28,
                  ),
                  const SizedBox(width: 12),

                  // Name + description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (location.description.isNotEmpty)
                          Text(
                            location.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Knowledge base indicator
                  if (!location.knowledgeBase.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.menu_book,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),

                  // Edit button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: l10n.editLocation,
                    onPressed: () => context.push(
                      '/guide/settings/locations/edit',
                      extra: location,
                    ),
                  ),

                  // Delete button
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.onSurfaceVariant),
                    tooltip: l10n.deleteLocation,
                    onPressed: () =>
                        _confirmDelete(context, ref, location, l10n),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Location location,
    AppL10n l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteLocation),
        content: Text(l10n.deleteLocationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
              style: destructiveFilledStyle(Theme.of(ctx)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.delete)),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    final orgId = ref.read(appUserProvider).valueOrNull?.orgId;
    if (orgId == null) return;

    try {
      // Delete photo from Storage if present
      if (location.photoUrl != null) {
        await ref
            .read(imageUploadServiceProvider)
            .deleteImage(location.photoUrl!);
      }

      // Delete Firestore document
      await ref
          .read(locationRepositoryProvider)
          .deleteLocation(orgId, location.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationDeleted)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.somethingWentWrong)),
        );
      }
    }
  }
}
