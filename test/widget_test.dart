import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/domain/character_provider.dart';
import 'package:ai_girlfriend/main.dart';

void main() {
  late Directory storageDirectory;

  setUpAll(() async {
    storageDirectory =
        await Directory.systemTemp.createTemp('ai_girlfriend_widget_test_');
    Hive.init(storageDirectory.path);
    globalStorageService = StorageService();
    await globalStorageService.init();
  });

  tearDownAll(() async {
    await Hive.close();
    await storageDirectory.delete(recursive: true);
  });

  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(globalStorageService)
      ],
      child: const AiGirlfriendApp(),
    ));
    expect(find.byType(AiGirlfriendApp), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Dispose the splash animation before closing its storage fixture.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
