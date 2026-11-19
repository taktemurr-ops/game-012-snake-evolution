import 'package:flutter_test/flutter_test.dart';
import 'package:game_012_snake_evolution/core/arcade.dart';
import 'package:game_012_snake_evolution/core/level_plan.dart';
import 'package:game_012_snake_evolution/game/rules.dart';
import 'package:game_012_snake_evolution/game/snake_engine.dart';

void main() {
  final rules = SnakeRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('snake moves, eats and grows', () {
    final l = rules.build(planner.spec(1)).puzzle;
    final s = SnakeSim(l);
    final len = s.body.length;
    s.food = s.nextCell(s.head, 0);
    for (var i = 0; i < l.stepTicks; i++) {
      s.tick(ArcadeInput.idle);
    }
    expect(s.eaten, 1);
    expect(s.body.length, len + 1);
  });

  test('reverse direction is ignored, wall hit costs a life', () {
    final l = rules.build(planner.spec(1)).puzzle;
    final s = SnakeSim(l);
    s.tick(const ArcadeInput(swipe: 2));
    expect(s.dir, 0);
    final lives = s.lives;
    for (var i = 0; i < l.stepTicks * (l.rows + 2) && s.lives == lives; i++) {
      s.food = -1;
      s.tick(ArcadeInput.idle);
    }
    expect(s.lives, lives - 1);
  });

  test('input replay reproduces the same state (resume)', () {
    final l = rules.build(planner.spec(37)).puzzle;
    final a = SnakeSim(l);
    final log = <List<int>>[];
    var last = ArcadeInput.idle;
    for (var t = 0; t < 900 && !a.over; t++) {
      final i = rules.bot(a).quantized();
      if (!i.sameAs(last)) {
        log.add([a.ticks + 1, ...i.encode()]);
        last = i;
      }
      a.tick(i);
    }
    final b = SnakeSim(l);
    replayLog(b, log, a.ticks);
    expect(b.body, a.body);
    expect(b.score, a.score);
  });

  test('zen never dies', () {
    final s = SnakeSim(rules.build(planner.run(GameModeId.zen, 2)).puzzle);
    for (var t = 0; t < 3000; t++) {
      s.tick(const ArcadeInput(swipe: 1));
    }
    expect(s.over, isFalse);
  });

  test('campaign levels 1..60 finished by the bot, sample to 50.000', () {
    for (var n = 1; n <= 60; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
    for (var n = 2000; n <= 50000; n += 6000) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
  });
}
