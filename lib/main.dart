import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme.dart';
import 'data/storage_service.dart';
import 'domain/character_provider.dart';
import 'domain/background_provider.dart';
import 'presentation/pages/splash_page.dart';

late StorageService globalStorageService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  globalStorageService = StorageService();
  await globalStorageService.init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(globalStorageService),
      ],
      child: const AiGirlfriendApp(),
    ),
  );
}

class AiGirlfriendApp extends ConsumerStatefulWidget {
  const AiGirlfriendApp({super.key});

  @override
  ConsumerState<AiGirlfriendApp> createState() => _AiGirlfriendAppState();
}

class _AiGirlfriendAppState extends ConsumerState<AiGirlfriendApp> {
  @override
  void initState() {
    super.initState();
    // 一次性初始化全局状态，避免在 build 中反复用 microtask 设置（Riverpod 反模式）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storedId = globalStorageService.currentCharacterId;
      if (storedId != null) {
        ref.read(currentCharacterIdProvider.notifier).state = storedId;
      }
      loadBackgroundChoice(ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 女友',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashPage(),
    );
  }
}
