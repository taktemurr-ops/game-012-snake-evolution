import '../core/arcade.dart';
import '../core/level_plan.dart';
import '../core/rng.dart';

/// Snake Evolution: grid snake with walls, portals, wrap edges, poison food,
/// a wandering obstacle and golden bonus food.
class SnakeLevel {
  final ArcadeMeta meta;
  final int cols;
  final int rows;

  /// Ticks per step (lower = faster).
  final int stepTicks;
  final int target; // food to eat, 0 = endless
  final Set<int> walls;
  final List<int> portals; // pairs: [a, b, c, d]
  final bool wrap;
  final bool poison;
  final bool mover;

  const SnakeLevel({
    required this.meta,
    required this.cols,
    required this.rows,
    required this.stepTicks,
    required this.target,
    required this.walls,
    required this.portals,
    required this.wrap,
    required this.poison,
    required this.mover,
  });

  int get start => (rows - 4) * cols + cols ~/ 2;
}

SnakeLevel generateSnakeLevel(LevelSpec spec) {
  final m = ArcadeMeta.of(spec);
  final r = SeededRandom(mixSeed([spec.seed, 12]));
  final d = spec.difficulty;
  final cols = (12 + d ~/ 2 + (spec.has('big') ? 4 : 0)).clamp(10, 20);
  final rows = (cols * 1.45).floor();
  final step = (11 - (d * 0.7).floor()).clamp(4, 11);
  final target = m.goal ? 8 + d * 3 : 0;
  final walls = <int>{};
  final startCell = (rows - 4) * cols + cols ~/ 2;
  bool nearStart(int c) {
    final x = c % cols, y = c ~/ cols;
    return (x - cols ~/ 2).abs() <= 1 && y >= rows - 8;
  }

  if (spec.has('walls') || d >= 4) {
    final segs = 2 + d ~/ 2;
    for (var i = 0; i < segs; i++) {
      final horiz = r.chance(0.5);
      final len = r.range(3, 5 + d ~/ 3);
      final x0 = r.range(2, cols - 3), y0 = r.range(2, rows - 3);
      for (var k = 0; k < len; k++) {
        final x = horiz ? x0 + k : x0, y = horiz ? y0 : y0 + k;
        if (x < 1 || y < 1 || x >= cols - 1 || y >= rows - 1) continue;
        final c = y * cols + x;
        if (!nearStart(c)) walls.add(c);
      }
    }
  }
  final portals = <int>[];
  if (spec.has('portals')) {
    while (portals.length < 4) {
      final c = r.range(cols + 1, cols * (rows - 1) - 2);
      if (walls.contains(c) || portals.contains(c) || nearStart(c) || c == startCell) continue;
      final x = c % cols;
      if (x == 0 || x == cols - 1) continue;
      portals.add(c);
    }
  }
  return SnakeLevel(
    meta: m,
    cols: cols,
    rows: rows,
    stepTicks: step,
    target: target,
    walls: walls,
    portals: portals,
    wrap: spec.has('wrap') || m.zen,
    poison: spec.has('poison'),
    mover: spec.has('mover'),
  );
}

const _dx = [0, 1, 0, -1];
const _dy = [-1, 0, 1, 0];

class SnakeSim extends ArcadeSim {
  final SnakeLevel level;
  List<int> body = [];
  int dir = 0;
  final List<int> _queue = [];
  int timer = 0;
  int food = -1;
  int golden = -1;
  int goldenTtl = 0;
  int poisonCell = -1;
  int moverCell = -1;
  int moverDir = 1;
  int eaten = 0;
  int maxLen = 3;
  int goldenEaten = 0;
  int portalsUsed = 0;
  int combo = 0;
  int lastEatTick = 0;

  /// Visual flags for the painter / sounds.
  int lastEvent = 0; // 1 eat, 2 golden, 3 poison, 4 hit

  SnakeSim(this.level) : super(level.meta) {
    _reset();
    _spawnFood();
    if (level.mover) moverCell = _free(avoidNearHead: true);
  }

  int get cols => level.cols;
  int get rows => level.rows;
  int get head => body.first;

  void _reset() {
    final s = level.start;
    body = [s, s + cols, s + 2 * cols];
    dir = 0;
    _queue.clear();
    timer = 0;
  }

  bool blocked(int c) => level.walls.contains(c) || c == moverCell;

