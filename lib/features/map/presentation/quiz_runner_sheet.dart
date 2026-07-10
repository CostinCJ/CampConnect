import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/features/passport/domain/passport_stamp.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import '../domain/location.dart';

/// One-question-at-a-time quiz with immediate feedback. On finish, the best
/// score is stored device-locally (never uploaded) and the passport tile
/// earns a star for a perfect run.
class QuizRunnerSheet extends ConsumerStatefulWidget {
  final String locationId;
  final List<QuizQuestion> quiz;

  const QuizRunnerSheet({
    super.key,
    required this.locationId,
    required this.quiz,
  });

  @override
  ConsumerState<QuizRunnerSheet> createState() => _QuizRunnerSheetState();
}

class _QuizRunnerSheetState extends ConsumerState<QuizRunnerSheet> {
  int _index = 0;
  int _correctCount = 0;
  int? _selected; // null until this question is answered
  bool _finished = false;

  bool get _answered => _selected != null;

  Future<void> _next() async {
    if (_index + 1 < widget.quiz.length) {
      setState(() {
        _index++;
        _selected = null;
      });
      return;
    }
    // Finished: persist best result and show the score view.
    await ref.read(passportStorageProvider).saveQuizResult(QuizResult(
          locationId: widget.locationId,
          correct: _correctCount,
          total: widget.quiz.length,
          completedAt: DateTime.now(),
        ));
    ref.invalidate(quizResultsProvider);
    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: _finished ? _scoreView(theme, l10n) : _questionView(theme, l10n),
      ),
    );
  }

  Widget _questionView(ThemeData theme, AppL10n l10n) {
    final question = widget.quiz[_index];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.quizQuestionOf(_index + 1, widget.quiz.length),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(question.question, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionButton(
              label: question.options[i],
              state: !_answered
                  ? _OptionState.idle
                  : i == question.correctIndex
                      ? _OptionState.correct
                      : i == _selected
                          ? _OptionState.wrong
                          : _OptionState.disabled,
              onTap: _answered
                  ? null
                  : () {
                      setState(() {
                        _selected = i;
                        if (i == question.correctIndex) _correctCount++;
                      });
                    },
            ),
          ),
        if (_answered) ...[
          const SizedBox(height: 4),
          Text(
            _selected == question.correctIndex
                ? l10n.quizCorrect
                : l10n.quizWrong,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _next,
            child: Text(
              _index + 1 < widget.quiz.length ? l10n.quizNext : l10n.quizFinish,
            ),
          ),
        ],
      ],
    );
  }

  Widget _scoreView(ThemeData theme, AppL10n l10n) {
    final perfect = _correctCount == widget.quiz.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          perfect ? Icons.star : Icons.emoji_events_outlined,
          size: 64,
          color: perfect
              ? const Color(0xFFFFC107)
              : theme.colorScheme.tertiary,
        ),
        const SizedBox(height: 12),
        Text(
          perfect
              ? l10n.quizPerfect
              : l10n.quizScore(_correctCount, widget.quiz.length),
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.quizFinish),
        ),
      ],
    );
  }
}

enum _OptionState { idle, correct, wrong, disabled }

class _OptionButton extends StatelessWidget {
  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  const _OptionButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) = switch (state) {
      _OptionState.idle => (
          theme.colorScheme.surfaceContainerHighest,
          theme.colorScheme.onSurface,
        ),
      _OptionState.correct => (
          theme.colorScheme.primaryContainer,
          theme.colorScheme.onPrimaryContainer,
        ),
      // Sunset orange, NOT error red — red stays reserved for emergencies
      // (design principle "Emergency is sacred").
      _OptionState.wrong => (
          const Color(0xFFFFE0B2),
          const Color(0xFF7A3E00),
        ),
      _OptionState.disabled => (
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          theme.colorScheme.onSurfaceVariant,
        ),
    };

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}
