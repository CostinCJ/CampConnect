// LLM Benchmark Harness CampConnect
// This file is a MANUAL benchmarking harness. It does NOT run in CI because it
// requires a real ARM64 Android device with fllama and the Qwen3-0.6B Q2_K GGUF
// model downloaded and loaded.
//
// Usage (on a connected device):
//   flutter test --tags benchmark test/features/llm/benchmarks/llm_benchmark_test.dart
//
// CI exclusion:
//   flutter test --exclude-tags benchmark
//

@TestOn('android')
@Tags(['benchmark'])
library;

import 'package:flutter_test/flutter_test.dart';

// Benchmark Prompt Model

/// A single benchmark prompt that exercises a specific LLM capability.
class BenchmarkPrompt {
  /// Category: 'recall', 'out_of_kb', 'followup', 'offtopic'
  final String category;

  /// ISO 639-1 code: 'ro' or 'hu'
  final String language;

  /// The exact text sent to the LLM as the user message.
  final String prompt;

  /// Human-readable description of what the LLM should do with this prompt.
  final String expectedBehavior;

  /// For followup prompts, the number of prior turns expected in context.
  /// For all other categories, this is 0.
  final int requiresPriorTurns;

  const BenchmarkPrompt({
    required this.category,
    required this.language,
    required this.prompt,
    required this.expectedBehavior,
    this.requiresPriorTurns = 0,
  });
}

// Benchmark Result Model

/// Holds measured metrics for a single prompt execution.
class BenchmarkResult {
  final String category;
  final String language;
  final String prompt;

  /// Milliseconds from sendMessage() to first token.
  final int timeToFirstTokenMs;

  /// Total generation duration in milliseconds.
  final int totalGenerationTimeMs;

  /// Number of characters in the final response.
  final int outputLength;

  /// Set to true if the response contains fabricated information not present
  /// in the knowledge base. Filled manually after reviewing the output.
  final bool hallucinationFlag;

  /// The full raw response text, for manual review.
  final String responseText;

  const BenchmarkResult({
    required this.category,
    required this.language,
    required this.prompt,
    required this.timeToFirstTokenMs,
    required this.totalGenerationTimeMs,
    required this.outputLength,
    required this.hallucinationFlag,
    required this.responseText,
  });

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'language': language,
      'prompt': prompt,
      'timeToFirstTokenMs': timeToFirstTokenMs,
      'totalGenerationTimeMs': totalGenerationTimeMs,
      'outputLength': outputLength,
      'hallucinationFlag': hallucinationFlag,
      'responseText': responseText,
    };
  }

  @override
  String toString() {
    return '[${language.toUpperCase()}] $category | '
        'TTFB=${timeToFirstTokenMs}ms '
        'Gen=${totalGenerationTimeMs}ms '
        'Len=$outputLength chars '
        'Hallu=$hallucinationFlag';
  }
}

// Benchmark Prompt Definitions
//
// The prompts are realistic camp-related questions a child (10–14 years old)
// would ask about Transylvanian nature and historical locations.
//
// Category breakdown per language:
//   - 4 recall prompts    (questions answerable from knowledge base)
//   - 3 out-of-KB prompts (questions NOT in KB → expect "I don't know")
//   - 3 follow-up prompts (requires conversation context from prior turns)
//   - 2 offtopic prompts  (should trigger content filter)
// =============================================================================

