import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/llm/domain/chat_message.dart';
import 'package:camp_connect/features/llm/providers/llm_providers.dart';
import 'package:camp_connect/features/map/domain/location.dart';

class LlmChatWidget extends ConsumerStatefulWidget {
  const LlmChatWidget({super.key, required this.masterLocation});

  final Location masterLocation;

  @override
  ConsumerState<LlmChatWidget> createState() => _LlmChatWidgetState();
}

class _LlmChatWidgetState extends ConsumerState<LlmChatWidget> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref
        .read(chatProvider(widget.masterLocation.id).notifier)
        .sendMessage(text, widget.masterLocation);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chatState = ref.watch(chatProvider(widget.masterLocation.id));

    // Auto-scroll whenever messages or streaming response changes.
    ref.listen(chatProvider(widget.masterLocation.id), (previous, next) {
      final prevCount = previous?.messages.length ?? 0;
      final nextCount = next.messages.length;
      final prevStreaming = previous?.streamingResponse;
      final nextStreaming = next.streamingResponse;

      if (nextCount != prevCount || prevStreaming != nextStreaming) {
        _scrollToBottom();
      }
    });

    final bool hasMessages = chatState.messages.isNotEmpty ||
        chatState.isGenerating ||
        chatState.streamingResponse != null;

    return Column(
      children: [
        // ── Top bar: "New conversation" button ──────────────────────────────
        if (hasMessages)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: chatState.isGenerating
                      ? null
                      : () => ref
                          .read(chatProvider(widget.masterLocation.id).notifier)
                          .clearConversation(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n.newConversation),
                ),
              ],
            ),
          ),

        // ── Error banner ────────────────────────────────────────────────────
        if (chatState.errorMessage != null)
          _ErrorBanner(message: l10n.llmError),

        // ── Message list ────────────────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: chatState.messages.length +
                (chatState.isGenerating ? 1 : 0),
            itemBuilder: (context, index) {
              // Streaming / in-progress assistant bubble at the end.
              if (index == chatState.messages.length && chatState.isGenerating) {
                return _AssistantBubble(
                  content: chatState.streamingResponse ?? '',
                  isStreaming: true,
                );
              }

              final message = chatState.messages[index];
              // Skip system messages — they are not displayed to the user.
              if (message.role == ChatRole.system) {
                return const SizedBox.shrink();
              }

              if (message.role == ChatRole.user) {
                return _UserBubble(content: message.content);
              }

              return _AssistantBubble(
                content: message.content,
                isStreaming: false,
              );
            },
          ),
        ),

        // ── Input area ──────────────────────────────────────────────────────
        _InputBar(
          controller: _textController,
          placeholder: l10n.chatPlaceholder,
          isDisabled: chatState.isGenerating,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private: Error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private: User bubble (right-aligned, primaryContainer color)
// ─────────────────────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          content,
          style: TextStyle(color: colorScheme.onPrimaryContainer),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private: Assistant bubble (left-aligned, surfaceContainerHighest color)
// ─────────────────────────────────────────────────────────────────────────────

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({
    required this.content,
    required this.isStreaming,
  });

  final String content;
  final bool isStreaming;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (content.isNotEmpty)
              Text(
                content,
                style: TextStyle(color: colorScheme.onSurface),
              ),
            if (isStreaming) ...[
              if (content.isNotEmpty) const SizedBox(height: 6),
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private: Input bar
// ─────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.placeholder,
    required this.isDisabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final String placeholder;
  final bool isDisabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isDisabled,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: isDisabled ? null : (_) => onSend(),
                decoration: InputDecoration(
                  hintText: placeholder,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isDisabled ? null : onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
