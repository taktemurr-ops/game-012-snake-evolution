import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_012_snake_evolution/main.dart';

void main() {
  test('snake cannot reverse into itself', () {
    final game = SnakeGame(seed: 42);
    expect(game.direction, SnakeDirection.right);
    game.turn(SnakeDirection.left);
    expect(game.direction, SnakeDirection.right);
    game.turn(SnakeDirection.up);
    expect(game.direction, SnakeDirection.up);
    game.turn(SnakeDirection.down);
    expect(game.direction, SnakeDirection.up);
  });

  test('reset restores score, length, direction and live state', () {
    final game = SnakeGame(seed: 12);
    game.score = 50;
    game.gameOver = true;
    game.reset();
    expect(game.score, 0);
    expect(game.gameOver, isFalse);
    expect(game.snake.length, 2);
    expect(game.direction, SnakeDirection.right);
    expect(game.snake.contains(game.food), isFalse);
  });

  test('collision with wall ends the game', () {
    final game = SnakeGame(width: 6, height: 6, seed: 3);
    game.food = const Point(0, 0);
    for (var i = 0; i < 4; i++) {
      game.tick();
    }
    expect(game.gameOver, isTrue);
  });
}
