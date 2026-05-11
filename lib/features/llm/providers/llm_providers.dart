import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:camp_connect/features/llm/data/chat_cache_repository.dart';
import 'package:camp_connect/features/llm/data/content_filter.dart';
import 'package:camp_connect/features/llm/data/llm_runtime.dart';
import 'package:camp_connect/features/llm/data/model_downloader.dart';
import 'package:camp_connect/features/llm/domain/chat_message.dart';
import 'package:camp_connect/features/llm/domain/prompt_templates.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/shared/providers/providers.dart';

// ---------------------------------------------------------------------------
// 1. Content Filter Provider
// ---------------------------------------------------------------------------

final contentFilterProvider = Provider<ContentFilter>((ref) {
  return ContentFilter();
});

// ---------------------------------------------------------------------------
// 2. Chat Cache Repository Provider
// ---------------------------------------------------------------------------

final chatCacheRepositoryProvider = FutureProvider<ChatCacheRepository>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return ChatCacheRepository(cacheDir: dir.path);
});

// ---------------------------------------------------------------------------
// 3. LLM Runtime Provider
// ---------------------------------------------------------------------------

final llmRuntimeProvider =
    StateNotifierProvider<LlmRuntimeNotifier, LlmState>((ref) {
  return LlmRuntimeNotifier();
});

class LlmRuntimeNotifier extends StateNotifier<LlmState> {
  final LlmRuntime _runtime = LlmRuntime();

  LlmRuntimeNotifier() : super(LlmState.idle);

  LlmRuntime get runtime => _runtime;

  Future<void> loadModel() async {
    state = LlmState.loading;
    try {
      await _runtime.loadModel();
      state = _runtime.state;
    } catch (e) {
      state = LlmState.idle;
      rethrow;
    }
  }

  Stream<String> generateChat({
    required String systemPrompt,
    required List<ChatMessage> messages,
  }) async* {
    yield* _runtime.generateChat(
      systemPrompt: systemPrompt,
      messages: messages,
    );
    state = _runtime.state;
  }

  Future<void> stopGeneration() async {
    await _runtime.stopGeneration();
    state = _runtime.state;
  }

  /// Releases the loaded model from memory without destroying this notifier.
  /// Safe to call when the app goes to background.
  Future<void> releaseModel() async {
    await _runtime.dispose();
    if (mounted) {
      state = LlmState.idle;
    }
  }