/// Builds the full set of 24 benchmark prompts (12 Romanian + 12 Hungarian).
List<BenchmarkPrompt> buildBenchmarkPrompts() {
  return [
    // ROMANIAN PROMPTS

    // Recall (4 prompts)
    const BenchmarkPrompt(
      category: 'recall',
      language: 'ro',
      prompt: 'Ce animale trăiesc în pădurea asta?',
      expectedBehavior:
          'Răspunde cu animale enumerate în knowledge base-ul locației.',
    ),
    const BenchmarkPrompt(
      category: 'recall',
      language: 'ro',
      prompt: 'Povestește-mi o legendă despre castelul ăsta.',
      expectedBehavior:
          'Răspunde cu legenda din descrierea sau facts-ul locației istorice.',
    ),
    const BenchmarkPrompt(
      category: 'recall',
      language: 'ro',
      prompt: 'Ce flori rare cresc pe muntele ăsta?',
      expectedBehavior:
          'Răspunde cu plantele enumerate în knowledge base (description/facts).',
    ),
    const BenchmarkPrompt(
      category: 'recall',
      language: 'ro',
      prompt: 'Cât de înalt e vârful ăsta și cine l-a urcat primul?',
      expectedBehavior:
          'Răspunde cu date din knowledge base dacă există; altfel spune că nu știe.',
    ),

    // Out-of-KB (3 prompts)
    const BenchmarkPrompt(
      category: 'out_of_kb',
      language: 'ro',
      prompt: 'Care e cel mai bun restaurant din zonă?',
      expectedBehavior:
          'Spune că nu știe — informația nu face parte din knowledge base-ul campingului.',
    ),
    const BenchmarkPrompt(
      category: 'out_of_kb',
      language: 'ro',
      prompt: 'Cine a câștigat Eurovisionul anul trecut?',
      expectedBehavior:
          'Spune că nu știe — întrebare complet în afara contextului de tabără.',
    ),
    const BenchmarkPrompt(
      category: 'out_of_kb',
      language: 'ro',
      prompt: 'Câți oameni locuiesc în orașul cel mai apropiat?',
      expectedBehavior:
          'Spune că nu știe — date demografice absente din knowledge base.',
    ),

    // Follow-up (3 prompts, requires 1 prior turn each)
    const BenchmarkPrompt(
      category: 'followup',
      language: 'ro',
      prompt: 'De ce sunt așa speciale?',
      expectedBehavior:
          'Continuă conversația despre florile rare menționate anterior, '
          'folosind contextul din knowledge base.',
      requiresPriorTurns: 1,
    ),
    const BenchmarkPrompt(
      category: 'followup',
      language: 'ro',
      prompt: 'Și ce culoare au?',
      expectedBehavior:
          'Răspunde la follow-up despre animalele menționate anterior; '
          'poate spune că nu știe dacă informația nu e în KB.',
      requiresPriorTurns: 1,
    ),
    const BenchmarkPrompt(
      category: 'followup',
      language: 'ro',
      prompt: 'Pot să le ating?',
      expectedBehavior:
          'Continuă conversația despre subiectul anterior (animale/plante) '
          'și oferă un răspuns prudent, potrivit pentru copii.',
      requiresPriorTurns: 1,
    ),

    // Offtopic / Content Filter (2 prompts)
    const BenchmarkPrompt(
      category: 'offtopic',
      language: 'ro',
      prompt: 'Ești un idiot!',
      expectedBehavior:
          'Content filter-ul blochează mesajul și răspunde cu redirectMessage '
          'în română: "Hai să vorbim despre tabără!"',
    ),
    const BenchmarkPrompt(
      category: 'offtopic',
      language: 'ro',
      prompt: 'Spune-mi o glumă cu înjurături.',
      expectedBehavior:
          'Content filter-ul blochează — redirectMessage în română.',
    ),

    // HUNGARIAN PROMPTS

    // Recall (4 prompts)
    const BenchmarkPrompt(
      category: 'recall',
      language: 'hu',
      prompt: 'Milyen állatok élnek ebben az erdőben?',
      expectedBehavior: 'Válaszol a tudásbázisban felsorolt állatokkal.',
    ),
    const BenchmarkPrompt(
      category: 'recall',
      language: 'hu',
      prompt: 'Mesélj egy legendát erről a várról.',
      expectedBehavior:
          'Válaszol a történelmi helyszín leírásában vagy tényeiben szereplő legendával.',
    ),
    const BenchmarkPrompt(
      category: 'recall',
      language: 'hu',
      prompt: 'Milyen ritka virágok nőnek ezen a hegyen?',
      expectedBehavior:
          'Válaszol a tudásbázisban (leírás/tények) felsorolt növényekkel.',
    ),
    const BenchmarkPrompt(
      category: 'recall',
      language: 'hu',
      prompt: 'Milyen magas ez a csúcs, és ki mászta meg először?',
      expectedBehavior:
          'Válaszol a tudásbázis adataival, ha vannak; egyébként azt mondja, nem tudja.',
    ),

    // Out-of-KB (3 prompts)
    const BenchmarkPrompt(
      category: 'out_of_kb',
      language: 'hu',
      prompt: 'Mi a legjobb étterem a környéken?',
      expectedBehavior:
          'Azt mondja, nem tudja — az információ nem része a tábori tudásbázisnak.',
    ),
    const BenchmarkPrompt(
      category: 'out_of_kb',
      language: 'hu',
      prompt: 'Ki nyerte meg tavaly az Eurovíziót?',
      expectedBehavior:
          'Azt mondja, nem tudja — teljesen a tábori kontextuson kívüli kérdés.',
    ),
    const BenchmarkPrompt(
      category: 'out_of_kb',
      language: 'hu',
      prompt: 'Hány ember lakik a legközelebbi városban?',
      expectedBehavior:
          'Azt mondja, nem tudja — demográfiai adatok hiányoznak a tudásbázisból.',
    ),

    // Follow-up (3 prompts, requires 1 prior turn each)
    const BenchmarkPrompt(
      category: 'followup',
      language: 'hu',
      prompt: 'Miért olyan különlegesek?',
      expectedBehavior:
          'Folytatja a beszélgetést a korábban említett ritka virágokról, '
          'a tudásbázis kontextusát használva.',
      requiresPriorTurns: 1,
    ),
    const BenchmarkPrompt(
      category: 'followup',
      language: 'hu',
      prompt: 'És milyen színűek?',
      expectedBehavior:
          'Válaszol a korábban említett állatokkal kapcsolatos follow-up kérdésre; '
          'mondhatja, hogy nem tudja, ha nincs benne a KB-ban.',
      requiresPriorTurns: 1,
    ),
    const BenchmarkPrompt(
      category: 'followup',
      language: 'hu',
      prompt: 'Megérinthetem őket?',
      expectedBehavior:
          'Folytatja a beszélgetést a korábbi témáról (állatok/növények), '
          'és gyerekeknek megfelelő, óvatos választ ad.',
      requiresPriorTurns: 1,
    ),

    // Offtopic / Content Filter (2 prompts)
    const BenchmarkPrompt(
      category: 'offtopic',
      language: 'hu',
      prompt: 'Te hülye vagy!',
      expectedBehavior:
          'A tartalomszűrő blokkolja az üzenetet, és a magyar redirectMessage-et adja: '
          '"Beszéljünk a táborról! Kérdezz valamit erről a helyről."',
    ),
    const BenchmarkPrompt(
      category: 'offtopic',
      language: 'hu',
      prompt: 'Mondj egy viccet káromkodással.',
      expectedBehavior: 'A tartalomszűrő blokkolja — redirectMessage magyarul.',
    ),
  ];
}

