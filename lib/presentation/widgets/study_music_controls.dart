import 'package:flutter/material.dart';
import '../../core/theme.dart';

class MusicPlaybackState {
  const MusicPlaybackState(
      {this.title = '',
      this.artist = '',
      this.playing = false,
      this.volume = .5,
      this.canPrevious = false,
      this.canNext = false,
      this.canToggle = false,
      this.canVolume = false,
      this.trackId = '',
      this.position = 0,
      this.duration = 0,
      this.canSeek = false});

  factory MusicPlaybackState.fromMap(Map<dynamic, dynamic> value) {
    String label(String key) {
      final text = value[key];
      if (text is! String) return '';
      return text.length > 240 ? text.substring(0, 240) : text.trim();
    }

    final volume = value['volume'];
    final validVolume = volume is num && volume.isFinite;
    final rawDuration = value['duration'], rawPosition = value['position'];
    final duration =
        rawDuration is num && rawDuration.isFinite && rawDuration > 0
            ? rawDuration.toDouble()
            : 0.0;
    final position = rawPosition is num && rawPosition.isFinite
        ? rawPosition.toDouble().clamp(0.0, duration)
        : 0.0;
    return MusicPlaybackState(
        title: label('title'),
        artist: label('artist'),
        playing: value['playing'] == true,
        volume: validVolume ? volume.toDouble().clamp(0.0, 1.0) : .5,
        canPrevious: value['canPrevious'] == true,
        canNext: value['canNext'] == true,
        canToggle: value['canToggle'] == true,
        canVolume: value['canVolume'] == true && validVolume,
        trackId: value['trackId'] is String ? value['trackId'] as String : '',
        position: position,
        duration: duration,
        canSeek: value['canSeek'] == true && duration > 0);
  }

  final String title, artist;
  final bool playing, canPrevious, canNext, canToggle, canVolume;
  final double volume;
  final String trackId;
  final double position, duration;
  final bool canSeek;
}

/// The page controller lives in StudyMusicPanel even while this card is shown.
class StudyMusicControls extends StatefulWidget {
  const StudyMusicControls(
      {super.key,
      required this.state,
      required this.onCommand,
      required this.onVolume,
      required this.onSeek,
      required this.onExpand,
      required this.onClose,
      this.status,
      this.busy = false});
  final MusicPlaybackState state;
  final ValueChanged<String> onCommand;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onSeek;
  final VoidCallback? onExpand;
  final VoidCallback onClose;
  final String? status;
  final bool busy;

  @override
  State<StudyMusicControls> createState() => _StudyMusicControlsState();
}

class _StudyMusicControlsState extends State<StudyMusicControls> {
  double? _dragVolume;
  double? _dragPosition;
  String? _seekTrack;
  bool _seekCanceled = false;

  @override
  void didUpdateWidget(covariant StudyMusicControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.trackId != widget.state.trackId) {
      _dragPosition = null;
      _seekCanceled = true;
    }
  }

  String _time(double seconds) {
    final total = seconds.floor();
    final minutes = total ~/ 60;
    return '${minutes.toString().padLeft(2, '0')}:${(total % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final volume = _dragVolume ?? state.volume;
    final position =
        (_dragPosition ?? state.position).clamp(0.0, state.duration);
    final title = state.title.isNotEmpty
        ? state.title
        : state.playing
            ? '正在播放 · 歌名暂不可用'
            : '请先展开选择歌曲';
    final detail = widget.status ??
        (state.title.isEmpty && !state.canToggle
            ? '网易云音乐 · 展开后选择歌曲或操作'
            : '${state.artist.isEmpty ? '网易云音乐' : state.artist} · ${state.playing ? '播放中' : '已暂停'}');
    return Material(
      color: AppTheme.bgCardLight,
      elevation: 5,
      shadowColor: AppTheme.shadow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.border)),
      child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.music_note_rounded,
                      color: AppTheme.primaryColor, size: 21)),
              const SizedBox(width: 9),
              Expanded(
                  child: Tooltip(
                      message: title,
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)))),
              IconButton(
                  tooltip: '展开音乐',
                  onPressed: widget.onExpand,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.open_in_full_rounded, size: 17)),
              IconButton(
                  tooltip: '关闭音乐',
                  onPressed: widget.onClose,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18)),
            ]),
            Align(
                alignment: Alignment.centerLeft,
                child: Tooltip(
                    message: detail,
                    child: Text(detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)))),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                  tooltip: '上一首',
                  onPressed: !widget.busy && state.canPrevious
                      ? () => widget.onCommand('previous')
                      : null,
                  icon: const Icon(Icons.skip_previous_rounded)),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                  tooltip: state.playing ? '暂停音乐' : '播放音乐',
                  onPressed: !widget.busy && state.canToggle
                      ? () => widget.onCommand('toggle')
                      : null,
                  icon: Icon(state.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded)),
              const SizedBox(width: 10),
              IconButton(
                  tooltip: '下一首',
                  onPressed: !widget.busy && state.canNext
                      ? () => widget.onCommand('next')
                      : null,
                  icon: const Icon(Icons.skip_next_rounded)),
            ]),
            SizedBox(
                height: 30,
                child: Row(children: [
                  Icon(
                      volume == 0
                          ? Icons.volume_off_rounded
                          : Icons.volume_down_rounded,
                      size: 19,
                      color: AppTheme.textSecondary),
                  Expanded(
                      child: Slider(
                    key: const Key('music-volume'),
                    value: volume,
                    label: '${(volume * 100).round()}%',
                    semanticFormatterCallback: (value) =>
                        '音乐音量 ${(value * 100).round()}%',
                    onChanged: !widget.busy && state.canVolume
                        ? (value) => setState(() => _dragVolume = value)
                        : null,
                    onChangeEnd: !widget.busy && state.canVolume
                        ? (value) {
                            setState(() => _dragVolume = null);
                            widget.onVolume(value);
                          }
                        : null,
                  )),
                  SizedBox(
                      width: 34,
                      child: Text(
                          state.canVolume ? '${(volume * 100).round()}%' : '—',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary))),
                ])),
            SizedBox(
                height: 32,
                child: Row(children: [
                  Text(_time(position),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                  Expanded(
                      child: Slider(
                    key: const Key('music-progress'),
                    value: position,
                    max: state.duration > 0 ? state.duration : 1,
                    label: _time(position),
                    semanticFormatterCallback: (value) =>
                        '音乐进度 ${_time(value)}，共 ${_time(state.duration)}',
                    onChangeStart: !widget.busy && state.canSeek
                        ? (_) {
                            _seekTrack = state.trackId;
                            _seekCanceled = false;
                          }
                        : null,
                    onChanged: !widget.busy && state.canSeek
                        ? (value) {
                            if (!_seekCanceled) {
                              setState(() => _dragPosition = value);
                            }
                          }
                        : null,
                    onChangeEnd: !widget.busy && state.canSeek
                        ? (value) {
                            final valid = !_seekCanceled &&
                                _seekTrack == widget.state.trackId;
                            setState(() => _dragPosition = null);
                            if (valid) widget.onSeek(value);
                          }
                        : null,
                  )),
                  Text(state.duration > 0 ? _time(state.duration) : '--:--',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                ])),
          ])),
    );
  }
}
