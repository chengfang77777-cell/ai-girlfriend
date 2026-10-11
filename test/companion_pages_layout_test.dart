import 'package:ai_girlfriend/core/theme.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/domain/character_provider.dart';
import 'package:ai_girlfriend/models/character.dart';
import 'package:ai_girlfriend/presentation/pages/character_create_page.dart';
import 'package:ai_girlfriend/presentation/pages/character_list_page.dart';
import 'package:ai_girlfriend/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryStorage implements StorageService {
  @override
  String? get apiKey => null;
  @override
  String? get mimoApiKey => null;
  @override
  bool get autoPlayVoice => false;
  @override
  T? getSetting<T>(String key, {T? defaultValue}) => defaultValue;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [390.0, 1440.0]) {
    for (final page in <Widget>[
      const SettingsPage(),
      const CharacterListPage(),
      const CharacterCreatePage(),
    ]) {
      testWidgets(
          '${page.runtimeType} fits $width and scrolls through all content',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(_MemoryStorage()),
            currentCharacterProvider.overrideWithValue(null),
            allCharactersProvider.overrideWithValue(List.generate(
                7,
                (i) => Character(
                      id: '$i',
                      name: '陪伴角色 $i',
                      age: 22,
                      personalityTags: const ['温柔', '热情', '包容'],
                      speakingStyle: '',
                      avatarModelPath: '',
                      isPreset: i < 5,
                    ))),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.2)),
              child: child!,
            ),
            home: page,
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (var i = 0; i < 12; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -550));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