  @override
  Future<void> dispose() async {
    await _runtime.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// 4. Model Download Provider
// ---------------------------------------------------------------------------

enum DownloadStatus { notStarted, downloading, completed, failed }

class DownloadState {
  final DownloadStatus status;
  final double progress;
  final String? errorMessage;

  const DownloadState({
    this.status = DownloadStatus.notStarted,
    this.progress = 0.0,
    this.errorMessage,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return DownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final modelDownloadProvider =
    StateNotifierProvider<ModelDownloadNotifier, DownloadState>((ref) {
  return ModelDownloadNotifier(ref);
});

class ModelDownloadNotifier extends StateNotifier<DownloadState> {
  final Ref _ref;

  ModelDownloadNotifier(this._ref) : super(const DownloadState());

  Future<void> startDownload() async {
    if (state.status == DownloadStatus.downloading) return;

    state = const DownloadState(status: DownloadStatus.downloading, progress: 0.0);

    final downloader = ModelDownloader(
      onProgress: (progress) {
        if (mounted) {
          state = state.copyWith(progress: progress);
        }
      },
    );

    try {
      await downloader.download();

      if (mounted) {
        state = const DownloadState(
          status: DownloadStatus.completed,
          progress: 1.0,
        );
        await _ref
            .read(settingsProvider.notifier)
            .setModelDownloaded(true);
      }
    } catch (e) {
      if (mounted) {
        state = DownloadState(
          status: DownloadStatus.failed,
          progress: state.progress,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> deleteModel() async {
    final downloader = ModelDownloader();
    await downloader.delete();
    await _ref.read(settingsProvider.notifier).setModelDownloaded(false);
    if (mounted) {
      state = const DownloadState();
    }
  }
}

// ---------------------------------------------------------------------------
// 5. Chat Provider (per-location family)
// ---------------------------------------------------------------------------

class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final bool isLoading;
  final String? errorMessage;
  final String? streamingResponse;

  const ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.isLoading = false,
    this.errorMessage,
    this.streamingResponse,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    bool? isLoading,
    String? errorMessage,
    String? streamingResponse,
    bool clearError = false,
    bool clearStreaming = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      streamingResponse:
          clearStreaming ? null : (streamingResponse ?? this.streamingResponse),
    );
  }
}

/// Token budget for the conversation history sent to the model.
/// Leaves room for the system prompt and generated response within the
/// 1536-token context window.
const _kChatTokenBudget = 1236;

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, locationId) {
    return ChatNotifier(ref, locationId);
  },
);

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  final String _locationId;

  StreamSubscription<String>? _generateSubscription;

  ChatNotifier(this._ref, this._locationId) : super(const ChatState()) {
    _loadCachedMessages();
  }

  Future<void> _loadCachedMessages() async {
    state = state.copyWith(isLoading: true);
    try {
      final cacheRepo = await _ref.read(chatCacheRepositoryProvider.future);
      final language = _ref.read(settingsProvider).language;
      final messages = await cacheRepo.load(_locationId, language);
      if (mounted) {
        state = state.copyWith(messages: messages, isLoading: false);
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> sendMessage(String text, Location masterLocation) async {
    if (text.trim().isEmpty) return;
    if (state.isGenerating) return;

    final language = _ref.read(settingsProvider).language;
    final contentFilter = _ref.read(contentFilterProvider);

    // Content filter check
    if (!contentFilter.isAllowed(text)) {
      final redirect = contentFilter.redirectMessage(language);
      if (mounted) {
        state = state.copyWith(
          messages: [
            ...state.messages,
            ChatMessage.user(text),
            ChatMessage.assistant(redirect),
          ],
        );
        await _saveMessages();
      }
      return;
    }

    final userMessage = ChatMessage.user(text);
    final updatedMessages = [...state.messages, userMessage];

    state = state.copyWith(
      messages: updatedMessages,
      isGenerating: true,
      clearError: true,
      clearStreaming: false,
      streamingResponse: '',
    );

    final runtimeState = _ref.read(llmRuntimeProvider);

    if (runtimeState != LlmState.ready) {
      if (mounted) {
        state = state.copyWith(
          isGenerating: false,
          errorMessage: language == 'hu'
              ? 'A modell nincs betöltve.'
              : 'Modelul nu este încărcat.',
        );
      }
      return;
    }

    // Build system prompt and trim conversation history
    final trimmedHistory = _trimToTokenBudget(updatedMessages);
    // When KB is empty, fall back to the Location's main description as context
    var kb = masterLocation.knowledgeBase;
    if (kb.isEmpty && masterLocation.description.isNotEmpty) {
      kb = KnowledgeBase(
        description: masterLocation.description,
      );
    }
    final systemPrompt = PromptTemplates.buildSystemPrompt(
      locationName: masterLocation.name,
      knowledgeBase: kb,
      language: language,
    );

    String accumulated = '';

    try {
      await _generateSubscription?.cancel();

      final runtimeNotifier = _ref.read(llmRuntimeProvider.notifier);
      final completer = Completer<void>();
      _generateSubscription = runtimeNotifier.generateChat(
        systemPrompt: systemPrompt,
        messages: trimmedHistory,
      ).listen(
        (chunk) {
          accumulated = chunk;
          if (mounted) {
            state = state.copyWith(streamingResponse: accumulated);
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!completer.isCompleted) completer.completeError(error, stack);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future;

      if (mounted) {
        final assistantMessage = ChatMessage.assistant(accumulated);
        final finalMessages = [...updatedMessages, assistantMessage];
        state = state.copyWith(
          messages: finalMessages,
          isGenerating: false,
          clearStreaming: true,
        );
        await _saveMessages();
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isGenerating: false,
          clearStreaming: true,
          errorMessage: e.toString(),
        );
      }
    }
  }

  Future<void> clearConversation() async {
    state = const ChatState();
    try {
      final cacheRepo = await _ref.read(chatCacheRepositoryProvider.future);
      final language = _ref.read(settingsProvider).language;
      await cacheRepo.clear(_locationId, language);
    } catch (_) {
      // Best-effort clear
    }
  }

  Future<void> stopGeneration() async {
    await _generateSubscription?.cancel();
    _generateSubscription = null;
    final runtime = _ref.read(llmRuntimeProvider.notifier).runtime;
    await runtime.stopGeneration();
    if (mounted) {
      state = state.copyWith(isGenerating: false, clearStreaming: true);
    }
  }

  Future<void> _saveMessages() async {
    try {
      final cacheRepo = await _ref.read(chatCacheRepositoryProvider.future);
      final language = _ref.read(settingsProvider).language;
      await cacheRepo.save(_locationId, language, state.messages);
    } catch (_) {
      // Best-effort save
    }
  }

  /// Trims the message list (excluding system messages) so the total estimated
  /// token count stays within [_kChatTokenBudget]. Keeps the newest messages.
  List<ChatMessage> _trimToTokenBudget(List<ChatMessage> messages) {
    final nonSystem =
        messages.where((m) => m.role != ChatRole.system).toList();

    int total = 0;
    final kept = <ChatMessage>[];

    for (int i = nonSystem.length - 1; i >= 0; i--) {
      final tokens = nonSystem[i].estimatedTokens;
      if (total + tokens > _kChatTokenBudget) break;
      total += tokens;
      kept.insert(0, nonSystem[i]);
    }

    return kept;
  }

  @override
  void dispose() {
    _generateSubscription?.cancel();
    super.dispose();
  }
}
