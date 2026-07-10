// lib/features/map/presentation/knowledge_base_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
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
  late List<QuizQuestion> _quiz;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final kb = widget.location.knowledgeBase;
    _descriptionController = TextEditingController(text: kb.description);
    _factsController = TextEditingController(text: kb.facts);
    _funFactController = TextEditingController(text: kb.funFact);
    _quiz = List.from(kb.quiz);
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

    final l10n = AppL10n.of(context);
    final orgId = ref.read(appUserProvider).valueOrNull?.orgId;
    if (orgId == null) return;

    setState(() => _isSaving = true);

    try {
      final knowledgeBase = KnowledgeBase(
        description: _descriptionController.text.trim(),
        facts: _factsController.text.trim(),
        funFact: _funFactController.text.trim(),
        quiz: _quiz,
      );

      await ref
          .read(locationRepositoryProvider)
          .updateKnowledgeBase(orgId, widget.location.id, knowledgeBase.toMap());

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
              content: Text(AppL10n.of(context).somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editQuestion(int? index) async {
    final existing = index != null ? _quiz[index] : null;
    final result = await showDialog<QuizQuestion>(
      context: context,
      builder: (ctx) => _QuizQuestionDialog(existing: existing),
    );
    if (result == null) return;
    setState(() {
      if (index != null) {
        _quiz[index] = result;
      } else {
        _quiz.add(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

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
            const SizedBox(height: 16),

            // Quiz section
            Row(
              children: [
                Icon(Icons.quiz_outlined,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(l10n.quizSectionTitle, style: theme.textTheme.titleSmall),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isSaving ? null : () => _editQuestion(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.addQuizQuestion),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._quiz.asMap().entries.map(
              (entry) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${entry.key + 1}')),
                  title: Text(
                    entry.value.question,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    entry.value.options[entry.value.correctIndex],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: _isSaving ? null : () => _editQuestion(entry.key),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    tooltip: l10n.quizDeleteQuestion,
                    onPressed: _isSaving
                        ? null
                        : () => setState(() => _quiz.removeAt(entry.key)),
                  ),
                ),
              ),
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

class _QuizQuestionDialog extends StatefulWidget {
  final QuizQuestion? existing;

  const _QuizQuestionDialog({this.existing});

  @override
  State<_QuizQuestionDialog> createState() => _QuizQuestionDialogState();
}

class _QuizQuestionDialogState extends State<_QuizQuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _questionCtrl;
  late final List<TextEditingController> _optionCtrls;
  late int _correctIndex;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _questionCtrl = TextEditingController(text: existing?.question ?? '');
    _optionCtrls = List.generate(
      4,
      (i) => TextEditingController(
        text: (existing != null && i < existing.options.length)
            ? existing.options[i]
            : '',
      ),
    );
    _correctIndex = existing?.correctIndex ?? 0;
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final l10n = AppL10n.of(context);
    if (!_formKey.currentState!.validate()) return;

    final options = <String>[];
    int? mappedCorrectIndex;
    for (var i = 0; i < _optionCtrls.length; i++) {
      final text = _optionCtrls[i].text.trim();
      if (text.isEmpty) continue;
      if (i == _correctIndex) mappedCorrectIndex = options.length;
      options.add(text);
    }

    if (options.length < 2 || mappedCorrectIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.quizNeedTwoOptions)),
      );
      return;
    }

    Navigator.pop(
      context,
      QuizQuestion(
        question: _questionCtrl.text.trim(),
        options: options,
        correctIndex: mappedCorrectIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AlertDialog(
      title: Text(l10n.addQuizQuestion),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _questionCtrl,
                decoration: InputDecoration(
                  labelText: l10n.quizQuestionLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.enterTitle : null,
              ),
              const SizedBox(height: 12),
              RadioGroup<int>(
                groupValue: _correctIndex,
                onChanged: (v) => setState(() => _correctIndex = v ?? 0),
                child: Column(
                  children: [
                    for (var i = 0; i < _optionCtrls.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Radio<int>(value: i),
                            Expanded(
                              child: TextFormField(
                                controller: _optionCtrls[i],
                                decoration: InputDecoration(
                                  labelText: l10n.quizOptionLabel(i + 1),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.quizCorrectOption,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.saveChanges)),
      ],
    );
  }
}
