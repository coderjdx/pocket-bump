import 'dart:math';
import 'package:flutter/material.dart';

/// Native-image pixel coordinates for opponent and player ground platforms
/// inside a battle background asset.
class BattleArenaAnchor {
  final double imgW;
  final double imgH;
  final double oppX;
  final double oppY;
  final double playerX;
  final double playerY;

  const BattleArenaAnchor({
    required this.imgW,
    required this.imgH,
    required this.oppX,
    required this.oppY,
    required this.playerX,
    required this.playerY,
  });

  /// Maps a pixel coordinate `(bgX, bgY)` from `(imgW x imgH)` into the
  /// rendered `BoxFit.cover` arena viewport of size `(arenaW x arenaH)`.
  Offset mapPoint(double bgX, double bgY, double arenaW, double arenaH) {
    final double scale = max(arenaW / imgW, arenaH / imgH);
    final double xOffset = (arenaW - imgW * scale) / 2.0;
    final double yOffset = (arenaH - imgH * scale) / 2.0;
    return Offset(xOffset + bgX * scale, yOffset + bgY * scale);
  }

  Offset mapOpponent(double arenaW, double arenaH) =>
      mapPoint(oppX, oppY, arenaW, arenaH);

  Offset mapPlayer(double arenaW, double arenaH) =>
      mapPoint(playerX, playerY, arenaW, arenaH);
}

/// Calibrated opponent & player platform coordinates for every battle
/// background image in `assets/images/battle_bg_*.png`.
class BattleArenaLayout {
  static const BattleArenaAnchor defaultAnchor = BattleArenaAnchor(
    imgW: 900,
    imgH: 750,
    oppX: 693,
    oppY: 416,
    playerX: 284,
    playerY: 608,
  );

  static const Map<String, BattleArenaAnchor> _byAsset = {
    // 900x750 arenas
    'assets/images/battle_bg_beach.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 690,
      oppY: 410,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_bell_tower.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 668,
      oppY: 514,
      playerX: 284,
      playerY: 616,
    ),
    'assets/images/battle_bg_burned_tower.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 668,
      oppY: 518,
      playerX: 284,
      playerY: 622,
    ),
    'assets/images/battle_bg_cave.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 712,
      oppY: 430,
      playerX: 284,
      playerY: 608,
    ),
    'assets/images/battle_bg_cerulean_cave.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 685,
      oppY: 434,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_e4_dark.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 668,
      oppY: 518,
      playerX: 284,
      playerY: 622,
    ),
    'assets/images/battle_bg_forest.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 690,
      oppY: 412,
      playerX: 284,
      playerY: 608,
    ),
    'assets/images/battle_bg_frontier.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 668,
      oppY: 514,
      playerX: 284,
      playerY: 618,
    ),
    'assets/images/battle_bg_gym_bug.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 668,
      oppY: 518,
      playerX: 284,
      playerY: 622,
    ),
    'assets/images/battle_bg_gym_electric.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 682,
      oppY: 468,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_gym_fire.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 708,
      oppY: 424,
      playerX: 284,
      playerY: 610,
    ),
    'assets/images/battle_bg_gym_flying.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 668,
      oppY: 508,
      playerX: 284,
      playerY: 618,
    ),
    'assets/images/battle_bg_gym_grass.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 685,
      oppY: 414,
      playerX: 284,
      playerY: 610,
    ),
    'assets/images/battle_bg_gym_ground.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 695,
      oppY: 434,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_gym_normal.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 668,
      oppY: 514,
      playerX: 284,
      playerY: 620,
    ),
    'assets/images/battle_bg_gym_poison.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 685,
      oppY: 460,
      playerX: 284,
      playerY: 612,
    ),
    'assets/images/battle_bg_gym_psychic.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 682,
      oppY: 468,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_gym_rock.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 695,
      oppY: 434,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_gym_steel.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 668,
      oppY: 516,
      playerX: 284,
      playerY: 622,
    ),
    'assets/images/battle_bg_gym_water.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 685,
      oppY: 414,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_power_plant.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 700,
      oppY: 442,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_pvp_arena.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 695,
      oppY: 414,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_route.png': defaultAnchor,
    'assets/images/battle_bg_seafoam.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 695,
      oppY: 422,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_urban.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 682,
      oppY: 468,
      playerX: 284,
      playerY: 606,
    ),
    'assets/images/battle_bg_victory_road.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 705,
      oppY: 436,
      playerX: 284,
      playerY: 608,
    ),
    'assets/images/battle_bg_volcano.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 708,
      oppY: 424,
      playerX: 284,
      playerY: 610,
    ),
    'assets/images/battle_bg_whirl_islands.png': BattleArenaAnchor(
      imgW: 900,
      imgH: 750,
      oppX: 668,
      oppY: 518,
      playerX: 284,
      playerY: 620,
    ),

    // 800x480 Elite Four & Champion Hall arenas
    'assets/images/battle_bg_champion_hall.png': BattleArenaAnchor(
      imgW: 800,
      imgH: 480,
      oppX: 585,
      oppY: 316,
      playerX: 240,
      playerY: 404,
    ),
    'assets/images/battle_bg_e4_dragon.png': BattleArenaAnchor(
      imgW: 800,
      imgH: 480,
      oppX: 568,
      oppY: 324,
      playerX: 255,
      playerY: 398,
    ),
    'assets/images/battle_bg_e4_fighting.png': BattleArenaAnchor(
      imgW: 800,
      imgH: 480,
      oppX: 595,
      oppY: 308,
      playerX: 245,
      playerY: 388,
    ),
    'assets/images/battle_bg_e4_ghost.png': BattleArenaAnchor(
      imgW: 800,
      imgH: 480,
      oppX: 595,
      oppY: 326,
      playerX: 240,
      playerY: 398,
    ),
    'assets/images/battle_bg_e4_ice.png': BattleArenaAnchor(
      imgW: 800,
      imgH: 480,
      oppX: 585,
      oppY: 322,
      playerX: 240,
      playerY: 400,
    ),
  };

  static BattleArenaAnchor forAsset(String assetPath) =>
      _byAsset[assetPath] ?? defaultAnchor;
}
