import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/character.dart';
import '../data/storage_service.dart';

// StorageService provider - 需要在应用初始化时注入实际实例
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('StorageService must be initialized before use');
});

// 当前选中的角色ID状态
final currentCharacterIdProvider = StateProvider<String?>((ref) => null);

// 所有角色列表（包括预设和自定义）
// 注意：必须依赖 characterNotifierProvider 而不是直接读storage，
// 否则增删角色后不会触发UI刷新
final allCharactersProvider = Provider<List<Character>>((ref) {
  return ref.watch(characterNotifierProvider);
});

// 仅自定义角色列表
final customCharactersProvider = Provider<List<Character>>((ref) {
  final all = ref.watch(characterNotifierProvider);
  return all.where((c) => !c.isPreset).toList();
});

// 当前选中的角色对象（基于currentCharacterIdProvider）
final currentCharacterProvider = Provider<Character?>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final currentId = ref.watch(currentCharacterIdProvider);
  if (currentId == null) return null;
  return storage.getCharacter(currentId);
});

// 角色管理Notifier - 处理CRUD操作
class CharacterNotifier extends StateNotifier<List<Character>> {
  final StorageService _storage;

  CharacterNotifier(this._storage) : super(_storage.getAllCharacters());

  /// 添加新角色
  Future<void> addCharacter(Character character) async {
    await _storage.addCharacter(character);
    state = _storage.getAllCharacters();
  }

  /// 更新现有角色
  Future<void> updateCharacter(Character character) async {
    await _storage.updateCharacter(character);
    state = _storage.getAllCharacters();
  }

  /// 删除角色
  Future<void> deleteCharacter(String id) async {
    await _storage.deleteCharacter(id);
    state = _storage.getAllCharacters();
  }
}

// 角色管理Provider
final characterNotifierProvider =
    StateNotifierProvider<CharacterNotifier, List<Character>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return CharacterNotifier(storage);
});
