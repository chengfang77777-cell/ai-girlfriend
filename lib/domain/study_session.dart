import 'dart:async';

import 'package:flutter/foundation.dart';

enum StudyPhase {
  ready,
  focusing,
  paused,
  supporting,
  resting,
  completed,
  ended
}

/// Local countdown. Only time inside a running segment counts toward the goal.
/// Persisted records contain elapsed time, never a deadline to replay on launch.
class StudySessionController extends ChangeNotifier {
  StudySessionController({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  Timer? _timer;
  DateTime? _segmentStartedAt;
  Duration _elapsedAtResume = Duration.zero;
  Duration _duration = const Duration(minutes: 25);
  Duration _elapsed = Duration.zero;
  String _goal = '';
  StudyPhase _phase = StudyPhase.ready;

  Duration get duration => _duration;
  Duration get elapsed => _elapsed;
  Duration get remaining => _duration - _elapsed;
  String get goal => _goal;
  StudyPhase get phase => _phase;

  void start({required Duration duration, String goal = ''}) {
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'Must be positive');
    }
    _stopTimer();
    _duration = duration;
    _goal = goal.trim();
    _elapsed = Duration.zero;
    _beginSegment();
    notifyListeners();
  }

  void pause({StudyPhase phase = StudyPhase.paused}) {
    if (phase != StudyPhase.paused &&
        phase != StudyPhase.supporting &&
        phase != StudyPhase.resting) {
      throw ArgumentError.value(phase, 'phase', 'Must be a paused state');
    }
    if (!_isActive) return;
    _elapsed = _sampleElapsed();
    _stopTimer();
    _phase = _elapsed >= _duration && _phase == StudyPhase.focusing
        ? StudyPhase.completed
        : phase;
    notifyListeners();
  }

  void resume() {
    if (!_isActive ||
        _phase == StudyPhase.focusing ||
        remaining <= Duration.zero) {
      return;
    }
    _beginSegment();
    notifyListeners();
  }

  /// An explicit stop is never a completed countdown, even at its deadline.
  void finish() {
    if (!_isActive) return;
    _elapsed = _sampleElapsed();
    _stopTimer();
    _phase = StudyPhase.ended;
    notifyListeners();
  }

  void tick() {
    if (_phase != StudyPhase.focusing) return;
    final next = _sampleElapsed();
    if (next == _elapsed) return;
    _elapsed = next;
    if (_elapsed >= _duration) {
      _stopTimer();
      _phase = StudyPhase.completed;
    }
    notifyListeners();
  }

  bool get _isActive =>
      _phase == StudyPhase.focusing ||
      _phase == StudyPhase.paused ||
      _phase == StudyPhase.supporting ||
      _phase == StudyPhase.resting;

  void _beginSegment() {
    _elapsedAtResume = _elapsed;
    _segmentStartedAt = _now();
    _phase = StudyPhase.focusing;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Duration _sampleElapsed() {
    if (_phase != StudyPhase.focusing || _segmentStartedAt == null) {
      return _elapsed;
    }
    final candidate = _elapsedAtResume + _now().difference(_segmentStartedAt!);
    // A clock adjustment must not subtract time already displayed to the user.
    if (candidate < _elapsed) return _elapsed;
    return candidate > _duration ? _duration : candidate;
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _segmentStartedAt = null;
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'durationMilliseconds': _duration.inMilliseconds,
        'elapsedMilliseconds': _sampleElapsed().inMilliseconds,
        'goal': _goal,
        'phase': _phase.name,
      };

  /// Restore before attaching any listener that plays completion effects.
  /// Even a fully elapsed active snapshot stays paused: reopening earns nothing.
  void restore(Map<dynamic, dynamic>? data) {
    _stopTimer();
    _duration = const Duration(minutes: 25);
    _elapsed = Duration.zero;
    _elapsedAtResume = Duration.zero;
    _goal = '';
    _phase = StudyPhase.ready;
    final durationMs = data?['durationMilliseconds'];
    final elapsedMs = data?['elapsedMilliseconds'];
    final savedPhase = data?['phase'];
    if (durationMs is int &&
        durationMs > 0 &&
        elapsedMs is int &&
        elapsedMs >= 0 &&
        data?['goal'] is String &&
        StudyPhase.values.any((phase) => phase.name == savedPhase)) {
      _duration = Duration(milliseconds: durationMs);
      _elapsed = Duration(milliseconds: elapsedMs.clamp(0, durationMs));
      _goal = (data!['goal'] as String).trim();
      _phase =
          StudyPhase.values.firstWhere((phase) => phase.name == savedPhase);
      if (_isActive) _phase = StudyPhase.paused;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
