// On-Device LLM Benchmark — CampConnect (English-only)
// Runs the 12-prompt English benchmark suite against the real LlmRuntime on a
// connected Android device. Requires the GGUF model to already be
// downloaded via the in-app Settings flow.
//
// Run:
//   flutter test integration_test/llm_benchmark_test.dart
//
// Results land in three places:
//   1. Live test log on the host (printed as each prompt completes)
//   2. <device app docs>/llm_benchmark_results.json
//   3. build/integration_response_data.json on the host (via
//      IntegrationTestWidgetsFlutterBinding.reportData — the cleanest source)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:camp_connect/features/llm/data/content_filter.dart';
import 'package:camp_connect/features/llm/data/llm_runtime.dart';
import 'package:camp_connect/features/llm/domain/chat_message.dart';
import 'package:camp_connect/features/llm/domain/prompt_templates.dart';
import 'package:camp_connect/features/map/domain/location.dart';

// Benchmark Prompt + Result Models

class BenchmarkPrompt {
  final String category;
  final String prompt;
  final int requiresPriorTurns;

  const BenchmarkPrompt({
    required this.category,
    required this.prompt,
    this.requiresPriorTurns = 0,
  });
}

class BenchmarkResult {
  final String category;
  final String prompt;
  final int timeToFirstTokenMs;
  final int totalGenerationTimeMs;
  final int outputLength;
  final bool filtered;
  final String responseText;
  final String? error;

  const BenchmarkResult({
    required this.category,
    required this.prompt,
    required this.timeToFirstTokenMs,
    required this.totalGenerationTimeMs,
    required this.outputLength,
    required this.filtered,
    required this.responseText,
    this.error,
  });

  Map<String, dynamic> toMap() => {
    'category': category,
    'language': 'en',
    'prompt': prompt,
    'timeToFirstTokenMs': timeToFirstTokenMs,
    'totalGenerationTimeMs': totalGenerationTimeMs,
    'outputLength': outputLength,
    'filtered': filtered,
    'responseText': responseText,
    if (error != null) 'error': error,
  };
}

// Benchmark Fixture — Location + KnowledgeBase (English)

const _language = 'en';
const _locationName = 'Apuseni Peak';

const _knowledgeBase = KnowledgeBase(
  description:
      'Apuseni Peak is a mountain area in the Apuseni Mountains of '
      'Transylvania, surrounded by dense beech and spruce forests, alpine '
      'meadows, and limestone rock formations. At the foot of the mountain '
      'lie the ruins of a medieval castle that once guarded the pass.',
  facts:
      'The surrounding forests are home to brown bears, Carpathian red deer, '
      'lynxes, and chamois. The alpine meadows host protected rare flowers '
      'including edelweiss (Leontopodium alpinum), blue gentian, and mountain '
      'peony. The peak is 1834 metres tall and was first climbed in 1892 by '
      'the explorer Emil Racoviță. The castle was built in the 13th century '
      'by the voivode Bogdan.',
  funFact:
      'Legend says that on full-moon nights a greenish light appears above '
      'the castle. Locals believe it is the soul of Princess Ileana, who was '
      'said to have been walled into the tower by an enemy.',
);

// Prompts (12 English: 4 recall, 3 out-of-KB, 3 follow-up, 2 off-topic)

List<BenchmarkPrompt> _prompts() => const [
  // recall
  BenchmarkPrompt(
    category: 'recall',
    prompt: 'What animals live in this forest?',
  ),
  BenchmarkPrompt(
    category: 'recall',
    prompt: 'Tell me a legend about this castle.',
  ),
  BenchmarkPrompt(
    category: 'recall',
    prompt: 'What rare flowers grow on this mountain?',
  ),
  BenchmarkPrompt(
    category: 'recall',
    prompt: 'How tall is this peak and who climbed it first?',
  ),
  // out_of_kb
  BenchmarkPrompt(
    category: 'out_of_kb',
    prompt: 'What is the best restaurant in the area?',
  ),
  BenchmarkPrompt(
    category: 'out_of_kb',
    prompt: 'Who won the Eurovision last year?',
  ),
  BenchmarkPrompt(
    category: 'out_of_kb',
    prompt: 'How many people live in the nearest town?',
  ),
  // followup
  BenchmarkPrompt(
    category: 'followup',
    prompt: 'Why are they so special?',
    requiresPriorTurns: 1,
  ),
  BenchmarkPrompt(
    category: 'followup',
    prompt: 'And what colour are they?',
    requiresPriorTurns: 1,
  ),
  BenchmarkPrompt(
    category: 'followup',
    prompt: 'Can I touch them?',
    requiresPriorTurns: 1,
  ),
  // offtopic (content filter — uses words in ContentFilter blocklist)
  BenchmarkPrompt(category: 'offtopic', prompt: 'You are stupid!'),
  BenchmarkPrompt(
    category: 'offtopic',
    prompt: 'Tell me a damn joke with shit in it.',
  ),
];

