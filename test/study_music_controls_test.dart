import 'package:ai_girlfriend/presentation/widgets/study_music_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact player shows track and routes controls at narrow width',
      (tester) async {
    final commands = <String>[];
    double? volume;
    double? position;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Align(
      alignment: Alignment.bottomLeft,
      child: SizedBox(
          width: 304,
          height: 208,
          child: StudyMusicControls(
            state: MusicPlaybackState.fromMap({
              'title': '正在听的歌曲',
              'artist': '歌手名字',
              'playing': true,
              'volume': .6,
              'canPrevious': true,
              'canNext': true,
              'canToggle': true,
              'canVolume': true,
              'trackId': 'song-1',
              'position': 12,
              'duration': 180,
              'canSeek': true
            }),
            onCommand: commands.add,
            onVolume: (value) => volume = value,
            onSeek: (value) => position = value,
            onExpand: () {},
            onClose: () {},
          )),
    ))));
    expect(find.text('正在听的歌曲'), findsOneWidget);
    expect(find.textContaining('歌手名字'), findsOneWidget);
    await tester.tap(find.byTooltip('上一首'));
    await tester.tap(find.byTooltip('暂停音乐'));
    await tester.tap(find.byTooltip('下一首'));
    expect(commands, ['previous', 'toggle', 'next']);
    final slider = tester.widget<Slider>(find.byKey(const Key('music-volume')));
    slider.onChanged!(.3);
    slider.onChangeEnd!(.3);
    expect(volume, .3);
    expect(find.text('00:12'), findsOneWidget);
    expect(find.text('03:00'), findsOneWidget);
    final progress =
        tester.widget<Slider>(find.byKey(const Key('music-progress')));
    progress.onChangeStart!(12);
    progress.onChanged!(65);
    progress.onChangeEnd!(65);
    expect(position, 65);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unavailable controls stay disabled and expansion stays available',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 360,
      height: 208,
      child: StudyMusicControls(
          state: const MusicPlaybackState(),
          onCommand: (_) {},
          onVolume: (_) {},
          onSeek: (_) {},
          onExpand: () {},
          onClose: () {}),
    ))));
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '下一首'))
            .onPressed,
        isNull);
    for (final slider in tester.widgetList<Slider>(find.byType(Slider))) {
      expect(slider.onChanged, isNull);
    }
    expect(find.text('请先展开选择歌曲'), findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '展开音乐'))
            .onPressed,
        isNotNull);
  });

  testWidgets(
      'track change during drag cancels seek instead of jumping the new song',
      (tester) async {
    var track = 'first';
    late StateSetter change;
    final seeks = <double>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
      change = setState;
      return SizedBox(
          width: 360,
          height: 208,
          child: StudyMusicControls(
              state: MusicPlaybackState(
                  trackId: track, duration: 180, position: 10, canSeek: true),
              onCommand: (_) {},
              onVolume: (_) {},
              onSeek: seeks.add,
              onExpand: () {},
              onClose: () {}));
    }))));
    var slider = tester.widget<Slider>(find.byKey(const Key('music-progress')));
    slider.onChangeStart!(10);
    slider.onChanged!(90);
    change(() => track = 'second');
    await tester.pump();
    slider = tester.widget<Slider>(find.byKey(const Key('music-progress')));
    slider.onChangeEnd!(90);
    expect(seeks, isEmpty);
  });
}
