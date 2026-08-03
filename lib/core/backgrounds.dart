import 'package:flutter/material.dart';

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
    description: '深色背景 + 闪烁星星，浪漫氛围',
    gradientColors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
    particleType: 'stars',
  );

  // 樱花飘落
  static const sakuraFalling = BackgroundConfig(
    id: 'sakura_falling',
    name: '樱花飘落',
    description: '粉色背景 + 飘落的花瓣，日系风格',
    gradientColors: [Color(0xFFFFF0F5), Color(0xFFFFE4E1), Color(0xFFFFC0CB)],
    particleType: 'sakura',
  );

  // 温馨房间
  static const cozyRoom = BackgroundConfig(
    id: 'cozy_room',
    name: '温馨房间',
    description: '暖色调房间，舒适氛围',
    gradientColors: [Color(0xFFFFF8DC), Color(0xFFFFEFD5), Color(0xFFFFE4C4)],
    particleType: 'warm_glow',
  );

  // 渐变光晕
  static const gradientGlow = BackgroundConfig(
    id: 'gradient_glow',
    name: '渐变光晕',
    description: '柔和的彩色光晕，现代感',
    gradientColors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
    particleType: 'glow',
  );

  // 清新草地
  static const freshMeadow = BackgroundConfig(
    id: 'fresh_meadow',
    name: '清新草地',
    description: '绿色自然，清新舒适',
    gradientColors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
    particleType: 'fireflies',
  );

  // 夕阳黄昏
  static const sunsetDusk = BackgroundConfig(
    id: 'sunset_dusk',
    name: '夕阳黄昏',
    description: '暖色夕阳，温馨浪漫',
    gradientColors: [Color(0xFFFF6B6B), Color(0xFFFF8E53), Color(0xFFFFD93D)],
    particleType: 'sunrays',
  );

  // 冰雪世界
  static const iceWorld = BackgroundConfig(
    id: 'ice_world',
    name: '冰雪世界',
    description: '清凉蓝色，晶莹剔透',
    gradientColors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2), Color(0xFF80DEEA)],
    particleType: 'snowflakes',
  );

  // 神秘夜空
  static const mysticNight = BackgroundConfig(
    id: 'mystic_night',
    name: '神秘夜空',
    description: '深紫夜空，神秘优雅',
    gradientColors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
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
    '温柔学姐': 'sakura_falling',      // 樱花 - 温柔
    '活泼青梅': 'fresh_meadow',        // 草地 - 活泼
    '傲娇同桌': 'gradient_glow',        // 渐变 - 现代
    '知性御姐': 'dreamy_starry',        // 星空 - 优雅
    '治愈邻家': 'cozy_room',           // 房间 - 温馨
    '拉姆': 'ice_world',               // 冰雪 - 冷酷
    '蕾姆': 'sunset_dusk',             // 夕阳 - 温暖
  };

  /// 获取角色的默认背景
  static BackgroundConfig getCharacterDefault(String characterName) {
    final bgId = characterDefaults[characterName] ?? 'dreamy_starry';
    return getById(bgId) ?? dreamyStarry;
  }
}
