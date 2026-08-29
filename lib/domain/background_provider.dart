import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/backgrounds.dart';
import '../core/constants.dart';
import 'character_provider.dart';

/// 当前背景ID状态
final backgroundIdProvider = StateProvider<String?>((ref) => null);

/// 背景变化通知器（用于触发VRM viewer更新）
final backgroundChangeProvider = StateProvider<int>((ref) => 0);

/// 获取当前角色的背景配置
final currentBackgroundProvider = Provider<BackgroundConfig>((ref) {
  final bgId = ref.watch(backgroundIdProvider);
  final currentChar = ref.watch(currentCharacterProvider);

  // 如果用户手动选择了背景
  if (bgId != null) {
    return PresetBackgrounds.getById(bgId) ?? PresetBackgrounds.dreamyStarry;
  }

  // 否则使用角色默认背景
  if (currentChar != null) {
    return PresetBackgrounds.getCharacterDefault(currentChar.name);
  }

  return PresetBackgrounds.dreamyStarry;
});

/// 保存用户的背景选择
void saveBackgroundChoice(WidgetRef ref, String bgId) {
  ref.read(backgroundIdProvider.notifier).state = bgId;
  // 触发背景变化通知
  ref.read(backgroundChangeProvider.notifier).state++;
  final storage = ref.read(storageServiceProvider);
  storage.setSetting(AppConstants.backgroundKey, bgId);
}

/// 重置为用户未选择背景（使用角色默认背景）
void resetBackgroundChoice(WidgetRef ref) {
  ref.read(backgroundIdProvider.notifier).state = null;
  // 触发背景变化通知，让 VRM viewer 即时刷新
  ref.read(backgroundChangeProvider.notifier).state++;
  final storage = ref.read(storageServiceProvider);
  storage.setSetting(AppConstants.backgroundKey, null);
}

/// 加载用户的背景选择
void loadBackgroundChoice(WidgetRef ref) {
  final storage = ref.read(storageServiceProvider);
  final bgId = storage.getSetting<String>(AppConstants.backgroundKey);
  if (bgId != null) {
    ref.read(backgroundIdProvider.notifier).state = bgId;
  }
}
