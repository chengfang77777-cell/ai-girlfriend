import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

@JsonSerializable()
@HiveType(typeId: 0)
class Message {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String characterId;

  @HiveField(2)
  final String role;

  @HiveField(3)
  final String content;

  @HiveField(4)
  final DateTime timestamp;

  @HiveField(5)
  final String emotion;

  @HiveField(6)
  final String? action;

  const Message({
    required this.id,
    required this.characterId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.emotion = 'neutral',
    this.action,
  });

  /// Whether this message was sent by the user.
  bool get isUser => role == 'user';

  /// Whether this message was sent by the AI assistant.
  bool get isAssistant => role == 'assistant';

  /// Whether this message is a system message.
  bool get isSystem => role == 'system';

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  Map<String, dynamic> toJson() => _$MessageToJson(this);

  /// Creates a copy of this Message with the given fields replaced.
  Message copyWith({
    String? id,
    String? characterId,
    String? role,
    String? content,
    DateTime? timestamp,
    String? emotion,
  }) {
    return Message(
      id: id ?? this.id,
      characterId: characterId ?? this.characterId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      emotion: emotion ?? this.emotion,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, characterId: $characterId, role: $role, '
        'content: ${content.length > 30 ? '${content.substring(0, 30)}...' : content}, '
        'timestamp: $timestamp, emotion: $emotion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
