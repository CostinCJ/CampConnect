// lib/features/map/presentation/knowledge_base_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class KnowledgeBaseEditorScreen extends ConsumerStatefulWidget {
  final Location location;

  const KnowledgeBaseEditorScreen({super.key, required this.location});

  @override
  ConsumerState<KnowledgeBaseEditorScreen> createState() =>
      _KnowledgeBaseEditorScreenState();
}

class _KnowledgeBaseEditorScreenState
    extends ConsumerState<KnowledgeBaseEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _factsController;
  late final TextEditingController _funFactController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final kb = widget.location.knowledgeBase;
    _descriptionController = TextEditingController(text: kb.description);
    _factsController = TextEditingController(text: kb.facts);
    _funFactController = TextEditingController(text: kb.funFact);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _factsController.dispose();
    _funFactController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _isSaving = true);

    try {
      final knowledgeBase = KnowledgeBase(
        description: _descriptionController.text.trim(),
        facts: _factsController.text.trim(),
        funFact: _funFactController.text.trim(),
      );

      await ref
          .read(locationRepositoryProvider)
          .updateKnowledgeBase(widget.location.id, knowledgeBase.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.knowledgeBaseSaved)),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).somethingWentWrong)),
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
        title: Text(l10n.knowledgeBase),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Location name header
            Text(
              widget.location.name,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.mapLocationsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.knowledgeBaseDescription,
                hintText: l10n.knowledgeBaseDescriptionHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Facts
            TextFormField(
              controller: _factsController,
              decoration: InputDecoration(
                labelText: l10n.knowledgeBaseFacts,
                hintText: l10n.knowledgeBaseFactsHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // Fun fact
            TextFormField(
              controller: _funFactController,
              decoration: InputDecoration(
                labelText: l10n.knowledgeBaseFunFact,
                hintText: l10n.knowledgeBaseFunFactHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
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
}
