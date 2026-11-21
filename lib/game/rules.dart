import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'snake_engine.dart';

class SnakeRules extends ArcadeRules<SnakeLevel> {
  @override
  String get gameId => 'game-012-snake-evolution';

  @override
  List<String> get optionalMechanics => const ['walls', 'portals', 'wrap', 'poison', 'mover', 'big'];

  @override
  List<GameStat> get gameStats => const [
        GameStat('food_eaten', 'Yem', 'Food eaten', scale: 50),
        GameStat('golden_food', 'Altın yem', 'Golden food', scale: 5),
        GameStat('portals_used', 'Portal geçişi', 'Portal trips', scale: 10),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('food_eaten', 'food_eaten', [30, 80, 160]),
        MissionTemplate('golden_food', 'golden_food', [2, 5, 10]),
      ];

  @override
  SnakeLevel generate(LevelSpec spec) => generateSnakeLevel(spec);

  @override
  ArcadeMeta metaOf(SnakeLevel l) => l.meta;

  @override
  ArcadeSim createSim(SnakeLevel l) => SnakeSim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => snakeBot(sim);

  @override
  String? check(SnakeLevel l) {
    if (l.walls.contains(l.start) || l.walls.contains(l.start - l.cols)) return 'start blocked';
    return null;
  }
}

ArcadeRules createRules() => SnakeRules();
