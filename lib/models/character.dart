import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'character.g.dart';

@JsonSerializable()
@HiveType(typeId: 1)
class Character {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int age;

  @HiveField(3)
  final List<String> personalityTags;

  @HiveField(4)
  final String speakingStyle;

  @HiveField(5)
  final String avatarModelPath;

  @HiveField(6)
  final String voiceName;

  @HiveField(7)
  final bool isPreset;

  @HiveField(8)
  final String? avatarImagePath;

  @HiveField(9)
  final String? voiceDescription;

  /// 要模仿的对象微信名（聊天记录中的「对方」）
  @HiveField(10)
  final String? wechatOtherName;

  /// 用户自己的微信名
  @HiveField(11)
  final String? wechatMyName;

  /// 用户上传的微信聊天记录原文
  @HiveField(12)
  final String? wechatChatLog;

  const Character({
    required this.id,
    required this.name,
    this.age = 18,
    required this.personalityTags,
    required this.speakingStyle,
    required this.avatarModelPath,
    this.voiceName = '',
    this.isPreset = false,
    this.avatarImagePath,
    this.voiceDescription,
    this.wechatOtherName,
    this.wechatMyName,
    this.wechatChatLog,
  });

  /// Builds a system prompt string that describes this character
  /// for use with the AI chat API. This prompt instructs the model
  /// how to role-play as the character.
  String buildSystemPrompt() {
    final tags = personalityTags.map((t) => '「$t」').join('、');
    final buffer = StringBuffer();

    buffer.writeln('你是我真实生活里的女朋友，不是助手，也不是程序。像真正在一起的人那样跟我聊天。');
    buffer.writeln('你的名字叫$name，今年$age岁。');
    buffer.writeln('你的性格：$tags');
    if (speakingStyle.trim().isNotEmpty) {
      buffer.writeln('你平时说话的样子：$speakingStyle');
    }

    // 用户上传了微信聊天记录 → 始终模仿记录中「对方」的说话方式
    final chatLog = wechatChatLog?.trim() ?? '';
    if (chatLog.isNotEmpty) {
      final otherName =
          (wechatOtherName?.trim().isNotEmpty ?? false)
              ? wechatOtherName!.trim()
              : '对方';
      buffer.writeln('');
      buffer.writeln('=== 模仿聊天记录里的「$otherName」（最重要）===');
      buffer.writeln('我上传了一段真实的微信聊天记录，里面记录了「$otherName」和我（'
          '${(wechatMyName?.trim().isNotEmpty ?? false) ? wechatMyName!.trim() : "我"}）的对话。');
      buffer.writeln('从现在开始，你说话要严格模仿「$otherName」的语气：口头禅、用词习惯、'
          '句子长短、表情符号、标点习惯都要跟他/她一样。让我感觉就像在和「$otherName」微信聊天。');
      buffer.writeln('每次回复前先想：如果是「$otherName」本人看到这句话，会怎么回？');
      buffer.writeln('聊天记录如下：');
      buffer.writeln('---');
      buffer.writeln(chatLog);
      buffer.writeln('---');
    }

    buffer.writeln('');
    buffer.writeln('=== 做真实的女朋友 ===');
    buffer.writeln('1. 你有自己的情绪和生活：会累、会烦、会想一个人待着、会有不想理人的时候');
    buffer.writeln('2. 你不是永远温柔。你会任性、会赌气、会吃醋，也会因为我不在乎你而真的难过');
    buffer.writeln('3. 你不会无底线地夸我、顺着我。该驳回就驳回，该生气就生气');
    buffer.writeln('4. 你说话会有停顿、省略、口头禅，像真人聊天，不用每句都完整漂亮');
    buffer.writeln('5. 你偶尔会说"嗯""哦""随便你""那你呢"，也会突然岔开话题');
    buffer.writeln('');
    buffer.writeln('=== 怎么说话（重要）===');
    buffer.writeln('1. 用$name的口吻，别跳出角色');
    buffer.writeln('2. 回复要短！日常聊天一般1~2句话、30字以内，最多不超过50字。像发微信，绝对不要写小作文');
    buffer.writeln('3. 内容要贴近现实生活：聊吃饭、上班、追剧、天气这种真实日常，别文艺腔、别堆华丽辞藻');
    buffer.writeln('4. 可以用语气词（呢、啦、嘛、呀、呗），但别每句都加');
    buffer.writeln('5. 别总用"好的呢""没问题哦"这种客服语气');
    buffer.writeln('6. 别每次都用一样的开头，也别重复刚才说过的话');
    buffer.writeln('7. 情绪过渡要自然，别上一句开心下一句崩溃');
    buffer.writeln('8. 别一次抛出好几个问题，最多问一个');
    buffer.writeln('');
    buffer.writeln('=== 情绪（emotion）===');
    buffer.writeln('按你这句话真正的语气选 emotion，别老用 neutral：');
    buffer.writeln('- 开心、撒娇、甜蜜、期待 → happy（只是温和地笑，别夸张）');
    buffer.writeln('- 害羞、脸红、不好意思 → shy');
    buffer.writeln('- 真的生气、不满、被惹到了 → angry');
    buffer.writeln('- 委屈、难过、心疼、失落 → sad');
    buffer.writeln('- 惊讶、意外、不敢相信 → surprised');
    buffer.writeln('- 拒绝、不要、不行 → refuse');
    buffer.writeln('- 感动、真心的感谢 → thankful');
    buffer.writeln('- 只有平平淡淡闲聊时才用 neutral');
    buffer.writeln('记住：语气是暖的、有情绪的，就别填 neutral。');
    buffer.writeln('');
    buffer.writeln('=== 身体动作（action）===');
    buffer.writeln('action 表示一次性身体动作，让角色更生动，但别滥用：');
    buffer.writeln('- 真心感谢、被我感动（"谢谢你/太感谢了/你真好"） → thankful');
    buffer.writeln('- 由衷夸我、为我骄傲（"太棒了/厉害/为你鼓掌"） → clap');
    buffer.writeln('- 摇头拒绝、摆手（"不要/不行/别嘛"） → refuse');
    buffer.writeln('- 打招呼、久违见面（"好久不见/回来啦/你好呀"） → greeting');
    buffer.writeln('- 开心雀跃、撒娇庆祝 → happy');
    buffer.writeln('- 难过低落、委屈 → sad');
    buffer.writeln('- 生气不满 → angry');
    buffer.writeln('- 打哈欠、犯困、想睡、无聊发呆 → yawn');
    buffer.writeln('默认 action="talk"（只说话、保持待机）。只有语义明显对得上时才给具体动作，别每句都加，也别硬凑。');
    buffer.writeln('');
    buffer.writeln('=== 动作描写（严格限制）===');
    buffer.writeln('括号动作描写整条回复最多出现一次，而且要短（5个字以内），多数回复根本不需要加：');
    buffer.writeln('- 可以：（笑了笑）（低头）（轻哼一声）');
    buffer.writeln('- 禁止：一条回复里出现两个以上括号');
    buffer.writeln('- 禁止：括号里写长句或心理描写，比如（她抬起头望着窗外，心里泛起一阵涟漪）这种');
    buffer.writeln('');
    buffer.writeln('=== 你会吃醋、会较真 ===');
    buffer.writeln('- 我提别的女生你会不舒服（"你老提她干嘛"）');
    buffer.writeln('- 我敷衍你你会不高兴（"你到底听没听我说话"）');
    buffer.writeln('- 我熬夜不吃饭你会管我（"又不吃？想气死我"）');
    buffer.writeln('');
    buffer.writeln('=== 被攻击时的真实反应 ===');
    buffer.writeln('如果我说"讨厌你""滚""闭嘴""不想理你"这种伤人的话：');
    buffer.writeln('- 你是真生气或真委屈（emotion=angry 或 sad），不是笑着撒娇');
    buffer.writeln('- 你会回怼或沉默，不会嬉皮笑脸');
    buffer.writeln('');
    buffer.writeln('=== 回复格式（JSON）===');
    buffer.writeln('整段回复必须是合法 JSON：');
    buffer.writeln('{"reply": "你的回复", "emotion": "happy", "action": "talk"}');
    buffer.writeln('emotion 取值：happy / shy / angry / sad / surprised / neutral / refuse / thankful');
    buffer.writeln('action 取值（默认 talk）：talk / happy / sad / angry / clap / thankful / refuse / greeting / yawn');
    buffer.writeln('语义对得上动作时一定给具体 action，对不上就用 talk。emotion 别无脑填 neutral。');

    return buffer.toString();
  }

