import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/features/announcements/domain/announcement_template.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';

/// Manager for the org's announcement templates (like the master-locations
/// manager). Guides edit the prewritten messages here — picking which language
/// to edit — and the announcement composer pulls from the same list.
class AnnouncementTemplatesScreen extends ConsumerStatefulWidget {
  const AnnouncementTemplatesScreen({super.key});

  @override
  ConsumerState<AnnouncementTemplatesScreen> createState() =>
      _AnnouncementTemplatesScreenState();
}

class _AnnouncementTemplatesScreenState
    extends ConsumerState<AnnouncementTemplatesScreen> {
  @override
  void initState() {
    super.initState();
    // Populate the built-in defaults the first time, so the list is never
    // empty for guides to personalise from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orgId = ref.read(appUserProvider).valueOrNull?.orgId;
      if (orgId != null) {
        ref
            .read(announcementTemplatesRepositoryProvider)
            .seedDefaultsIfEmpty(orgId)
            .ignore();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final lang = ref.watch(settingsProvider).language;
    final templatesAsync = ref.watch(announcementTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.announcementTemplates)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newTemplate),
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.somethingWentWrong)),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(l10n.noTemplatesYet, style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(
                    template.titleFor(lang),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    template.bodyFor(lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: l10n.editTemplate,
                        onPressed: () =>
                            _openEditor(context, existing: template),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        tooltip: l10n.deleteTemplate,
                        onPressed: () => _confirmDelete(context, template),
                      ),
                    ],
                  ),
                  onTap: () => _openEditor(context, existing: template),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openEditor(BuildContext context, {AnnouncementTemplate? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TemplateEditorSheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AnnouncementTemplate template,
  ) async {
    final l10n = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteTemplate),
        content: Text(l10n.deleteTemplateConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: destructiveFilledStyle(Theme.of(ctx)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final orgId = ref.read(appUserProvider).valueOrNull?.orgId;
    if (orgId == null) return;
    try {
      await ref
          .read(announcementTemplatesRepositoryProvider)
          .deleteTemplate(orgId, template.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.templateDeleted)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
      }
    }
  }
}

/// Edits one template across all three languages. A language selector swaps
/// which language's title/body the two fields show; edits are kept per language
/// in memory and all languages are saved together.
class _TemplateEditorSheet extends ConsumerStatefulWidget {
  const _TemplateEditorSheet({this.existing});

  final AnnouncementTemplate? existing;

  @override
  ConsumerState<_TemplateEditorSheet> createState() =>
      _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends ConsumerState<_TemplateEditorSheet> {
  late final Map<String, String> _titles;
  late final Map<String, String> _bodies;
  late String _lang;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titles = {
      for (final l in AnnouncementTemplate.languages)
        l: widget.existing?.titles[l] ?? '',
    };
    _bodies = {
      for (final l in AnnouncementTemplate.languages)
        l: widget.existing?.bodies[l] ?? '',
    };
    // Default to editing the app's current language.
    _lang = ref.read(settingsProvider).language;
    if (!AnnouncementTemplate.languages.contains(_lang)) {
      _lang = AnnouncementTemplate.languages.first;
    }
    _loadFields();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _loadFields() {
    _titleCtrl.text = _titles[_lang] ?? '';
    _bodyCtrl.text = _bodies[_lang] ?? '';
  }

  void _stashFields() {
    _titles[_lang] = _titleCtrl.text;
    _bodies[_lang] = _bodyCtrl.text;
  }

  void _switchLanguage(String lang) {
    if (lang == _lang) return;
    _stashFields();
    setState(() {
      _lang = lang;
      _loadFields();
    });
  }

  String _langLabel(AppL10n l10n, String lang) {
    switch (lang) {
      case 'ro':
        return l10n.romanian;
      case 'hu':
        return l10n.hungarian;
      default:
        return l10n.english;
    }
  }

  Future<void> _save() async {
    _stashFields();
    final l10n = AppL10n.of(context);

    // Require at least one language to have both a title and a body.
    final hasContent = AnnouncementTemplate.languages.any(
      (l) =>
          (_titles[l] ?? '').trim().isNotEmpty &&
          (_bodies[l] ?? '').trim().isNotEmpty,
    );
    if (!hasContent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.templateNeedsContent)));
      return;
    }

    final orgId = ref.read(appUserProvider).valueOrNull?.orgId;
    if (orgId == null) return;

    setState(() => _isSaving = true);
    final repo = ref.read(announcementTemplatesRepositoryProvider);
    final trimmedTitles = {
      for (final e in _titles.entries) e.key: e.value.trim(),
    };
    final trimmedBodies = {
      for (final e in _bodies.entries) e.key: e.value.trim(),
    };
    try {
      if (_isEditing) {
        await repo.updateTemplate(
          orgId,
          widget.existing!.copyWith(
            titles: trimmedTitles,
            bodies: trimmedBodies,
          ),
        );
      } else {
        await repo.addTemplate(
          orgId,
          AnnouncementTemplate(
            id: '',
            titles: trimmedTitles,
            bodies: trimmedBodies,
            order: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? l10n.editTemplate : l10n.newTemplate,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.templateLanguageHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Language selector
            SegmentedButton<String>(
              segments: [
                for (final lang in AnnouncementTemplate.languages)
                  ButtonSegment<String>(
                    value: lang,
                    label: Text(_langLabel(l10n, lang)),
                  ),
              ],
              selected: {_lang},
              onSelectionChanged: (s) => _switchLanguage(s.first),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: l10n.announcementTitle,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.announcementBody,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.saveChanges),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
