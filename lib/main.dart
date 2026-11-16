import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const SnakeEvolutionApp());

enum SnakeDirection { up, right, down, left }

class SnakeGame {
  SnakeGame({this.width = 14, this.height = 18, int seed = 1})
      : random = Random(seed) {
    reset();
  }

  final int width;
  final int height;
  final Random random;
  late List<Point<int>> snake;
  late Point<int> food;
  SnakeDirection direction = SnakeDirection.right;
  int score = 0;
  bool gameOver = false;

  void reset() {
    snake = [Point(width ~/ 2, height ~/ 2), Point(width ~/ 2 - 1, height ~/ 2)];
    direction = SnakeDirection.right;
    score = 0;
    gameOver = false;
    placeFood();
  }

  void placeFood() {
    final free = <Point<int>>[
      for (var y = 0; y < height; y++)
        for (var x = 0; x < width; x++)
          if (!snake.contains(Point(x, y))) Point(x, y),
    ];
    if (free.isEmpty) {
      gameOver = true;
      return;
    }
    food = free[random.nextInt(free.length)];
  }

  void turn(SnakeDirection next) {
    if (gameOver) return;
    final opposite = (direction.index + 2) % 4;
    if (next.index != opposite) direction = next;
  }

  void tick() {
    if (gameOver) return;
    final head = snake.first;
    final delta = switch (direction) {
      SnakeDirection.up => const Point(0, -1),
      SnakeDirection.right => const Point(1, 0),
      SnakeDirection.down => const Point(0, 1),
      SnakeDirection.left => const Point(-1, 0),
    };
    final next = Point(head.x + delta.x, head.y + delta.y);
    final eating = next == food;
    if (next.x < 0 || next.y < 0 || next.x >= width || next.y >= height ||
        snake.take(eating ? snake.length : snake.length - 1).contains(next)) {
      gameOver = true;
      return;
    }
    snake.insert(0, next);
    if (eating) {
      score += 10;
      placeFood();
    } else {
      snake.removeLast();
    }
  }
}

class SnakeEvolutionApp extends StatelessWidget {
  const SnakeEvolutionApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Snake Evolution',
        theme: ThemeData.dark(useMaterial3: true),
        home: const SnakeScreen(),
      );
}

class SnakeScreen extends StatefulWidget {
  const SnakeScreen({super.key});

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen> {
  SnakeGame game = SnakeGame();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Snake Evolution')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Text('Score: ${game.score}  •  Length: ${game.snake.length}',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: game.width / game.height,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: game.width * game.height,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: game.width,
                          crossAxisSpacing: 1,
                          mainAxisSpacing: 1,
                        ),
                        itemBuilder: (context, index) {
                          final p = Point(index % game.width, index ~/ game.width);
                          final color = game.snake.first == p
                              ? Colors.lightGreenAccent
                              : game.snake.contains(p)
                                  ? Colors.green
                                  : game.food == p
                                      ? Colors.redAccent
                                      : const Color(0xFF1B2C35);
                          return ColoredBox(color: color);
                        },
                      ),
                    ),
                  ),
                  if (game.gameOver)
                    const Text('Game over', key: ValueKey('game-over')),
                  const SizedBox(height: 8),
                  Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
                    IconButton.filledTonal(
                      tooltip: 'Turn left',
                      onPressed: () => setState(() => game.turn(SnakeDirection.left)),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Turn up',
                      onPressed: () => setState(() => game.turn(SnakeDirection.up)),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Turn down',
                      onPressed: () => setState(() => game.turn(SnakeDirection.down)),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Turn right',
                      onPressed: () => setState(() => game.turn(SnakeDirection.right)),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    IconButton.filled(
                      tooltip: 'Advance one step',
                      onPressed: game.gameOver ? null : () => setState(game.tick),
                      icon: const Icon(Icons.play_arrow),
                    ),
                    IconButton.outlined(
                      tooltip: 'New game',
                      onPressed: () => setState(game.reset),
                      icon: const Icon(Icons.refresh),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      );
}