  int _free({bool avoidNearHead = false}) {
    for (var tries = 0; tries < 2000; tries++) {
      final c = rng.nextInt(cols * rows);
      if (blocked(c) || body.contains(c) || c == food || c == golden || c == poisonCell) continue;
      if (level.portals.contains(c)) continue;
      if (avoidNearHead && body.isNotEmpty) {
        final hx = head % cols, hy = head ~/ cols;
        if ((c % cols - hx).abs() + (c ~/ cols - hy).abs() < 4) continue;
      }
      return c;
    }
    for (var c = 0; c < cols * rows; c++) {
      if (!blocked(c) && !body.contains(c) && c != food) return c;
    }
    return -1;
  }

  void _spawnFood() {
    food = _free();
    if (level.poison && rng.chance(0.5)) poisonCell = _free();
  }

  /// Next cell from [c] in direction [d]; -1 = wall/edge death.
  int nextCell(int c, int d) {
    var x = c % cols + _dx[d], y = c ~/ cols + _dy[d];
    if (x < 0 || y < 0 || x >= cols || y >= rows) {
      if (!level.wrap) return -1;
      x = (x + cols) % cols;
      y = (y + rows) % rows;
    }
    var n = y * cols + x;
    final pi = level.portals.indexOf(n);
    if (pi >= 0) n = level.portals[pi ^ 1];
    return n;
  }

  void steer(int d) {
    final last = _queue.isNotEmpty ? _queue.last : dir;
    if (d == last || (d + 2) % 4 == last) return;
    if (_queue.length < 2) _queue.add(d);
  }

  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    if (input.swipe >= 0) {
      steer(input.swipe);
    } else if (input.tap && input.hasPointer) {
      // One-hand control: turn toward the tapped side of the head.
      final hx = (head % cols + 0.5) * cellSize, hy = top + (head ~/ cols + 0.5) * cellSize;
      final cur = _queue.isNotEmpty ? _queue.last : dir;
      if (cur == 0 || cur == 2) {
        steer(input.x < hx ? 3 : 1);
      } else {
        steer(input.y < hy ? 0 : 2);
      }
    } else if (input.dirX != 0) {
      steer(input.dirX > 0 ? 1 : 3);
    } else if (input.dirY != 0) {
      steer(input.dirY > 0 ? 2 : 0);
    }
    if (goldenTtl > 0 && --goldenTtl == 0) golden = -1;
    if (level.mover && ticks % 24 == 0) _moveMover();
    timer++;
    final speedUp = (body.length ~/ 12).clamp(0, 2);
    if (timer < level.stepTicks - speedUp) return;
    timer = 0;
    if (_queue.isNotEmpty) dir = _queue.removeAt(0);
    _step();
  }

  void _moveMover() {
    if (moverCell < 0) return;
    for (var k = 0; k < 4; k++) {
      final d = (moverDir + k) % 4;
      final x = moverCell % cols + _dx[d], y = moverCell ~/ cols + _dy[d];
      if (x < 1 || y < 1 || x >= cols - 1 || y >= rows - 1) continue;
      final n = y * cols + x;
      if (level.walls.contains(n) || body.contains(n) || n == food || level.portals.contains(n)) continue;
      // Never move right in front of the snake.
      if (nextCell(head, dir) == n) continue;
      moverCell = n;
      moverDir = rng.chance(0.25) ? rng.nextInt(4) : d;
      return;
    }
  }

  void _step() {
    final n = nextCell(head, dir);
    if (portalAt(n)) portalsUsed++;
    final grows = n == food || n == golden;
    final tailMoves = !grows;
    final hitsBody = body.contains(n) && !(tailMoves && n == body.last);
    if (n < 0 || blocked(n) || hitsBody) {
      if (meta.zen) {
        // Zen: turn instead of dying.
        for (final d in [(dir + 1) % 4, (dir + 3) % 4]) {
          final c = nextCell(head, d);
          if (c >= 0 && !blocked(c) && !body.contains(c)) {
            dir = d;
            _step();
            return;
          }
        }
        return;
      }
      lastEvent = 4;
      hit();
      return;
    }
    body.insert(0, n);
    if (n == food) {
      eaten++;
      combo = ticks - lastEatTick < 60 * 5 ? combo + 1 : 1;
      lastEatTick = ticks;
      score += 10 * combo.clamp(1, 5);
      lastEvent = 1;
      if (eaten % 5 == 0 && golden < 0) {
        golden = _free(avoidNearHead: true);
        goldenTtl = 60 * 7;
      }
      _spawnFood();
      if (level.target > 0 && eaten >= level.target) win();
    } else if (n == golden) {
      golden = -1;
      goldenEaten++;
      score += 60;
      lastEvent = 2;
    } else {
      body.removeLast();
    }
    if (n == poisonCell) {
      poisonCell = -1;
      score = (score - 15).clamp(0, 1 << 30);
      if (body.length > 3) body.removeLast();
      lastEvent = 3;
    }
    if (body.length > maxLen) maxLen = body.length;
  }

  bool portalAt(int c) => c >= 0 && level.portals.contains(c);

  @override
  void onLifeLost() {
    _reset();
    if (food < 0 || body.contains(food)) _spawnFood();
  }

  double get cellSize => kWorldW / cols;
  double get top => (kWorldH - rows * cellSize) / 2;

  @override
  double get progress => level.target == 0 ? 0 : eaten / level.target;

  @override
  String get goalText => level.target == 0 ? '$eaten' : '$eaten/${level.target}';

  @override
  Map<String, int> get stats => {
        'food_eaten': eaten,
        'max_length': maxLen,
        'golden_food': goldenEaten,
        'portals_used': portalsUsed,
      };

  @override
  int get stars => lifeStars(this, 3);
}

