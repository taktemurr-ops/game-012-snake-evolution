import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_012_snake_evolution/main.dart';

void main() {
  test('snake moves forward and cannot reverse directly', () {
    final game = SnakeGame(seed: 3);
    final start = game.snake.first;
    game.turn(SnakeDirection.left);
    expect(game.direction, SnakeDirection.right);
    game.tick();
    expect(game.snake.first, Point(start.x + 1, start.y));
  });

  test('wall collision ends the game', () {
    final game = SnakeGame(width: 6, height: 6, seed: 2);
    for (var i = 0; i < 8; i++) {
      game.tick();
    }
    expect(game.gameOver, isTrue);
  });

  test('reset restores score and length', () {
    final game = SnakeGame();
    game.score = 50;
    game.reset();
    expect(game.score, 0);
    expect(game.snake.length, 2);
    expect(game.gameOver, isFalse);
  });

  testWidgets('snake controls render', (tester) async {
    await tester.pumpWidget(const SnakeEvolutionApp());
    expect(find.byTooltip('Turn left'), findsOneWidget);
    expect(find.byTooltip('Advance one step'), findsOneWidget);
    expect(find.byTooltip('New game'), findsOneWidget);
  });
}