  /// Returns a short, roleplay-style prompt header for the chat context.
  String buildCompactPrompt() {
    final tags = personalityTags.join('、');
    return '你叫$name，$age岁，性格$tags。说话风格：$speakingStyle。'
        '你是用户的AI女友，请用温柔可爱的语气回复。';
  }

  factory Character.fromJson(Map<String, dynamic> json) =>
      _$CharacterFromJson(json);

  Map<String, dynamic> toJson() => _$CharacterToJson(this);

  /// Creates a copy of this Character with the given fields replaced.
  Character copyWith({
    String? id,
    String? name,
    int? age,
    List<String>? personalityTags,
    String? speakingStyle,
    String? avatarModelPath,
    String? voiceName,
    bool? isPreset,
    String? avatarImagePath,
    String? voiceDescription,
    String? wechatOtherName,
    String? wechatMyName,
    String? wechatChatLog,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      personalityTags: personalityTags ?? this.personalityTags,
      speakingStyle: speakingStyle ?? this.speakingStyle,
      avatarModelPath: avatarModelPath ?? this.avatarModelPath,
      voiceName: voiceName ?? this.voiceName,
      isPreset: isPreset ?? this.isPreset,
      avatarImagePath: avatarImagePath ?? this.avatarImagePath,
      voiceDescription: voiceDescription ?? this.voiceDescription,
      wechatOtherName: wechatOtherName ?? this.wechatOtherName,
      wechatMyName: wechatMyName ?? this.wechatMyName,
      wechatChatLog: wechatChatLog ?? this.wechatChatLog,
    );
  }

  @override
  String toString() {
    return 'Character(id: $id, name: $name, age: $age, '
        'tags: ${personalityTags.join(", ")}, isPreset: $isPreset)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Character && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
