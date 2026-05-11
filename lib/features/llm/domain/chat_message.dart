enum ChatRole { user, assistant, system }

class ChatMessage {
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.user(String content) {
    return ChatMessage(
      role: ChatRole.user,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.assistant(String content) {
    return ChatMessage(
      role: ChatRole.assistant,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  factory ChatMessage.system(String content) {
    return ChatMessage(
      role: ChatRole.system,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  /// Rough token estimate: ~1 token per 4 chars for RO/HU text.
  int get estimatedTokens => (content.length / 4).ceil();

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: ChatRole.values.firstWhere((r) => r.name == json['role']),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