/// Autopilot: BFS to food (avoiding body, walls, poison and the mover);
/// falls back to the move with the largest reachable area.
ArcadeInput snakeBot(ArcadeSim s) {
  final g = s as SnakeSim;
  final need = g.timer + 1 >= g.level.stepTicks - (g.body.length ~/ 12).clamp(0, 2);
  if (!need) return ArcadeInput.idle;
  final d = bestSnakeDir(g);
  if (d == null || d == g.dir) return ArcadeInput.idle;
  return ArcadeInput(swipe: d);
}

int? bestSnakeDir(SnakeSim g) {
  final n = g.cols * g.rows;
  final blocked = List<bool>.filled(n, false);
  for (final c in g.level.walls) {
    blocked[c] = true;
  }
  for (var i = 0; i < g.body.length - 1; i++) {
    blocked[g.body[i]] = true;
  }
  if (g.poisonCell >= 0) blocked[g.poisonCell] = true;
  if (g.moverCell >= 0) {
    blocked[g.moverCell] = true;
    for (var d = 0; d < 4; d++) {
      final c = g.nextCell(g.moverCell, d);
      if (c >= 0) blocked[c] = true;
    }
  }
  final targets = <int>{if (g.food >= 0) g.food, if (g.golden >= 0) g.golden};
  // BFS from head.
  final first = List<int>.filled(n, -1);
  final dist = List<int>.filled(n, -1);
  final q = <int>[];
  for (var d = 0; d < 4; d++) {
    if ((d + 2) % 4 == g.dir) continue;
    final c = g.nextCell(g.head, d);
    if (c < 0 || blocked[c] || dist[c] >= 0) continue;
    dist[c] = 1;
    first[c] = d;
    q.add(c);
  }
  int? found;
  for (var qi = 0; qi < q.length; qi++) {
    final c = q[qi];
    if (targets.contains(c)) {
      found = c;
      break;
    }
    for (var d = 0; d < 4; d++) {
      final m = g.nextCell(c, d);
      if (m < 0 || blocked[m] || dist[m] >= 0) continue;
      dist[m] = dist[c] + 1;
      first[m] = first[c];
      q.add(m);
    }
  }
  int area(int start) {
    final seen = <int>{start};
    final st = [start];
    while (st.isNotEmpty && seen.length < 400) {
      final c = st.removeLast();
      for (var d = 0; d < 4; d++) {
        final m = g.nextCell(c, d);
        if (m < 0 || blocked[m] || seen.contains(m)) continue;
        seen.add(m);
        st.add(m);
      }
    }
    return seen.length;
  }

  if (found != null) {
    final d = first[found];
    final c = g.nextCell(g.head, d);
    if (area(c) >= g.body.length + 2) return d;
  }
  int? best;
  var bestArea = -1;
  for (var d = 0; d < 4; d++) {
    if ((d + 2) % 4 == g.dir) continue;
    final c = g.nextCell(g.head, d);
    if (c < 0 || blocked[c]) continue;
    final a = area(c);
    if (a > bestArea) {
      bestArea = a;
      best = d;
    }
  }
  return best;
}
