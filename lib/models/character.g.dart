// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'character.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CharacterAdapter extends TypeAdapter<Character> {
  @override
  final int typeId = 1;

  @override
  Character read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Character(
      id: fields[0] as String,
      name: fields[1] as String,
      age: fields[2] as int,
      personalityTags: (fields[3] as List).cast<String>(),
      speakingStyle: fields[4] as String,
      avatarModelPath: fields[5] as String,
      voiceName: fields[6] as String,
      isPreset: fields[7] as bool,
      avatarImagePath: fields[8] as String?,
      voiceDescription: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Character obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.age)
      ..writeByte(3)
      ..write(obj.personalityTags)
      ..writeByte(4)
      ..write(obj.speakingStyle)
      ..writeByte(5)
      ..write(obj.avatarModelPath)
      ..writeByte(6)
      ..write(obj.voiceName)
      ..writeByte(7)
      ..write(obj.isPreset)
      ..writeByte(8)
      ..write(obj.avatarImagePath)
      ..writeByte(9)
      ..write(obj.voiceDescription);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CharacterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Character _$CharacterFromJson(Map<String, dynamic> json) => Character(
      id: json['id'] as String,
      name: json['name'] as String,
      age: (json['age'] as num?)?.toInt() ?? 18,
      personalityTags: (json['personalityTags'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      speakingStyle: json['speakingStyle'] as String,
      avatarModelPath: json['avatarModelPath'] as String,
      voiceName: json['voiceName'] as String? ?? 'zh-CN-XiaoxiaoNeural',
      isPreset: json['isPreset'] as bool? ?? false,
      avatarImagePath: json['avatarImagePath'] as String?,
      voiceDescription: json['voiceDescription'] as String?,
    );

Map<String, dynamic> _$CharacterToJson(Character instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'age': instance.age,
      'personalityTags': instance.personalityTags,
      'speakingStyle': instance.speakingStyle,
      'avatarModelPath': instance.avatarModelPath,
      'voiceName': instance.voiceName,
      'isPreset': instance.isPreset,
      'avatarImagePath': instance.avatarImagePath,
      'voiceDescription': instance.voiceDescription,
    };
