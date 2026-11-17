import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_012_snake_evolution/main.dart';

void main() {
  test('reset creates two segments and valid food', () {
    final game = SnakeGame(width: 8, height: 8, seed: 7);
    expect(game.snake.length, 2);
    expect(game.score, 0);
    expect(game.snake.contains(game.food), isFalse);
    game.reset();
    expect(game.gameOver, isFalse);
    expect(game.direction, SnakeDirection.right);
  });

  test('reverse turns are rejected', () {
    final game = SnakeGame(width: 8, height: 8);
    game.turn(SnakeDirection.left);
    expect(game.direction, SnakeDirection.right);
  });

  test('only one valid direction change is accepted per tick', () {
    final game = SnakeGame(width: 8, height: 8);
    game.turn(SnakeDirection.up);
    game.turn(SnakeDirection.left);
    expect(game.direction, SnakeDirection.up);
    game.tick();
    game.turn(SnakeDirection.left);
    expect(game.direction, SnakeDirection.left);
  });

  test('moving into vacated tail cell is legal', () {
    final game = SnakeGame(width: 8, height: 8);
    game.snake = [const Point(3, 3), const Point(3, 4)];
    game.food = const Point(7, 7);
    game.direction = SnakeDirection.down;
    game.tick();
    expect(game.gameOver, isFalse);
    expect(game.snake.first, const Point(3, 4));
  });

  test('eating increases score and length', () {
    final game = SnakeGame(width: 8, height: 8);
    final head = game.snake.first;
    game.food = Point(head.x + 1, head.y);
    game.tick();
    expect(game.score, 10);
    expect(game.snake.length, 3);
    expect(game.snake.contains(game.food), isFalse);
  });

  test('wall collision ends game and prevents further movement', () {
    final game = SnakeGame(width: 4, height: 4);
    game.tick();
    game.tick();
    expect(game.gameOver, isTrue);
    final previous = List<Point<int>>.of(game.snake);
    game.tick();
    expect(game.snake, previous);
  });
}
