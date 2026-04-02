import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import '../domain/journal_entry.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  final JournalEntry? existingEntry;

  const JournalEditorScreen({super.key, this.existingEntry});

  @override
  ConsumerState<JournalEditorScreen> createState() =>
      _JournalEditorScreenState();
}

class _JournalEditorScreenState extends ConsumerState<JournalEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  late DateTime _selectedDate;
  final List<String> _photos = [];
  // Track photos from the existing entry so we know which ones to keep
  late final List<String> _originalPhotos;
  // Track newly added photos so we can clean up orphans on discard
  final List<String> _newlyAddedPhotos = [];
  bool _saving = false;
  bool _saved = false;

  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.existingEntry!.title;
      _bodyController.text = widget.existingEntry!.body;
      _selectedDate = widget.existingEntry!.date;
      _photos.addAll(widget.existingEntry!.photos);
      _originalPhotos = List.from(widget.existingEntry!.photos);
    } else {
      _selectedDate = DateTime.now();
      _originalPhotos = [];
    }
  }

  @override
  void dispose() {
    // Clean up orphaned photos if user discarded without saving
    if (!_saved) {
      _cleanupOrphanedPhotos();
    }
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _cleanupOrphanedPhotos() {
    for (final path in _newlyAddedPhotos) {
      // Only delete if the photo is still in _photos (wasn't already removed)
      // and wasn't saved as part of an entry
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {
        // Best effort cleanup
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;

    final notifier = ref.read(journalProvider.notifier);
    final savedPath = await notifier.savePhoto(picked.path);
    setState(() {
      _photos.add(savedPath);
      _newlyAddedPhotos.add(savedPath);
    });
  }

  void _showPhotoSourceDialog() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.takePhoto),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.chooseFromGallery),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removePhoto(int index) async {
    final photoPath = _photos[index];
    setState(() {
      _photos.removeAt(index);
    });
    // Only delete the file if it's a newly added photo (not from existing entry)
    if (!_originalPhotos.contains(photoPath)) {
      _newlyAddedPhotos.remove(photoPath);
      await ref.read(journalProvider.notifier).deletePhoto(photoPath);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final notifier = ref.read(journalProvider.notifier);
      final now = DateTime.now();

      // Clean up removed photos from existing entry
      if (_isEditing) {
        for (final originalPhoto in _originalPhotos) {
          if (!_photos.contains(originalPhoto)) {
            await notifier.deletePhoto(originalPhoto);
          }
        }
      }

      final entry = JournalEntry(
        id: _isEditing ? widget.existingEntry!.id : const Uuid().v4(),
        date: _selectedDate,
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        photos: List.from(_photos),
        createdAt: _isEditing ? widget.existingEntry!.createdAt : now,
        updatedAt: now,
      );

      await notifier.saveEntry(entry);
      _saved = true;

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? l10n.entryUpdated : l10n.entryCreated),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('dd MMM yyyy', l10n.locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editEntry : l10n.newEntry),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteEntry,
              onPressed: _saving ? null : () => _confirmDelete(l10n),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date picker
            InkWell(
              onTap: _saving ? null : _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.journalDate,
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: const OutlineInputBorder(),
                ),
                child: Text(dateFormat.format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.journalTitle,
                hintText: l10n.enterJournalTitle,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? l10n.enterTitle : null,
              enabled: !_saving,
            ),
            const SizedBox(height: 16),

            // Body
            TextFormField(
              controller: _bodyController,
              decoration: InputDecoration(
                labelText: l10n.journalBody,
                hintText: l10n.enterJournalBody,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 8,
              minLines: 4,
              textCapitalization: TextCapitalization.sentences,
              enabled: !_saving,
            ),
            const SizedBox(height: 24),

            // Photos section
            Row(
              children: [
                Icon(Icons.photo_library,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  l10n.journalPhotos,
                  style: theme.textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _saving ? null : _showPhotoSourceDialog,
                  icon: const Icon(Icons.add_a_photo, size: 18),
                  label: Text(l10n.addPhoto),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_photos.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(_photos[index]),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, e, s) => Container(
                                width: 120,
                                height: 120,
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: _saving ? null : () => _removePhoto(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 32),

            // Save button
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(l10n.saveEntry),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteEntry),
        content: Text(l10n.deleteEntryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(journalProvider.notifier)
                  .deleteEntry(widget.existingEntry!.id);
              _saved = true; // Prevent orphan cleanup since entry is deleted
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.entryDeleted)),
                );
                context.pop();
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