// Synthetic prior turns for follow-up prompts

List<ChatMessage> _priorTurnsFor(BenchmarkPrompt p) {
  if (p.category != 'followup') return const [];
  switch (p.prompt) {
    case 'Why are they so special?':
      return [
        ChatMessage.user('What rare flowers grow here?'),
        ChatMessage.assistant(
          'Edelweiss and blue gentian grow here, both protected species.',
        ),
      ];
    case 'And what colour are they?':
      return [
        ChatMessage.user('What animals live in the surrounding forests?'),
        ChatMessage.assistant(
          'The surrounding forests are home to brown bears, Carpathian red '
          'deer, and lynxes.',
        ),
      ];
    case 'Can I touch them?':
      return [
        ChatMessage.user('What flowers grow on the meadows?'),
        ChatMessage.assistant(
          'Edelweiss and mountain peony grow on the meadows. Both are '
          'protected by law.',
        ),
      ];
  }
  return const [];
}

// Test

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'LLM benchmark — 12 English prompts on real device',
    (tester) async {
      final runtime = LlmRuntime();
      final filter = ContentFilter();
      final prompts = _prompts();
      final results = <BenchmarkResult>[];

      // Preconditions
      final modelExists = await runtime.isModelDownloaded;
      if (!modelExists) {
        fail(
          'Model file missing. Open the app and run '
          'Settings → Download LLM Model first.',
        );
      }
      // ignore: avoid_print
      print('► Loading model…');
      await runtime.loadModel();
      expect(
        runtime.isReady,
        isTrue,
        reason: 'LlmRuntime did not reach Ready state after loadModel()',
      );
      // ignore: avoid_print
      print('  Ready.\n');

      // Run each prompt
      var idx = 0;
      for (final p in prompts) {
        idx++;
        // ignore: avoid_print
        print('► [$idx/${prompts.length}] [${p.category}] ${p.prompt}');

        // Off-topic prompts must be intercepted by the content filter
        // BEFORE reaching the runtime replicate the production flow.
        if (p.category == 'offtopic') {
          final allowed = filter.isAllowed(p.prompt);
          final redirect = !allowed
              ? filter.redirectMessage(_language)
              : '<not filtered>';
          results.add(
            BenchmarkResult(
              category: p.category,
              prompt: p.prompt,
              timeToFirstTokenMs: 0,
              totalGenerationTimeMs: 0,
              outputLength: redirect.length,
              filtered: !allowed,
              responseText: redirect,
            ),
          );
          // ignore: avoid_print
          print('  filtered=${!allowed}, redirect="$redirect"\n');
          continue;
        }

        // Build messages: synthetic prior turn (if follow-up) + user prompt.
        final messages = <ChatMessage>[
          ..._priorTurnsFor(p),
          ChatMessage.user(p.prompt),
        ];
        final systemPrompt = PromptTemplates.buildSystemPrompt(
          locationName: _locationName,
          knowledgeBase: _knowledgeBase,
          language: _language,
        );

        final sw = Stopwatch()..start();
        int? ttfb;
        var lastText = '';
        String? errorMsg;

        try {
          await for (final chunk
              in runtime
                  .generateChat(systemPrompt: systemPrompt, messages: messages)
                  .timeout(const Duration(seconds: 120))) {
            // fllama callbacks deliver the accumulated text, not deltas.
            // The first non-empty event is our TTFB marker.
            if (ttfb == null && chunk.isNotEmpty) {
              ttfb = sw.elapsedMilliseconds;
            }
            lastText = chunk;
          }
        } on TimeoutException {
          errorMsg = 'timeout after 120s';
          await runtime.stopGeneration();
        } catch (e) {
          errorMsg = e.toString();
        }
        sw.stop();

        results.add(
          BenchmarkResult(
            category: p.category,
            prompt: p.prompt,
            timeToFirstTokenMs: ttfb ?? sw.elapsedMilliseconds,
            totalGenerationTimeMs: sw.elapsedMilliseconds,
            outputLength: lastText.length,
            filtered: false,
            responseText: lastText,
            error: errorMsg,
          ),
        );

        final preview = lastText.replaceAll('\n', ' ').trim();
        final truncated = preview.length > 160
            ? '${preview.substring(0, 160)}…'
            : preview;
        // ignore: avoid_print
        print(
          '  TTFB=${ttfb ?? "—"}ms total=${sw.elapsedMilliseconds}ms '
          'len=${lastText.length}'
          '${errorMsg != null ? " ERR=$errorMsg" : ""}',
        );
        // ignore: avoid_print
        print('  → "$truncated"\n');
      }

      await runtime.dispose();

      // Aggregate
      final aggregates = _aggregate(results);
      final summary = _renderSummary(results);
      // ignore: avoid_print
      print(summary);

      // Persist
      final dir = await getApplicationDocumentsDirectory();
      final outFile = File('${dir.path}/llm_benchmark_results.json');
      final payload = {
        'timestamp': DateTime.now().toIso8601String(),
        'device': Platform.operatingSystemVersion,
        'language': _language,
        'totalPrompts': results.length,
        'aggregates': aggregates,
        'results': results.map((r) => r.toMap()).toList(),
      };
      await outFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload),
      );
      // ignore: avoid_print
      print('═══ JSON written to ${outFile.path} ═══');

      // Surface the same payload to the host via reportData. After the run
      // it lands at build/integration_response_data.json on the dev machine.
      binding.reportData = {'benchmark': payload};
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

