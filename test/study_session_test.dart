import 'dart:convert';

import 'package:ai_girlfriend/domain/study_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late StudySessionController session;
  setUp(() {
    now = DateTime(2026, 9, 28, 12);
    session = StudySessionController(now: () => now);
  });
  tearDown(() => session.dispose());

  test('counts actual wall-clock time and emits completion only once', () {
    var completions = 0;
    session.addListener(() {
      if (session.phase == StudyPhase.completed) completions++;
    });
    session.start(duration: const Duration(minutes: 3), goal: '读第二章');
    now = now.add(const Duration(seconds: 121));
    session.tick();
    expect(session.elapsed, const Duration(seconds: 121));
    expect(session.remaining, const Duration(seconds: 59));
    now = now.add(const Duration(minutes: 10));
    session.tick();
    expect(session.phase, StudyPhase.completed);
    expect(session.elapsed, const Duration(minutes: 3));
    expect(session.remaining, Duration.zero);
    session.tick();
    session.resume();
    session.pause();
    expect(completions, 1);
    expect(session.phase, StudyPhase.completed);
  });

  for (final phase in [
    StudyPhase.paused,
    StudyPhase.supporting,
    StudyPhase.resting,
  ]) {
    test('$phase stops counting until explicitly resumed', () {
      session.start(duration: const Duration(minutes: 5), goal: '  单词  ');
      now = now.add(const Duration(seconds: 40));
      session.pause(phase: phase);
      expect(session.elapsed, const Duration(seconds: 40));
      now = now.add(const Duration(hours: 2));
      session.tick();
      expect(session.phase, phase);
      expect(session.elapsed, const Duration(seconds: 40));
      session.resume();
      session.resume();
      now = now.add(const Duration(seconds: 20));
      session.tick();
      expect(session.elapsed, const Duration(minutes: 1));
      expect(session.goal, '单词');
    });
  }

  test('manual end never awards completion, even at the deadline', () {
    session.start(duration: const Duration(seconds: 5));
    now = now.add(const Duration(seconds: 10));
    session.finish();
    expect(session.phase, StudyPhase.ended);
    session.resume();
    session.tick();
    expect(session.phase, StudyPhase.ended);
  });

  test('restoration pauses active sessions without credit for time away', () {
    session.start(duration: const Duration(minutes: 10), goal: '论文');
    now = now.add(const Duration(seconds: 91));
    final data = jsonDecode(jsonEncode(session.toJson())) as Map;
    now = now.add(const Duration(days: 2));
    session.restore(data);
    expect(session.phase, StudyPhase.paused);
    expect(session.goal, '论文');
    expect(session.elapsed, const Duration(seconds: 91));
    session.tick();
    expect(session.elapsed, const Duration(seconds: 91));
    session.resume();
    now = now.add(const Duration(seconds: 9));
    session.tick();
    expect(session.elapsed, const Duration(seconds: 100));
  });

  test('restored completed sessions cannot earn another completion', () {
    session.start(duration: const Duration(seconds: 1));
    now = now.add(const Duration(seconds: 1));
    session.tick();
    final data = session.toJson();
    session.restore(data);
    var notifications = 0;
    session.addListener(() => notifications++);
    session.resume();
    session.tick();
    expect(session.phase, StudyPhase.completed);
    expect(notifications, 0);
  });

  test('expired active snapshot does not complete on restoration or resume',
      () {
    session.start(duration: const Duration(seconds: 1));
    now = now.add(const Duration(seconds: 2));
    session.restore(session.toJson());
    expect(session.phase, StudyPhase.paused);
    session.resume();
    session.tick();
    expect(session.phase, StudyPhase.paused);
  });

  test('invalid records reset safely and invalid durations are rejected', () {
    session.restore({'phase': 'focusing', 'durationMilliseconds': 'oops'});
    expect(session.phase, StudyPhase.ready);
    expect(() => session.start(duration: Duration.zero), throwsArgumentError);
    expect(() => session.start(duration: const Duration(seconds: -1)),
        throwsArgumentError);
    session.restore(null);
    expect(session.elapsed, Duration.zero);
  });

  test('clock rollback cannot subtract already earned time', () {
    session.start(duration: const Duration(minutes: 5));
    now = now.add(const Duration(seconds: 20));
    session.tick();
    now = now.subtract(const Duration(seconds: 30));
    session.tick();
    expect(session.elapsed, const Duration(seconds: 20));
  });

  testWidgets('timer updates automatically and is cancelled on dispose',
      (tester) async {
    session.start(duration: const Duration(seconds: 2));
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(session.phase, StudyPhase.completed);
    session.start(duration: const Duration(minutes: 1));
    session.dispose();
    session = StudySessionController(now: () => now);
    await tester.pump(const Duration(seconds: 2));
  });
}
