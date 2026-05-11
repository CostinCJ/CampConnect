import 'dart:async';
import 'dart:io';

import 'package:fllama/fllama.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/features/llm/domain/chat_message.dart';

enum LlmState { idle, loading, ready, generating, disposed }

class LlmRuntime {
  LlmState _state = LlmState.idle;
  int _activeRequestId = -1;

  LlmState get state => _state;
  bool get isReady => _state == LlmState.ready;
  bool get isGenerating => _state == LlmState.generating;

  Future<String> get modelPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/${AppConstants.llmModelFileName}';
  }

  Future<bool> get isModelDownloaded async {
    final path = await modelPath;
    return File(path).existsSync();
  }

  Future<void> loadModel() async {
    debugPrint('[LLM] loadModel called, state=$_state');
    if (_state == LlmState.ready || _state == LlmState.loading) return;

    _state = LlmState.loading;

    try {
      final path = await modelPath;
      final file = File(path);

      final exists = file.existsSync();
      debugPrint('[LLM] loadModel: path=$path, exists=$exists');
      if (!exists) {
        throw Exception('Model file not found at $path');
      }
      final fileSize = file.lengthSync();
      debugPrint('[LLM] loadModel: fileSize=$fileSize');
      if (fileSize < 100 * 1024 * 1024) {
        throw Exception('Model file too small ($fileSize bytes), likely corrupt');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.keyLlmLoadAttempted, true);
      await prefs.setBool(AppConstants.keyLlmLoadSucceeded, false);

      // fllamaChat loads the model lazily on first inference call;
      // no native context init is needed here. File verified = ready.
      debugPrint('[LLM] loadModel: file verified, runtime ready');

      _state = LlmState.ready;
      await prefs.setBool(AppConstants.keyLlmLoadSucceeded, true);
    } catch (e) {
      debugPrint('[LLM] loadModel: failed: $e');
      _state = LlmState.idle;
      rethrow;
    }
  }

  Stream<String> generateChat({
    required String systemPrompt,
    required List<ChatMessage> messages,
  }) async* {
    if (_state != LlmState.ready) {
      throw StateError('Model not loaded. Current state: $_state');
    }

    _state = LlmState.generating;
    final path = await modelPath;

    final fllamaMessages = <Message>[
      Message(Role.system, systemPrompt),
      for (final msg in messages)
        Message(
          msg.role == ChatRole.user ? Role.user : Role.assistant,
          msg.content,
        ),
    ];

    debugPrint('[LLM] generateChat: sending ${fllamaMessages.length} messages');

    final controller = StreamController<String>();
    var callbackReceivedDone = false;

    try {
      _activeRequestId = await fllamaChat(
        OpenAiRequest(
          maxTokens: 512,
          messages: fllamaMessages,
          modelPath: path,
          contextSize: 2048,
          temperature: 0.3,
          topP: 0.9,
          presencePenalty: 1.1,
          frequencyPenalty: 0.1,
          numGpuLayers: 0,
        ),
        (String response, _, bool done) {
          if (!controller.isClosed) {
            controller.add(response);
            if (done) {
              callbackReceivedDone = true;
              controller.close();
            }
          }
        },
      );

      yield* controller.stream;
    } finally {
      if (!callbackReceivedDone && !controller.isClosed) {
        controller.close();
      }
      if (_state == LlmState.generating) {
        _state = LlmState.ready;
      }
      _activeRequestId = -1;
    }
  }

  Future<void> stopGeneration() async {
    if (_activeRequestId < 0) return;
    try {
      fllamaCancelInference(_activeRequestId);
      debugPrint('[LLM] stopGeneration: cancelled request $_activeRequestId');
    } catch (e) {
      debugPrint('[LLM] stopGeneration error: $e');
    }
    // The fllamaChat callback will fire with done=true,
    // which transitions state via the generateChat finally block.
    // If we reach here and are still generating, force the transition.
    if (_state == LlmState.generating) {
      _state = LlmState.ready;
    }
    _activeRequestId = -1;
  }

  Future<void> dispose() async {
    // Cancel any active inference before disposing.
    if (_activeRequestId >= 0) {
      try {
        fllamaCancelInference(_activeRequestId);
        debugPrint('[LLM] dispose: cancelled request $_activeRequestId');
      } catch (e) {
        debugPrint('[LLM] dispose cancelInference error: $e');
      }
      _activeRequestId = -1;
    }
    _state = LlmState.disposed;
  }
}
