import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:camp_connect/features/announcements/domain/announcement.dart';
import 'package:camp_connect/features/announcements/domain/prompt_utils.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';
import '../domain/journal_entry.dart';
import '../domain/prompt_answer.dart';

class JournalEditorScreen extends ConsumerStatefulWidget {
  final JournalEntry? existingEntry;
  final String? initialPrompt;

  const JournalEditorScreen({super.key, this.existingEntry, this.initialPrompt});

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
  // The question this entry answers, if any — either adopted from the
  // announcement CTA / journal-editor prompt banner, or (when editing) the
  // entry's own already-saved prompt.
  String? _prompt;
  // Track photos from the existing entry so we know which ones to keep
  late final List<String> _originalPhotos;
  // Track newly added photos so we can clean up orphans on discard
  final List<String> _newlyAddedPhotos = [];
  bool _saving = false;
  bool _saved = false;

  // Photos pending permanent on-disk deletion, keyed by path, guarded by a
  // Timer so the delete only fires if the user doesn't tap Undo in time.
  // A Timer (rather than SnackBar's onVisible callback) is used because
  // onVisible isn't reliably invoked across all Flutter versions/platforms,
  // and it only fires once the snackbar is actually shown/animated in,
  // which is a less precise/robust signal than a fixed duration timer. See
  // _deleteFinalizeDelay for why that timer's duration is intentionally
  // longer than the SnackBar's own displayed `duration`.
  final Map<String, Timer> _pendingPhotoDeletes = {};

