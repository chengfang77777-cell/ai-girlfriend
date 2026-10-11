import 'package:flutter/material.dart';

enum BackgroundMotion { gentle, still, system }

/// 背景配置类
class BackgroundConfig {
  final String id;
  final String name;
  final String description;
  final List<Color> gradientColors;
  final String? particleType; // 星星、花瓣、光晕等
  final Map<String, dynamic>? extra;

  const BackgroundConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.gradientColors,
    this.particleType,
    this.extra,
  });
}

/// 预设背景配置
class PresetBackgrounds {
  PresetBackgrounds._();

  // 梦幻星空
  static const dreamyStarry = BackgroundConfig(
    id: 'dreamy_starry',
    name: '梦幻星空',
    description: '静谧星河、轻柔微光与偶尔划过的流星',
    gradientColors: [Color(0xFF101E2B), Color(0xFF2A3E4A), Color(0xFF536763)],
    particleType: 'stars',
  );

  // 樱花飘落
  static const sakuraFalling = BackgroundConfig(
    id: 'sakura_falling',
    name: '樱花飘落',
    description: '暖白春光，花瓣随风轻轻翻转',
    gradientColors: [Color(0xFFFAF4F0), Color(0xFFEEDFDF), Color(0xFFD5CFC9)],
    particleType: 'sakura',
  );

  // 温馨房间
  static const cozyRoom = BackgroundConfig(
    id: 'cozy_room',
    name: '温馨房间',
    description: '窗边的午后暖光，空气里漂浮着细小微尘',
    gradientColors: [Color(0xFFF7F0E3), Color(0xFFEAD9BF), Color(0xFFC6BAA7)],
    particleType: 'warm_glow',
  );

  // 渐变光晕
  static const gradientGlow = BackgroundConfig(
    id: 'gradient_glow',
    name: '渐变光晕',
    description: '鼠尾草绿与淡玫瑰色，像呼吸一样缓缓流动',
    gradientColors: [Color(0xFFEDF1E8), Color(0xFFD1DDD4), Color(0xFFDBC9C9)],
    particleType: 'glow',
  );

  // 清新草地
  static const freshMeadow = BackgroundConfig(
    id: 'fresh_meadow',
    name: '清新草地',
    description: '远处草坡、轻摆的草叶与点点萤光',
    gradientColors: [Color(0xFFEFF3E8), Color(0xFFD8E4D5), Color(0xFF96AE97)],
    particleType: 'fireflies',
  );

  // 夕阳黄昏
  static const sunsetDusk = BackgroundConfig(
    id: 'sunset_dusk',
    name: '夕阳黄昏',
    description: '柔和落日、层叠远山与缓慢舒展的云层',
    gradientColors: [Color(0xFFE3C9BC), Color(0xFFD6A190), Color(0xFF889798)],
    particleType: 'sunrays',
  );

  // 冰雪世界
  static const iceWorld = BackgroundConfig(
    id: 'ice_world',
    name: '冰雪世界',
    description: '珍珠蓝的远山，细雪在不同深度轻轻飘落',
    gradientColors: [Color(0xFFF2F6F4), Color(0xFFDBE9E9), Color(0xFFADBEC6)],
    particleType: 'snowflakes',
  );

  // 神秘夜空
  static const mysticNight = BackgroundConfig(
    id: 'mystic_night',
    name: '神秘夜空',
    description: '深蓝夜色里，薄薄的极光与星尘缓缓流动',
    gradientColors: [Color(0xFF0D222D), Color(0xFF163E43), Color(0xFF2E5154)],
    particleType: 'nebula',
  );

  /// 所有预设背景
  static const List<BackgroundConfig> all = [
    dreamyStarry,
    sakuraFalling,
    cozyRoom,
    gradientGlow,
    freshMeadow,
    sunsetDusk,
    iceWorld,
    mysticNight,
  ];

  /// 根据ID获取背景
  static BackgroundConfig? getById(String id) {
    try {
      return all.firstWhere((bg) => bg.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 角色默认背景映射
  static const Map<String, String> characterDefaults = {
    '温柔学姐': 'sakura_falling', // 樱花 - 温柔
    '活泼青梅': 'fresh_meadow', // 草地 - 活泼
    '傲娇同桌': 'gradient_glow', // 渐变 - 现代
    '知性御姐': 'dreamy_starry', // 星空 - 优雅
    '治愈邻家': 'cozy_room', // 房间 - 温馨
    '拉姆': 'ice_world', // 冰雪 - 冷酷
    '蕾姆': 'sunset_dusk', // 夕阳 - 温暖
  };

  /// 获取角色的默认背景
  static BackgroundConfig getCharacterDefault(String characterName) {
    final bgId = characterDefaults[characterName] ?? 'dreamy_starry';
    return getById(bgId) ?? dreamyStarry;
  }
}
