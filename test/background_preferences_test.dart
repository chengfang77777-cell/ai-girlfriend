import 'package:ai_girlfriend/core/backgrounds.dart';
import 'package:ai_girlfriend/core/constants.dart';
import 'package:ai_girlfriend/core/theme.dart';
import 'package:ai_girlfriend/data/storage_service.dart';
import 'package:ai_girlfriend/domain/background_provider.dart';
import 'package:ai_girlfriend/domain/character_provider.dart';
import 'package:ai_girlfriend/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Storage implements StorageService {
  final settings = <String, dynamic>{};
  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      settings[key] as T? ?? defaultValue;
  @override
  Future<void> setSetting(String key, dynamic value) async {
    settings[key] = value;
  }

  @override
  String? get apiKey => null;
  @override
  String? get mimoApiKey => null;
  @override
  bool get autoPlayVoice => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('background motion restores a saved choice and defaults to gentle', () {
    final storage = _Storage();
    for (final (saved, expected) in [
      (null, BackgroundMotion.gentle),
      ('still', BackgroundMotion.still),
      ('system', BackgroundMotion.system),
      ('unknown', BackgroundMotion.gentle)
    ]) {
      storage.settings[AppConstants.backgroundMotionKey] = saved;
      final container = ProviderContainer(
          overrides: [storageServiceProvider.overrideWithValue(storage)]);
      expect(container.read(backgroundMotionProvider), expected);
      container.dispose();
    }
  });
  testWidgets('settings changes and persists the background motion preference',
      (tester) async {
    final storage = _Storage();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(storage),
          currentCharacterProvider.overrideWithValue(null)
        ],
        child: MaterialApp(
            theme: AppTheme.lightTheme, home: const SettingsPage())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
        find.byKey(const Key('background-motion')), 400,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('background-motion')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('静态背景').last);
    await tester.pumpAndSettle();
    expect(storage.settings[AppConstants.backgroundMotionKey], 'still');
    final container =
        ProviderScope.containerOf(tester.element(find.byType(SettingsPage)));
    expect(container.read(backgroundMotionProvider), BackgroundMotion.still);
    expect(tester.takeException(), isNull);
  });
}