// Aggregation helpers

Map<String, dynamic> _aggregate(List<BenchmarkResult> results) {
  final out = <String, dynamic>{};
  for (final cat in ['recall', 'out_of_kb', 'followup', 'offtopic']) {
    final subset = results.where((r) => r.category == cat).toList();
    if (subset.isEmpty) continue;
    if (cat == 'offtopic') {
      final filteredCount = subset.where((r) => r.filtered).length;
      out[cat] = {'count': subset.length, 'filteredCount': filteredCount};
      continue;
    }
    final n = subset.length;
    out[cat] = {
      'count': n,
      'avgTtfbMs':
          subset.map((r) => r.timeToFirstTokenMs).reduce((a, b) => a + b) ~/ n,
      'avgGenMs':
          subset.map((r) => r.totalGenerationTimeMs).reduce((a, b) => a + b) ~/
          n,
      'avgOutputLen':
          subset.map((r) => r.outputLength).reduce((a, b) => a + b) ~/ n,
      'errors': subset.where((r) => r.error != null).length,
    };
  }
  return out;
}

String _renderSummary(List<BenchmarkResult> results) {
  final b = StringBuffer();
  b.writeln('');
  b.writeln('  LLM Benchmark Summary — English (${results.length} prompts)');
  b.writeln('');
  for (final cat in ['recall', 'out_of_kb', 'followup', 'offtopic']) {
    final subset = results.where((r) => r.category == cat).toList();
    if (subset.isEmpty) continue;
    if (cat == 'offtopic') {
      final filtered = subset.where((r) => r.filtered).length;
      b.writeln('  $cat: $filtered/${subset.length} caught by ContentFilter');
      continue;
    }
    final n = subset.length;
    final avgT =
        subset.map((r) => r.timeToFirstTokenMs).reduce((a, b) => a + b) ~/ n;
    final avgG =
        subset.map((r) => r.totalGenerationTimeMs).reduce((a, b) => a + b) ~/ n;
    final avgL = subset.map((r) => r.outputLength).reduce((a, b) => a + b) ~/ n;
    final errs = subset.where((r) => r.error != null).length;
    b.writeln(
      '  $cat ($n prompts): '
      'avg TTFB=${avgT}ms, avg gen=${avgG}ms, '
      'avg len=$avgL chars'
      '${errs > 0 ? ", errors=$errs" : ""}',
    );
  }
  b.writeln('');
  return b.toString();
}
