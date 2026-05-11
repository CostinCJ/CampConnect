// ignore_for_file: depend_on_referenced_packages
// path_provider_platform_interface is a transitive dependency of path_provider
// and is imported to provide a test-only fake PathProviderPlatform.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/features/llm/data/llm_runtime.dart';

/// A fake [PathProviderPlatform] that returns a controllable temp directory
/// instead of the real application documents directory, so tests can create
/// and verify model files without relying on platform channels.
class FakePathProvider extends PathProviderPlatform {
  final String documentsPath;

  FakePathProvider(this.documentsPath);

  @override
  Future<String> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => null;

  @override
  Future<String?> getLibraryPath() async => null;

  @override
  Future<String?> getTemporaryPath() async => null;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('llm_runtime_test_');
    SharedPreferences.setMockInitialValues({});
    PathProviderPlatform.instance = FakePathProvider(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LlmRuntime state', () {
    test('initial state is idle', () {
      final runtime = LlmRuntime();
      expect(runtime.state, LlmState.idle);
      expect(runtime.isReady, isFalse);
      expect(runtime.isGenerating, isFalse);
    });

    test('transitions to disposed after dispose()', () async {
      final runtime = LlmRuntime();
      await runtime.dispose();
      expect(runtime.state, LlmState.disposed);
      expect(runtime.isReady, isFalse);
      expect(runtime.isGenerating, isFalse);
    });

    test(
        'state goes idle → loading → idle when loadModel fails (no file)',
        () async {
      final runtime = LlmRuntime();
      expect(runtime.state, LlmState.idle);

      try {
        await runtime.loadModel();
        fail('Expected loadModel to throw');
      } catch (_) {
        // Expected: model file does not exist in temp dir.
      }

      // Verify state returned to idle after failure.
      expect(runtime.state, LlmState.idle);
    });
  });

  group('loadModel file validation', () {
    test('throws Exception when model file does not exist', () async {
      final runtime = LlmRuntime();

      expect(
        () => runtime.loadModel(),
        throwsA(isA<Exception>()),
      );
    });

    test('throws Exception when model file is smaller than 100 MB', () async {
      // Create a tiny file at the expected model path.
      final modelFile = File(
        '${tempDir.path}/${AppConstants.llmModelFileName}',
      );
      modelFile.createSync(recursive: true);
      modelFile.writeAsBytesSync(List.filled(1024, 0)); // 1 KB

      final runtime = LlmRuntime();

      try {
        await runtime.loadModel();
        fail('Expected loadModel to throw for small file');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('too small'));
      }

      // State should have reset to idle after the caught error.
      expect(runtime.state, LlmState.idle);
    });
  });

  group('generateChat state guard', () {
    test('throws StateError when model is not loaded', () async {
      final runtime = LlmRuntime();

      // generateChat is an async* generator; the error surfaces when the
      // returned stream is listened to.  Convert to a Future via .toList().
      await expectLater(
        runtime.generateChat(
          systemPrompt: 'Test',
          messages: [],
        ).toList(),
        throwsA(isA<StateError>()),
      );
    });

    test('throws StateError when runtime has been disposed', () async {
      final runtime = LlmRuntime();
      await runtime.dispose();

      await expectLater(
        runtime.generateChat(
          systemPrompt: 'Test',
          messages: [],
        ).toList(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('stopGeneration', () {
    test('safely no-ops when not generating', () async {
      final runtime = LlmRuntime();
      // Should not throw when called from idle state.
      await runtime.stopGeneration();
      expect(runtime.state, LlmState.idle);
    });

    test('safely no-ops after dispose', () async {
      final runtime = LlmRuntime();
      await runtime.dispose();
      // Should not throw; dispose only cancels subscription + releases context.
      await runtime.stopGeneration();
      expect(runtime.state, LlmState.disposed);
    });
  });

  group('dispose', () {
    test('is idempotent', () async {
      final runtime = LlmRuntime();
      await runtime.dispose();
      await runtime.dispose(); // Second call must not throw.
      expect(runtime.state, LlmState.disposed);
    });

    test('subsequent loadModel after dispose fails gracefully', () async {
      final runtime = LlmRuntime();
      await runtime.dispose();

      // loadModel checks if state is ready/loading at the top;
      // disposed is neither, so it proceeds to loading then fails on file.
      try {
        await runtime.loadModel();
      } catch (_) {
        // Expected to fail — no model file.
      }

      // State should be back to idle (the catch in loadModel resets to idle
      // regardless of prior state as long as it wasn't ready/loading).
      expect(runtime.state, LlmState.idle);
    });
  });
}
