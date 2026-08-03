import 'package:flutter_riverpod/flutter_riverpod.dart';

// Live2D模型加载状态枚举
enum AvatarLoadState { loading, loaded, error, idle }

// 角色形象状态类
class AvatarState {
  final String modelPath;
  final AvatarLoadState loadState;
  final String currentEmotion;
  final bool isBreathing;
  final String? errorMessage;

  const AvatarState({
    this.modelPath = '',
    this.loadState = AvatarLoadState.idle,
    this.currentEmotion = 'neutral',
    this.isBreathing = true,
    this.errorMessage,
  });

  AvatarState copyWith({
    String? modelPath,
    AvatarLoadState? loadState,
    String? currentEmotion,
    bool? isBreathing,
    String? errorMessage,
  }) {
    return AvatarState(
      modelPath: modelPath ?? this.modelPath,
      loadState: loadState ?? this.loadState,
      currentEmotion: currentEmotion ?? this.currentEmotion,
      isBreathing: isBreathing ?? this.isBreathing,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

// 角色形象Notifier
class AvatarNotifier extends StateNotifier<AvatarState> {
  AvatarNotifier() : super(const AvatarState());

  /// 加载模型
  void loadModel(String path) {
    state = state.copyWith(
      modelPath: path,
      loadState: AvatarLoadState.loading,
      errorMessage: null,
    );
    // 实际加载逻辑由Live2D Widget处理
  }

  /// 模型加载成功回调
  void onModelLoaded() {
    state = state.copyWith(loadState: AvatarLoadState.loaded);
  }

  /// 模型加载失败回调
  void onModelError(String error) {
    state = state.copyWith(
      loadState: AvatarLoadState.error,
      errorMessage: error,
    );
  }

  /// 切换表情
  void setEmotion(String emotion) {
    state = state.copyWith(currentEmotion: emotion);
  }

  /// 切换呼吸动画状态
  void toggleBreathing() {
    state = state.copyWith(isBreathing: !state.isBreathing);
  }
}

// 角色形象Provider
final avatarProvider =
    StateNotifierProvider<AvatarNotifier, AvatarState>((ref) {
  return AvatarNotifier();
});