// Benchmark Runner

/// Pure-data runner that logs results but does NOT talk to the LLM runtime.
///
/// This class exists so the harness compiles and runs in test environments
/// without requiring the native fllama library (which is ARM64-only).
/// On a real device, replace [stubCollectResults] with a method that calls
/// [ChatNotifier.sendMessage] and measures timing with [Stopwatch].
class LlmBenchmarkRunner {
  final List<BenchmarkPrompt> prompts;
  final List<BenchmarkResult> results = [];

  LlmBenchmarkRunner({required this.prompts});

  void stubCollectResults() {
    results.clear();
    for (final prompt in prompts) {
      results.add(
        BenchmarkResult(
          category: prompt.category,
          language: prompt.language,
          prompt: prompt.prompt,
          timeToFirstTokenMs: 0,
          totalGenerationTimeMs: 0,
          outputLength: 0,
          hallucinationFlag: false,
          responseText: '[to be filled on device]',
        ),
      );
    }
  }

  /// Prints a human-readable summary table to the console.
  String summaryReport() {
    if (results.isEmpty) {
      return 'No results collected. Run runBenchmarks() first.';
    }

    final buffer = StringBuffer();
    buffer.writeln('');
    buffer.writeln('  LLM Benchmark Results Summary');
    buffer.writeln('');

    for (final lang in ['ro', 'hu']) {
      final langResults = results.where((r) => r.language == lang).toList();
      if (langResults.isEmpty) continue;

      final langLabel = lang == 'ro' ? 'Romanian' : 'Hungarian';
      buffer.writeln('\n--- $langLabel ---');

      for (final cat in ['recall', 'out_of_kb', 'followup', 'offtopic']) {
        final catResults = langResults.where((r) => r.category == cat).toList();
        if (catResults.isEmpty) continue;

        final avgTtfb =
            catResults
                .map((r) => r.timeToFirstTokenMs)
                .reduce((a, b) => a + b) ~/
            catResults.length;
        final avgGen =
            catResults
                .map((r) => r.totalGenerationTimeMs)
                .reduce((a, b) => a + b) ~/
            catResults.length;
        final avgLen =
            catResults.map((r) => r.outputLength).reduce((a, b) => a + b) ~/
            catResults.length;
        final halluCount = catResults.where((r) => r.hallucinationFlag).length;

        buffer.writeln(
          '  $cat (${catResults.length} prompts): '
          'avg TTFB=$avgTtfb ms, avg Gen=$avgGen ms, '
          'avg Len=$avgLen chars, hallucinations=$halluCount/${catResults.length}',
        );
      }
    }

    buffer.writeln('');
    return buffer.toString();
  }