  // Resolved once in initState(), while `ref` is still guaranteed valid.
  // Used by every photo-delete/save call site below (_deletePhotoFile,
  // _pickImage) instead of a fresh `ref.read(...)` each time, so there's
  // only ever one way to get a notifier for those specific operations.
  // dispose() must not call `ref.read(...)` itself: per Flutter's widget
  // lifecycle,
  // `Element.unmount()` has already invalidated `ref` by the time ANY code
  // inside `State.dispose()` runs (not just "partway through" it) -- so
  // even reading it as the very first statement in dispose() throws
  // "Cannot use `ref` after the widget was disposed." Capturing it here,
  // before disposal is anywhere in the picture, sidesteps that entirely.
  //
  // This assumes journalProvider isn't torn down/recreated (e.g. by an
  // account switch invalidating the auth-derived providers it depends on)
  // while this screen is on-screen -- true for this app's current
  // navigation/auth flow, but not a guarantee Riverpod itself makes about
  // this provider's lifetime.
  late final JournalNotifier _journalNotifier;

  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    _journalNotifier = ref.read(journalProvider.notifier);
    if (_isEditing) {
      _titleController.text = widget.existingEntry!.title;
      _bodyController.text = widget.existingEntry!.body;
      _selectedDate = widget.existingEntry!.date;
      _photos.addAll(widget.existingEntry!.photos);
      _originalPhotos = List.from(widget.existingEntry!.photos);
      _prompt = widget.existingEntry!.prompt;
    } else {
      _selectedDate = DateTime.now();
      _originalPhotos = [];
      _prompt = widget.initialPrompt;
    }
  }

  @override
  void dispose() {
    // Any pending "undo window" deletes can no longer show a snackbar to be
    // undone, so finalize them immediately rather than leaking the timers.
    // Uses the pre-captured _journalNotifier, not `ref` -- see its doc
    // comment above for why `ref` itself is unusable at this point.
    for (final timer in _pendingPhotoDeletes.values) {
      timer.cancel();
    }
    for (final path in _pendingPhotoDeletes.keys) {
      _deletePhotoFile(path);
    }
    _pendingPhotoDeletes.clear();

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

    final savedPath = await _journalNotifier.savePhoto(picked.path);
    setState(() {
      _photos.add(savedPath);
      _newlyAddedPhotos.add(savedPath);
    });
  }

  void _showPhotoSourceDialog() {
    final l10n = AppL10n.of(context);
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

  static const _undoWindow = Duration(seconds: 4);

  // SnackBar's own auto-dismiss timer doesn't start counting down from the
  // moment showSnackBar() is called -- it only starts once the SnackBar's
  // entrance transition finishes animating in, which per Flutter's
  // SnackBar implementation takes ~250ms. That means the SnackBar (and its
  // tappable "Undo" action) actually stays visible until roughly
  // `250ms + duration` after showSnackBar() is called, not just `duration`.
  // If the app-level finalize Timer below used exactly `_undoWindow`, there
  // would be a window (~250ms) where the file has already been deleted from
  // disk but Undo is still visible and tappable, producing a dangling photo
  // reference if tapped. Adding a safety margin comfortably larger than the
  // 250ms entrance transition ensures the finalize Timer can never fire
  // before the SnackBar (and its Undo action) has actually gone away.
  static const _snackBarDismissMargin = Duration(milliseconds: 500);
  static final _deleteFinalizeDelay = _undoWindow + _snackBarDismissMargin;

  /// Deletes [photoPath] from disk via the pre-captured [_journalNotifier]
  /// (see its field doc for why this never reads `ref` directly -- that
  /// keeps this method safe to call from `dispose()` as well as from
  /// normal widget lifetime, with no special-casing needed at call sites).
  Future<void> _deletePhotoFile(String photoPath) async {
    // Only delete the file if it's a newly added photo (not from existing entry)
    if (!_originalPhotos.contains(photoPath)) {
      _newlyAddedPhotos.remove(photoPath);
      await _journalNotifier.deletePhoto(photoPath);
    }
  }

  /// Removes [photoPath] from the in-memory list immediately (so it
  /// disappears from the UI right away) but defers the on-disk file
  /// deletion until [_deleteFinalizeDelay] elapses, giving the user a
  /// chance to tap "Undo" on the snackbar for the full time it is actually
  /// visible on screen (the snackbar itself is shown for [_undoWindow], see
  /// [_snackBarDismissMargin] for why the finalize delay is longer than
  /// that). If the widget is disposed before the delay elapses, the delete
  /// is finalized immediately in dispose().
  void _removePhotoWithUndo(int index) {
    final photoPath = _photos[index];
    setState(() {
      _photos.removeAt(index);
    });

    final l10n = AppL10n.of(context);
    _pendingPhotoDeletes[photoPath]?.cancel();
    _pendingPhotoDeletes[photoPath] = Timer(_deleteFinalizeDelay, () {
      _pendingPhotoDeletes.remove(photoPath);
      _deletePhotoFile(photoPath);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: _undoWindow,
        content: Text(l10n.photoRemoved),
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () {
            _pendingPhotoDeletes.remove(photoPath)?.cancel();
            if (!mounted) return;
            setState(() {
              final restoreIndex = index <= _photos.length
                  ? index
                  : _photos.length;
              _photos.insert(restoreIndex, photoPath);
            });
          },
        ),
      ),
    );
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
        prompt: _prompt,
        createdAt: _isEditing ? widget.existingEntry!.createdAt : now,
        updatedAt: now,
      );

      await notifier.saveEntry(entry);
      _saved = true;

      if (mounted) {
        final l10n = AppL10n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? l10n.entryUpdated : l10n.entryCreated),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppL10n.of(context);
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

  /// Whether the entry differs from what's saved on disk (or, for a new
  /// entry, from blank) — the [PopScope] guard below only interrupts
  /// navigation when this is true.
  bool get _isDirty {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (!_isEditing) {
      return title.isNotEmpty ||
          body.isNotEmpty ||
          _photos.isNotEmpty ||
          _prompt != null;
    }
    final existing = widget.existingEntry!;
    return title != existing.title.trim() ||
        body != existing.body.trim() ||
        _selectedDate != existing.date ||
        !listEquals(_photos, _originalPhotos) ||
        _prompt != existing.prompt;
  }

  Future<bool> _confirmDiscard(AppL10n l10n) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardEntryTitle),
        content: Text(l10n.discardEntryMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.keepWriting),
          ),
          FilledButton(
            style: destructiveFilledStyle(Theme.of(ctx)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final dateFormat = DateFormat(
      'dd MMM yyyy',
      Localizations.localeOf(context).toString(),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_isDirty || _saved) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        final discard = await _confirmDiscard(l10n);
        if (!discard) return;
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
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
            _PromptBanner(
              adopted: _prompt,
              isNewEntry: !_isEditing,
              onAdopt: (question) => setState(() => _prompt = question),
              onClear: () => setState(() => _prompt = null),
            ),
            // Date picker
            InkWell(
              onTap: _saving ? null : _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.journalDate,
                  prefixIcon: const Icon(Icons.calendar_today),
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
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  key: const ValueKey('remove-photo-button'),
                                  customBorder: const CircleBorder(),
                                  onTap: _saving
                                      ? null
                                      : () => _removePhotoWithUndo(index),
                                  child: Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Semantics(
                                        label: l10n.removePhoto,
                                        child: const Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
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
      ),
    );
  }

  void _confirmDelete(AppL10n l10n) {
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

/// Shows the question this entry answers (dismissible), or — on a fresh
/// entry with no adopted question — offers today's active prompt.
class _PromptBanner extends ConsumerWidget {
  final String? adopted;
  final bool isNewEntry;
  final ValueChanged<String> onAdopt;
  final VoidCallback onClear;

  const _PromptBanner({
    required this.adopted,
    required this.isNewEntry,
    required this.onAdopt,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    if (adopted != null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: theme.colorScheme.tertiaryContainer,
        child: ListTile(
          leading: Icon(Icons.lightbulb,
              color: theme.colorScheme.onTertiaryContainer),
          title: Text(
            adopted!,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
        ),
      );
    }

    if (!isNewEntry) return const SizedBox.shrink();
    final announcements =
        ref.watch(announcementsProvider).valueOrNull ?? const <Announcement>[];
    final prompt = activePrompt(announcements, DateTime.now());
    if (prompt == null) return const SizedBox.shrink();

    final entries = ref.watch(journalProvider).valueOrNull ?? const [];
    if (hasAnsweredPrompt(entries, prompt)) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: ListTile(
          leading: Icon(Icons.check_circle, color: theme.colorScheme.primary),
          title: Text(l10n.promptAnswered, style: theme.textTheme.titleSmall),
          subtitle: Text(prompt.title, style: theme.textTheme.bodySmall),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(Icons.lightbulb_outline,
            color: theme.colorScheme.tertiary),
        title: Text(l10n.questionOfTheDay,
            style: theme.textTheme.labelSmall),
        subtitle: Text(prompt.title, style: theme.textTheme.titleSmall),
        trailing: FilledButton.tonal(
          onPressed: () => onAdopt(prompt.title),
          child: Text(l10n.answerInJournal),
        ),
      ),
    );
  }
}