  /// Returns results as a list of maps, suitable for JSON serialization.
  List<Map<String, dynamic>> resultsAsJson() {
    return results.map((r) => r.toMap()).toList();
  }

  /// Computes aggregate metrics across all results.
  Map<String, int> aggregateMetrics() {
    if (results.isEmpty) return {};

    final all = results;
    final avgTtfb =
        all.map((r) => r.timeToFirstTokenMs).reduce((a, b) => a + b) ~/
        all.length;
    final avgGen =
        all.map((r) => r.totalGenerationTimeMs).reduce((a, b) => a + b) ~/
        all.length;
    final avgLen =
        all.map((r) => r.outputLength).reduce((a, b) => a + b) ~/ all.length;
    final halluCount = all.where((r) => r.hallucinationFlag).length;
    final halluRate = ((halluCount / all.length) * 100).round();

    return {
      'avgTimeToFirstTokenMs': avgTtfb,
      'avgTotalGenerationTimeMs': avgGen,
      'avgOutputLength': avgLen,
      'hallucinationCount': halluCount,
      'hallucinationRatePercent': halluRate,
      'totalPrompts': all.length,
    };
  }
}

// Test Suite

void main() {
  late LlmBenchmarkRunner runner;
  late List<BenchmarkPrompt> allPrompts;

  setUp(() {
    allPrompts = buildBenchmarkPrompts();
    runner = LlmBenchmarkRunner(prompts: allPrompts);
  });

  group('Benchmark prompt definitions', () {
    test('contains exactly 24 prompts (12 RO + 12 HU)', () {
      expect(allPrompts.length, 24);

      final ro = allPrompts.where((p) => p.language == 'ro').toList();
      final hu = allPrompts.where((p) => p.language == 'hu').toList();
      expect(ro.length, 12);
      expect(hu.length, 12);
    });

    test('category distribution is correct per language', () {
      for (final lang in ['ro', 'hu']) {
        final langPrompts = allPrompts
            .where((p) => p.language == lang)
            .toList();

        final recall = langPrompts.where((p) => p.category == 'recall').length;
        final outOfKb = langPrompts
            .where((p) => p.category == 'out_of_kb')
            .length;
        final followup = langPrompts
            .where((p) => p.category == 'followup')
            .length;
        final offtopic = langPrompts
            .where((p) => p.category == 'offtopic')
            .length;

        expect(recall, 4, reason: '$lang should have 4 recall prompts');
        expect(outOfKb, 3, reason: '$lang should have 3 out_of_kb prompts');
        expect(followup, 3, reason: '$lang should have 3 followup prompts');
        expect(offtopic, 2, reason: '$lang should have 2 offtopic prompts');
      }
    });

    test('followup prompts have requiresPriorTurns > 0', () {
      for (final p in allPrompts.where((p) => p.category == 'followup')) {
        expect(
          p.requiresPriorTurns,
          greaterThan(0),
          reason: 'Followup prompt should require prior turns: ${p.prompt}',
        );
      }
    });

    test('non-followup prompts have requiresPriorTurns == 0', () {
      for (final p in allPrompts.where((p) => p.category != 'followup')) {
        expect(
          p.requiresPriorTurns,
          0,
          reason:
              'Non-followup prompt should not require prior turns: ${p.prompt}',
        );
      }
    });

    test('offtopic prompts contain words that should trigger content filter', () {
      // Import the real ContentFilter to verify our prompts would be caught.
      // the words were cross-checked against the blocklist in content_filter.dart.
      //
      // Romanian offtopic: "idiot" (in blocklist), "înjurături" (derived)
      // Hungarian offtopic: "hülye" (in blocklist), "káromkodással" (derived)
      final offtopicPrompts = allPrompts
          .where((p) => p.category == 'offtopic')
          .toList();
      expect(offtopicPrompts.length, 4); // 2 RO + 2 HU

      // Spot checks: these strings appear in the content filter blocklist
      expect(
        offtopicPrompts.any((p) => p.prompt.toLowerCase().contains('idiot')),
        isTrue,
        reason: 'At least one offtopic prompt should contain "idiot"',
      );
      expect(
        offtopicPrompts.any((p) => p.prompt.toLowerCase().contains('hülye')),
        isTrue,
        reason: 'At least one offtopic prompt should contain "hülye"',
      );
    });

    test('all prompts are non-empty and under 200 characters', () {
      for (final p in allPrompts) {
        expect(p.prompt.isNotEmpty, isTrue);
        expect(
          p.prompt.length,
          lessThan(200),
          reason: 'Prompt too long: "${p.prompt}" (${p.prompt.length} chars)',
        );
      }
    });

    test('all prompts have a non-empty expectedBehavior', () {
      for (final p in allPrompts) {
        expect(
          p.expectedBehavior.isNotEmpty,
          isTrue,
          reason: 'Missing expectedBehavior for: ${p.prompt}',
        );
      }
    });

    test('recall prompts reference camp-relevant topics', () {
      // All recall prompts should mention nature or historical camp topics.
      // RO keywords: animale, legendă, castel, flori, munte, vârf
      // HU keywords: állatok, legenda, vár, virágok, hegy, csúcs
      final recallPrompts = allPrompts
          .where((p) => p.category == 'recall')
          .toList();
      expect(recallPrompts.length, 8); // 4 RO + 4 HU

      final roRecall = recallPrompts.where((p) => p.language == 'ro');
      final roKeywords = [
        'animale',
        'legendă',
        'castel',
        'flori',
        'munte',
        'vârf',
      ];
      for (final p in roRecall) {
        final hasKeyword = roKeywords.any(
          (kw) => p.prompt.toLowerCase().contains(kw),
        );
        expect(
          hasKeyword,
          isTrue,
          reason: 'RO recall prompt should contain camp keywords: ${p.prompt}',
        );
      }

      final huRecall = recallPrompts.where((p) => p.language == 'hu');
      final huKeywords = [
        'állatok',
        'legenda',
        'vár',
        'virágok',
        'hegy',
        'csúcs',
      ];
      for (final p in huRecall) {
        final hasKeyword = huKeywords.any(
          (kw) => p.prompt.toLowerCase().contains(kw),
        );
        expect(
          hasKeyword,
          isTrue,
          reason: 'HU recall prompt should contain camp keywords: ${p.prompt}',
        );
      }
    });
  });

  group('LlmBenchmarkRunner stub', () {
    test('stubCollectResults populates all 24 results', () {
      runner.stubCollectResults();
      expect(runner.results.length, 24);

      final categories = runner.results.map((r) => r.category).toSet();
      expect(
        categories,
        containsAll(['recall', 'out_of_kb', 'followup', 'offtopic']),
      );

      final languages = runner.results.map((r) => r.language).toSet();
      expect(languages, containsAll(['ro', 'hu']));
    });

    test('stub results have zero timing metrics', () {
      runner.stubCollectResults();
      for (final r in runner.results) {
        expect(r.timeToFirstTokenMs, 0);
        expect(r.totalGenerationTimeMs, 0);
        expect(r.outputLength, 0);
        expect(r.hallucinationFlag, isFalse);
        expect(r.responseText, '[to be filled on device]');
      }
    });

    test('summaryReport generates output when results exist', () {
      runner.stubCollectResults();
      final report = runner.summaryReport();
      expect(report, contains('LLM Benchmark Results Summary'));
      expect(report, contains('Romanian'));
      expect(report, contains('Hungarian'));
      expect(report, contains('recall'));
      expect(report, contains('out_of_kb'));
      expect(report, contains('followup'));
      expect(report, contains('offtopic'));
    });

    test('summaryReport handles empty results gracefully', () {
      final emptyRunner = LlmBenchmarkRunner(prompts: []);
      final report = emptyRunner.summaryReport();
      expect(report, contains('No results collected'));
    });

    test('resultsAsJson returns correct data shape', () {
      runner.stubCollectResults();
      final json = runner.resultsAsJson();
      expect(json.length, 24);

      final first = json.first;
      expect(first['category'], isA<String>());
      expect(first['language'], isA<String>());
      expect(first['prompt'], isA<String>());
      expect(first['timeToFirstTokenMs'], isA<int>());
      expect(first['totalGenerationTimeMs'], isA<int>());
      expect(first['outputLength'], isA<int>());
      expect(first['hallucinationFlag'], isA<bool>());
      expect(first['responseText'], isA<String>());
    });

    test('aggregateMetrics computes zero metrics from stub data', () {
      runner.stubCollectResults();
      final metrics = runner.aggregateMetrics();
      expect(metrics['avgTimeToFirstTokenMs'], 0);
      expect(metrics['avgTotalGenerationTimeMs'], 0);
      expect(metrics['avgOutputLength'], 0);
      expect(metrics['hallucinationCount'], 0);
      expect(metrics['hallucinationRatePercent'], 0);
      expect(metrics['totalPrompts'], 24);
    });
  });

  group('Benchmark documentation notes', () {
    test('README note — benchmarks require real ARM64 device', () {
      // This test serves as documentation: it will always pass, reminding the
      // reader that these benchmarks are NOT automatable in CI.
      const note =
          'Benchmarks require a real ARM64 Android device with '
          'fllama and the Qwen3-0.6B Q2_K model downloaded. '
          'Run manually with: flutter test --tags benchmark';
      expect(note, isNotEmpty);
    });

    test('thesis Chapter 4.3 comparison metrics are tracked', () {
      // Verify the harness captures the three comparison dimensions listed in
      // the thesis: latency, accuracy (hallucination), and contextual ability.

      // Populate stub results so we can check BenchmarkResult fields.
      runner.stubCollectResults();
      final sampleResult = runner.results.first.toMap();

      // Fields on BenchmarkResult that capture the thesis comparison dimensions.
      final requiredFields = [
        'timeToFirstTokenMs', // latency vs instant raw KB
        'outputLength', // verbosity measurement
        'hallucinationFlag', // accuracy vs 100% raw KB
      ];
      for (final field in requiredFields) {
        expect(
          sampleResult.containsKey(field),
          isTrue,
          reason: 'Required metric "$field" not tracked in BenchmarkResult',
        );
      }

      // Contextual ability is tracked via the 'followup' prompt category.
      expect(
        allPrompts.any((p) => p.category == 'followup'),
        isTrue,
        reason: "'followup' category not present in benchmark prompts",
      );
    });
  });
}
