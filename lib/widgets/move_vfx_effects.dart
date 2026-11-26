import 'dart:math';
import 'package:flutter/material.dart';
import '../models/move.dart';
import '../models/pokemon_type.dart';

/// Rich, multi-layered custom canvas VFX renderer for Pocket Bump moves.
///
/// Covers fractal branching lightning for all Electric moves, upgrades earlier
/// rudimentary circle/line animations, and renders tailored multi-stage
/// animations for all moves without falling back to a plain circle.
class MoveVfxEffects {
  /// Deterministic pseudo-random helper returning `[-1.0, 1.0]`.
  static double _hashSigned(int seed, int step, int frame) {
    int x = seed * 374761393 + step * 668265263 + frame * 1274126177;
    x = (x ^ (x >> 13)) * 1274126177;
    x = x ^ (x >> 16);
    return ((x & 0xFFFF) / 32767.5) - 1.0;
  }

  /// Draws multi-layered fractal crackling lightning with outer electric glow,
  /// bright plasma channel, white-hot core, optional forked branches, and impact nodes.
  static void drawArcLightning(
    Canvas canvas,
    Offset start,
    Offset end,
    double t,
    double fade, {
    double strokeWidth = 4.0,
    int segments = 7,
    double jitter = 16.0,
    int seed = 0,
    bool drawBranches = true,
    bool drawTerminals = true,
    Color outerColor = const Color(0xFFFFD600),
    Color midColor = Colors.yellowAccent,
    Color coreColor = Colors.white,
  }) {
    final diff = end - start;
    final len = diff.distance;
    if (len < 1.0 || fade <= 0.01) return;
    final unit = diff / len;
    final perp = Offset(-unit.dy, unit.dx);
    final frame = (t * 18.0).floor();

    final pts = <Offset>[start];
    for (int i = 1; i < segments; i++) {
      final frac = i / segments;
      final env = sin(frac * pi);
      final offset = _hashSigned(seed, i, frame) * jitter * env;
      pts.add(Offset.lerp(start, end, frac)! + perp * offset);
    }
    pts.add(end);

    final mainPath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      mainPath.lineTo(pts[i].dx, pts[i].dy);
    }

    canvas.drawPath(
      mainPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 3.1 * fade
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = outerColor.withOpacity(0.28 * fade),
    );
    canvas.drawPath(
      mainPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.15 * fade
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = midColor.withOpacity(0.95 * fade),
    );
    canvas.drawPath(
      mainPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, strokeWidth * 0.42 * fade)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = coreColor.withOpacity(fade),
    );

    if (drawBranches && pts.length >= 4 && len > 28.0) {
      final branchCount = segments >= 7 ? 3 : 2;
      for (int b = 0; b < branchCount; b++) {
        final anchorIdx = (1 + ((b + 1) * (pts.length - 2) / (branchCount + 1)).floor())
            .clamp(1, pts.length - 2);
        final anchor = pts[anchorIdx];
        final sideSign = (seed + b + frame).isEven ? 1.0 : -1.0;
        final bDir = (unit * 0.72 + perp * (sideSign * 0.68));
        final bNorm = bDir / max(0.001, bDir.distance);
        final bPerp = Offset(-bNorm.dy, bNorm.dx);
        final bLen = (len * 0.24).clamp(14.0, 42.0);
        final mid = anchor +
            bNorm * (bLen * 0.52) +
            bPerp * (_hashSigned(seed + 41, b, frame) * 7.0);
        final tip = anchor + bNorm * bLen;
        final bp = Path()
          ..moveTo(anchor.dx, anchor.dy)
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(tip.dx, tip.dy);
        canvas.drawPath(
          bp,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth * 1.4 * fade
            ..strokeCap = StrokeCap.round
            ..color = outerColor.withOpacity(0.25 * fade),
        );
        canvas.drawPath(
          bp,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.2, strokeWidth * 0.45 * fade)
            ..strokeCap = StrokeCap.round
            ..color = coreColor.withOpacity(0.92 * fade),
        );
      }
    }

    if (drawTerminals) {
      canvas.drawCircle(
        end,
        (strokeWidth * 2.2) * fade,
        Paint()..color = outerColor.withOpacity(0.32 * fade),
      );
      canvas.drawCircle(
        end,
        (strokeWidth * 0.85) * fade,
        Paint()..color = coreColor.withOpacity(0.95 * fade),
      );
    }
  }

  /// Renders specific moves and returns `true` if handled cleanly.
  static bool tryPaintMove({
    required Canvas canvas,
    required Size size,
    required String moveId,
    required PokemonType moveType,
    required MoveCategory moveCategory,
    required double t,
    required double fade,
    required bool isSelfTarget,
    required Offset attackerCenter,
    required Offset defenderCenter,
    required double attackerSize,
    required double defenderSize,
    required Offset dir,
    required double dist,
    required Offset unit,
    required Offset perp,
  }) {
    // ─── 1. ALL 14 ELECTRIC MOVES (FRACTAL ARC LIGHTNING) ────────────────────
    switch (moveId) {
      case 'thunder_shock':
        _paintElectricShock(canvas, attackerCenter, defenderCenter, t, fade, unit, perp);
        return true;
      case 'electro_ball':
        _paintElectroBall(canvas, attackerCenter, defenderCenter, t, fade);
        return true;
      case 'thunderbolt':
        _paintThunderbolt(canvas, defenderCenter, t, fade);
        return true;
      case 'thunder':
        _paintThunder(canvas, defenderCenter, t, fade);
        return true;
      case 'thunder_wave':
        _paintThunderWave(canvas, attackerCenter, defenderCenter, t, fade);
        return true;
      case 'shock_wave':
        _paintShockWave(canvas, attackerCenter, defenderCenter, t, fade, unit, perp);
        return true;
      case 'discharge':
        _paintDischarge(canvas, attackerCenter, defenderCenter, t, fade);
        return true;
      case 'thunder_punch':
        _paintElementalPunch(
          canvas, attackerCenter, defenderCenter, t, fade, unit, perp,
          outer: const Color(0xFFFFD600), inner: Colors.white, flavor: 'electric',
        );
        return true;
      case 'zap_cannon':
        _paintZapCannon(canvas, attackerCenter, defenderCenter, t, fade, unit, perp);
        return true;
      case 'charge_beam':
        _paintChargeBeam(canvas, attackerCenter, defenderCenter, t, fade, unit, perp);
        return true;
      case 'spark':
        _paintSparkDash(canvas, attackerCenter, defenderCenter, t, fade, unit, perp);
        return true;
      case 'charge':
        _paintElectricCharge(canvas, attackerCenter, t, fade);
        return true;
      case 'magnet_rise':
        _paintMagnetRise(canvas, attackerCenter, t, fade);
        return true;
      case 'thunder_fang':
        _paintElementalFang(
          canvas, defenderCenter, t, fade,
          toothColor: Colors.yellowAccent, glowColor: const Color(0xFFFFAB00), flavor: 'electric',
        );
        return true;

      // ─── 2. UPGRADED RUDIMENTARY EXISTING MOVES ──────────────────────────────
      case 'fire_fang':
        _paintElementalFang(
          canvas, defenderCenter, t, fade,
          toothColor: const Color(0xFFFF6D00), glowColor: Colors.yellowAccent, flavor: 'fire',
        );
        return true;
      case 'ice_fang':
        _paintElementalFang(
          canvas, defenderCenter, t, fade,
          toothColor: Colors.lightBlueAccent, glowColor: Colors.white, flavor: 'ice',
        );
        return true;
      case 'poison_fang':
        _paintElementalFang(
          canvas, defenderCenter, t, fade,
          toothColor: const Color(0xFFAB47BC), glowColor: Colors.purpleAccent, flavor: 'poison',
        );
        return true;
      case 'bite':
      case 'crunch':
      case 'hyper_fang':
      case 'bug_bite':
        _paintElementalFang(
          canvas, defenderCenter, t, fade,
          toothColor: moveId == 'bug_bite'
              ? const Color(0xFF9CCC65)
              : (moveId == 'crunch' ? const Color(0xFF4527A0) : const Color(0xFFECEFF1)),
          glowColor: moveId == 'bug_bite'
              ? Colors.lightGreenAccent
              : (moveId == 'crunch' ? Colors.deepPurpleAccent : Colors.white),
          flavor: moveId == 'crunch' ? 'dark' : 'normal',
          heavy: moveId == 'crunch' || moveId == 'hyper_fang',
        );
        return true;
      case 'fire_punch':
        _paintElementalPunch(
          canvas, attackerCenter, defenderCenter, t, fade, unit, perp,
          outer: Colors.deepOrangeAccent, inner: Colors.yellowAccent, flavor: 'fire',
        );
        return true;
      case 'ice_punch':
        _paintElementalPunch(
          canvas, attackerCenter, defenderCenter, t, fade, unit, perp,
          outer: Colors.lightBlueAccent, inner: Colors.white, flavor: 'ice',
        );
        return true;
      case 'mach_punch':
      case 'bullet_punch':
      case 'shadow_punch':
      case 'dynamic_punch':
      case 'focus_punch':
      case 'drain_punch':
      case 'dizzy_punch':
      case 'hammer_arm':
      case 'arm_thrust':
      case 'sky_uppercut':
      case 'wake_up_slap':
        _paintHeavyStrikeMove(
          canvas, attackerCenter, defenderCenter, t, fade, unit, perp,
          moveId: moveId, moveType: moveType,
        );
        return true;
      case 'mega_kick':
      case 'jump_kick':
      case 'high_jump_kick':
      case 'rolling_kick':
      case 'blaze_kick':
      case 'low_kick':
      case 'low_sweep':
        _paintKickCombo(
          canvas, defenderCenter, t, fade, unit, perp,
          color: moveType.color,
          isFire: moveId == 'blaze_kick',
          isSweep: moveId == 'low_kick' || moveId == 'low_sweep',
        );
        return true;
      case 'take_down':
      case 'stomp':
      case 'flare_blitz':
      case 'brave_bird':
      case 'giga_impact':
      case 'head_smash':
      case 'wood_hammer':
      case 'heat_crash':
      case 'heavy_slam':
      case 'steamroller':
      case 'dragon_rush':
      case 'revenge':
      case 'facade':
      case 'retaliate':
      case 'superpower':
      case 'last_resort':
      case 'chip_away':
      case 'feint_attack':
      case 'pursuit':
      case 'sucker_punch':
      case 'assurance':
      case 'payback':
      case 'punishment':
      case 'avalanche':
        _paintHeavyChargeImpact(
          canvas, attackerCenter, defenderCenter, t, fade, unit, perp,
          moveId: moveId, moveType: moveType,
        );
        return true;
      case 'constrict':
      case 'wrap':
      case 'bind':
      case 'clamp':
      case 'power_whip':
        _paintBindingVinesOrCoils(
          canvas, attackerCenter, defenderCenter, t, fade, unit, perp,
          moveType: moveType, isWhip: moveId == 'power_whip',
        );
        return true;
      case 'snore':
      case 'sleep_talk':
      case 'uproar':
      case 'hyper_voice':
      case 'bug_buzz':
      case 'roar':
      case 'screech':
      case 'metal_sound':
      case 'supersonic':
      case 'perish_song':
      case 'round':
      case 'chatter':
        _paintSoundWaveMove(
          canvas, attackerCenter, defenderCenter, t, fade, unit, perp,
          moveId: moveId, moveType: moveType,
        );
        return true;
      case 'powder_snow':
      case 'icy_wind':
      case 'ice_shard':
      case 'icicle_spear':
      case 'icicle_crash':
      case 'sheer_cold':
      case 'hail':
      case 'mist':
      case 'haze':
        _paintIceMove(
          canvas, size, attackerCenter, defenderCenter, t, fade, unit, perp,
          moveId: moveId,
        );
        return true;
    }

    // ─── 3. ALL PREVIOUSLY UNMAPPED MOVES GROUPED BY SIGNATURE MECHANICS ─────
    if (_weatherMoves.contains(moveId)) {
      _paintWeatherMove(canvas, size, attackerCenter, defenderCenter, t, fade, moveId);
      return true;
    }
    if (_shieldMoves.contains(moveId)) {
      _paintShieldBarrier(canvas, attackerCenter, defenderCenter, t, fade, moveId, moveType);
      return true;
    }
    if (_hazardMoves.contains(moveId)) {
      _paintEntryHazard(canvas, defenderCenter, t, fade, moveId);
      return true;
    }
    if (_slashMoves.contains(moveId)) {
      _paintElementalSlash(canvas, defenderCenter, t, fade, moveType, moveId);
      return true;
    }
    if (_beamMoves.contains(moveId)) {
      _paintElementalBeam(canvas, attackerCenter, defenderCenter, t, fade, unit, perp, moveType, moveId);
      return true;
    }
    if (_orbBurstMoves.contains(moveId)) {
      _paintElementalOrbOrWave(canvas, attackerCenter, defenderCenter, t, fade, unit, perp, moveType, moveId);
      return true;
    }
    if (_groundRockMoves.contains(moveId)) {
      _paintEarthRockMove(canvas, size, attackerCenter, defenderCenter, t, fade, unit, perp, moveType, moveId);
      return true;
    }
    if (_grassMoves.contains(moveId)) {
      _paintGrassMove(canvas, attackerCenter, defenderCenter, t, fade, unit, perp, moveId);
      return true;
    }
    if (_fireMoves.contains(moveId)) {
      _paintFireSpecialMove(canvas, attackerCenter, defenderCenter, t, fade, unit, perp, moveId);
      return true;
    }
    if (_waterMoves.contains(moveId)) {
      _paintWaterSpecialMove(canvas, attackerCenter, defenderCenter, t, fade, unit, perp, moveId);
      return true;
    }
    if (_flyingBugMoves.contains(moveId)) {
      _paintWindOrBugMove(canvas, attackerCenter, defenderCenter, t, fade, unit, perp, moveType, moveId);
      return true;
    }
    if (_ghostDarkPsychicStatusMoves.contains(moveId)) {
      _paintMysticShadowMove(canvas, attackerCenter, defenderCenter, t, fade, unit, perp, moveType, moveId);
      return true;
    }
    if (_boostDanceMoves.contains(moveId)) {
      _paintBoostOrAuraMove(canvas, attackerCenter, t, fade, moveType, moveId);
      return true;
    }
    if (_utilityDebuffMoves.contains(moveId)) {
      _paintTargetedUtilityMove(canvas, attackerCenter, defenderCenter, t, fade, unit, perp, moveType, moveId);
      return true;
    }
    if (_physicalComboMoves.contains(moveId)) {
      _paintPhysicalSkillMove(canvas, attackerCenter, defenderCenter, t, fade, unit, perp, moveType, moveId);
      return true;
    }

    return false;
  }

  /// Category & type-aware multi-layered fallback (replaces the old single circle).
  static void paintFallback({
    required Canvas canvas,
    required Size size,
    required PokemonType moveType,
    required MoveCategory moveCategory,
    required double t,
    required double fade,
    required bool isSelfTarget,
    required Offset attackerCenter,
    required Offset defenderCenter,
    required Offset unit,
    required Offset perp,
  }) {
    final c = moveType.color;
    if (moveCategory == MoveCategory.status) {
      final center = isSelfTarget ? attackerCenter : defenderCenter;
      _drawAuraRings(canvas, center, t, fade, c, ascending: isSelfTarget);
      return;
    }
    if (moveCategory == MoveCategory.special) {
      final flyT = min(1.0, t / 0.62);
      final pos = Offset.lerp(attackerCenter, defenderCenter, flyT)!;
      if (t < 0.72) {
        _drawGlowOrb(canvas, pos, 14.0 * fade, c, Colors.white, fade);
        for (int i = 1; i <= 4; i++) {
          final wt = max(0.0, flyT - i * 0.08);
          final wp = Offset.lerp(attackerCenter, defenderCenter, wt)!;
          canvas.drawCircle(
            wp,
            max(2.5, (11.0 - i * 2.0) * fade),
            Paint()..color = c.withOpacity((0.6 - i * 0.1) * fade),
          );
        }
      }
      if (t > 0.48) {
        final imp = ((t - 0.48) / 0.52).clamp(0.0, 1.0);
        _drawStarburst(canvas, defenderCenter, 14 + imp * 34, c, Colors.white, fade, points: 8, rot: t * 3);
      }
      return;
    }
    // Physical fallback: kinetic rush + sharp impact burst + shockwave ring
    final dash = Curves.easeOut.transform(min(1.0, t * 2.1));
    for (int i = -1; i <= 1; i++) {
      final p0 = attackerCenter + perp * (i * 12.0);
      final p1 = Offset.lerp(p0, defenderCenter + perp * (i * 8.0), dash)!;
      canvas.drawLine(
        p0,
        p1,
        Paint()
          ..color = c.withOpacity(0.55 * fade)
          ..strokeWidth = 4.5 * fade
          ..strokeCap = StrokeCap.round,
      );
    }
    if (t > 0.35) {
      final imp = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
      _drawStarburst(canvas, defenderCenter, 12 + imp * 32, c, Colors.white, fade, points: 6, rot: t * 4);
    }
  }

  // ─── GROUP TABLES FOR ALL 267 REMAINING MOVES ─────────────────────────────
  static const Set<String> _weatherMoves = {
    'sunny_day', 'rain_dance', 'sandstorm',
  };

  static const Set<String> _shieldMoves = {
    'protect', 'detect', 'endure', 'quick_guard', 'wide_guard',
    'magic_coat', 'safeguard', 'lucky_chant', 'mirror_coat', 'counter',
  };

  static const Set<String> _hazardMoves = {
    'spikes', 'toxic_spikes', 'stealth_rock',
  };

  static const Set<String> _slashMoves = {
    'night_slash', 'shadow_claw', 'psycho_cut', 'cross_poison',
    'leaf_blade', 'air_cutter', 'aerial_ace', 'crush_claw',
    'metal_claw', 'razor_shell', 'fury_cutter', 'dragon_tail',
    'false_swipe', 'iron_tail',
  };

  static const Set<String> _beamMoves = {
    'signal_beam', 'aurabeam', 'dragon_pulse', 'dark_pulse', 'aura_sphere',
    'extrasensory', 'psyshock', 'psystrike', 'future_sight', 'synchronoise',
    'stored_power', 'mirror_shot', 'acid_spray',
  };

  static const Set<String> _orbBurstMoves = {
    'energy_ball', 'mud_bomb', 'mud_shot', 'gunk_shot', 'sludge_wave',
    'smog', 'clear_smog', 'magnet_bomb', 'vacuum_wave', 'brick_break',
    'hurricane', 'twister', 'gyro_ball', 'rapid_spin', 'bullet_seed',
    'barrage', 'rock_blast',
  };

  static const Set<String> _groundRockMoves = {
    'earth_power', 'bulldoze', 'magnitude', 'sand_tomb', 'sand_attack',
    'bone_rush', 'mud_sport', 'rock_tomb', 'stone_edge', 'smack_down',
    'rock_polish', 'iron_defense',
  };

  static const Set<String> _grassMoves = {
    'leaf_storm', 'leaf_tornado', 'magical_leaf', 'petal_dance',
    'stun_spore', 'rage_powder', 'synthesis', 'ingrain', 'aromatherapy',
    'worry_seed', 'leech_life', 'sweet_scent',
  };

  static const Set<String> _fireMoves = {
    'heat_wave', 'will_o_wisp', 'lava_plume', 'flame_burst',
    'flame_charge', 'inferno', 'eruption',
  };

  static const Set<String> _waterMoves = {
    'muddy_water', 'brine', 'bubble', 'dive', 'whirlpool',
    'aqua_ring', 'water_sport', 'soak',
  };

  static const Set<String> _flyingBugMoves = {
    'acrobatics', 'bounce', 'pluck', 'tailwind', 'sky_drop',
    'feather_dance', 'roost', 'mirror_move', 'megahorn', 'poison_sting',
  };

  static const Set<String> _ghostDarkPsychicStatusMoves = {
    'astonish', 'nightmare', 'curse', 'spite', 'destiny_bond', 'grudge',
    'hex', 'taunt', 'torment', 'flatter', 'memento', 'fake_tears',
    'nasty_plot', 'switcheroo', 'trick', 'gastro_acid', 'role_play',
    'imprison', 'gravity', 'wonder_room', 'telekinesis', 'magic_room',
    'disable', 'mean_look', 'block', 'yawn', 'lovely_kiss', 'swagger',
    'captivate', 'charm', 'moonlight', 'heal_pulse', 'healing_wish',
  };

  static const Set<String> _boostDanceMoves = {
    'dragon_dance', 'quiver_dance', 'calm_mind', 'bulk_up', 'shell_smash',
    'coil', 'cosmic_power', 'work_up', 'growth', 'meditate', 'amnesia',
    'barrier', 'defense_curl', 'minimize', 'belly_drum', 'focus_energy',
    'acupressure', 'stockpile', 'swallow', 'spit_up', 'slack_off',
    'refresh', 'recycle', 'conversion', 'conversion_2', 'camouflage',
    'reflect_type', 'psych_up', 'power_swap', 'guard_swap', 'baton_pass',
    'helping_hand', 'after_you', 'ally_switch', 'follow_me', 'copycat',
    'me_first',
  };

  static const Set<String> _utilityDebuffMoves = {
    'leer', 'scary_face', 'kinesis', 'foresight', 'odor_sleuth',
    'miracle_eye', 'lock_on', 'mind_reader', 'encore', 'tickle',
  };

  static const Set<String> _physicalComboMoves = {
    'meteor_mash', 'double_hit', 'fake_out', 'feint', 'flail',
    'reversal', 'endeavor', 'super_fang', 'final_gambit', 'vital_throw',
    'storm_throw', 'circle_throw', 'heart_stamp', 'trump_card',
    'wring_out', 'natural_gift', 'fling', 'knock_off', 'covet',
    'bestow',
  };

  // ─── ELECTRIC RENDERERS ──────────────────────────────────────────────────

  static void _paintElectricShock(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
  ) {
    final pulse = sin(min(1.0, t * 2.2) * pi).clamp(0.0, 1.0);
    canvas.drawCircle(atk, (14 + pulse * 14) * fade,
        Paint()..color = const Color(0xFFFFD600).withOpacity(0.35 * fade));
    canvas.drawCircle(atk, 7 * fade, Paint()..color = Colors.white.withOpacity(fade));
    for (int i = -1; i <= 1; i++) {
      final off = perp * (i * 9.0);
      drawArcLightning(
        canvas,
        atk + off,
        def + off * 0.7,
        t,
        fade,
        strokeWidth: i == 0 ? 4.4 : 2.6,
        segments: 7,
        jitter: i == 0 ? 15.0 : 20.0,
        seed: 100 + i * 19,
        drawBranches: i == 0,
      );
    }
    if (t > 0.25) {
      final imp = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
      for (int s = 0; s < 5; s++) {
        final ang = (s / 5.0) * pi * 2 + t * 7.0;
        final sp = def + Offset(cos(ang) * (12 + imp * 28), sin(ang) * (10 + imp * 22));
        _drawStarburst(canvas, sp, 7 * fade, Colors.yellowAccent, Colors.white, fade, points: 4, rot: t * 9);
      }
    }
  }

  static void _paintElectroBall(
    Canvas canvas, Offset atk, Offset def, double t, double fade,
  ) {
    final travel = Curves.easeInOut.transform(min(1.0, t / 0.64));
    final pos = Offset.lerp(atk, def, travel)!;
    // Crackling plasma trail back toward attacker
    if (travel > 0.1) {
      drawArcLightning(
        canvas,
        Offset.lerp(atk, pos, 0.35)!,
        pos,
        t,
        fade * 0.7,
        strokeWidth: 2.5,
        segments: 5,
        jitter: 10.0,
        seed: 201,
        drawBranches: false,
        drawTerminals: false,
      );
    }
    canvas.drawCircle(pos, 26 * fade, Paint()..color = const Color(0xFFFFAB00).withOpacity(0.32 * fade));
    canvas.drawCircle(pos, 16 * fade, Paint()..color = Colors.yellowAccent.withOpacity(0.92 * fade));
    canvas.drawCircle(pos, 8 * fade, Paint()..color = Colors.white.withOpacity(fade));
    for (int s = 0; s < 5; s++) {
      final ang = (s / 5.0) * pi * 2 + t * 14.0;
      final p1 = pos + Offset(cos(ang) * 9, sin(ang) * 9);
      final p2 = pos + Offset(cos(ang + 0.35) * 32, sin(ang + 0.35) * 32);
      drawArcLightning(canvas, p1, p2, t, fade, strokeWidth: 2.2, segments: 4, jitter: 7.0, seed: 210 + s, drawBranches: false);
    }
    if (t > 0.58) {
      final imp = ((t - 0.58) / 0.42).clamp(0.0, 1.0);
      _drawStarburst(canvas, def, 18 + imp * 40, const Color(0xFFFFD600), Colors.white, fade, points: 8, rot: t * 8);
    }
  }

  static void _paintThunderbolt(
    Canvas canvas, Offset def, double t, double fade,
  ) {
    final impactFlash = sin(min(1.0, t * 1.4) * pi).clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(def.dx, 0),
      def,
      Paint()
        ..color = Colors.yellowAccent.withOpacity(0.24 * impactFlash * fade)
        ..strokeWidth = 44.0,
    );
    drawArcLightning(
      canvas,
      Offset(def.dx, 0),
      def,
      t,
      fade,
      strokeWidth: 6.0,
      segments: 10,
      jitter: 24.0,
      seed: 301,
      drawBranches: true,
    );
    for (final b in [-1, 1]) {
      drawArcLightning(
        canvas,
        Offset(def.dx + b * 24.0, 0),
        def + Offset(b * 10.0, 4.0),
        t,
        fade * 0.85,
        strokeWidth: 3.0,
        segments: 8,
        jitter: 18.0,
        seed: 305 + b,
        drawBranches: false,
      );
    }
    for (int r = 0; r < 2; r++) {
      final rt = ((t - r * 0.12) / 0.88).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: def + const Offset(0, 24),
          width: (32 + rt * 96) * fade,
          height: (12 + rt * 28) * fade,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (3.8 - r) * fade
          ..color = (r == 0 ? Colors.yellowAccent : Colors.white).withOpacity(0.85 * fade),
      );
    }
    for (int k = 0; k < 6; k++) {
      final ang = (k / 6.0) * pi * 2 + t * 8.0;
      final sp1 = def + Offset(cos(ang) * 14, sin(ang) * 10);
      final sp2 = def + Offset(cos(ang) * (24 + t * 38), sin(ang) * (18 + t * 26));
      drawArcLightning(canvas, sp1, sp2, t, fade * 0.85, strokeWidth: 2.0, segments: 4, jitter: 6.0, seed: 320 + k, drawBranches: false, drawTerminals: false);
    }
  }

  static void _paintThunder(
    Canvas canvas, Offset def, double t, double fade,
  ) {
    // Storm cloud glow overhead + colossal multi-fork sky strike
    final stormCenter = Offset(def.dx, max(18.0, def.dy - 145.0));
    canvas.drawOval(
      Rect.fromCenter(center: stormCenter, width: 128 * fade, height: 38 * fade),
      Paint()..color = const Color(0xFF37474F).withOpacity(0.75 * fade),
    );
    canvas.drawOval(
      Rect.fromCenter(center: stormCenter, width: 96 * fade, height: 24 * fade),
      Paint()..color = Colors.yellowAccent.withOpacity(0.28 * fade),
    );
    drawArcLightning(
      canvas,
      stormCenter,
      def,
      t,
      fade,
      strokeWidth: 8.2,
      segments: 11,
      jitter: 28.0,
      seed: 401,
      drawBranches: true,
    );
    for (final s in [-1, 1]) {
      drawArcLightning(
        canvas,
        stormCenter + Offset(s * 34.0, 6.0),
        def + Offset(s * 14.0, 6.0),
        t,
        fade,
        strokeWidth: 4.2,
        segments: 9,
        jitter: 22.0,
        seed: 410 + s,
        drawBranches: true,
      );
    }
    final imp = Curves.easeOut.transform(t);
    _drawStarburst(canvas, def, 24 + imp * 46, const Color(0xFFFFD600), Colors.white, fade, points: 10, rot: t * 10);
    canvas.drawOval(
      Rect.fromCenter(center: def + const Offset(0, 26), width: 136 * imp, height: 42 * imp),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5 * fade
        ..color = Colors.yellowAccent.withOpacity(fade),
    );
  }

  static void _paintThunderWave(
    Canvas canvas, Offset atk, Offset def, double t, double fade,
  ) {
    // Arcing electric tether + pulsing concentric shock rings around defender
    if (t < 0.55) {
      final reach = min(1.0, t / 0.35);
      drawArcLightning(
        canvas,
        atk,
        Offset.lerp(atk, def, reach)!,
        t,
        fade,
        strokeWidth: 3.0,
        segments: 7,
        jitter: 14.0,
        seed: 501,
        drawBranches: false,
      );
    }
    for (int i = 0; i < 3; i++) {
      final rad = 16 + i * 13 + sin(t * pi) * 14;
      canvas.drawOval(
        Rect.fromCenter(center: def, width: rad * 2.2, height: rad * 1.45),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * fade
          ..color = (i.isEven ? Colors.yellowAccent : Colors.lightBlueAccent).withOpacity(0.88 * fade),
      );
    }
    for (int z = 0; z < 6; z++) {
      final a1 = (z / 6.0) * pi * 2 + t * 5.0;
      final a2 = a1 + 0.55;
      final p1 = def + Offset(cos(a1) * 24, sin(a1) * 18);
      final p2 = def + Offset(cos(a2) * 34, sin(a2) * 25);
      drawArcLightning(canvas, p1, p2, t, fade, strokeWidth: 2.5, segments: 4, jitter: 7.0, seed: 520 + z, drawBranches: false, drawTerminals: false);
    }
  }

  static void _paintShockWave(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
  ) {
    for (int i = 0; i < 3; i++) {
      final lt = ((t - i * 0.1) / 0.6).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final pos = Offset.lerp(atk, def, lt)!;
      canvas.drawCircle(
        pos,
        (13 + i * 3.5) * fade,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4 * fade
          ..color = Colors.yellowAccent.withOpacity(fade),
      );
      drawArcLightning(
        canvas,
        pos - perp * 16,
        pos + perp * 16,
        t,
        fade,
        strokeWidth: 2.8,
        segments: 5,
        jitter: 9.0,
        seed: 600 + i,
        drawBranches: false,
        drawTerminals: false,
      );
    }
    if (t > 0.42) {
      final imp = ((t - 0.42) / 0.58).clamp(0.0, 1.0);
      _drawStarburst(canvas, def, 14 + imp * 30, Colors.yellowAccent, Colors.white, fade, points: 7, rot: t * 8);
    }
  }

  static void _paintDischarge(
    Canvas canvas, Offset atk, Offset def, double t, double fade,
  ) {
    final expand = Curves.easeOut.transform(t);
    canvas.drawCircle(
      atk,
      (20 + expand * 54) * fade,
      Paint()..color = Colors.yellowAccent.withOpacity(0.22 * (1.0 - t * 0.5) * fade),
    );
    for (int i = 0; i < 8; i++) {
      final ang = (i / 8.0) * pi * 2 + t * 1.4;
      final rad = 24 + expand * 68;
      final endPt = atk + Offset(cos(ang) * rad, sin(ang) * rad);
      drawArcLightning(canvas, atk, endPt, t, fade, strokeWidth: 3.4, segments: 6, jitter: 12.0, seed: 700 + i, drawBranches: i.isEven);
    }
    // Primary bolt locking onto defender as well
    if (atk != def) {
      drawArcLightning(canvas, atk, def, t, fade, strokeWidth: 4.4, segments: 8, jitter: 16.0, seed: 750, drawBranches: true);
    }
  }

  static void _paintZapCannon(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
  ) {
    final fly = Curves.easeInOut.transform(min(1.0, t / 0.62));
    final pos = Offset.lerp(atk, def, fly)!;
    // Trailing magnetic plasma tether
    drawArcLightning(canvas, atk, pos, t, fade, strokeWidth: 4.5, segments: 8, jitter: 14.0, seed: 801, drawBranches: true);
    // Heavy charged cannonball with orbiting arcs
    canvas.drawCircle(pos, 32 * fade, Paint()..color = const Color(0xFFFFD600).withOpacity(0.32 * fade));
    canvas.drawCircle(pos, 20 * fade, Paint()..color = Colors.yellowAccent.withOpacity(0.95 * fade));
    canvas.drawCircle(pos, 10 * fade, Paint()..color = Colors.white.withOpacity(fade));
    for (int i = 0; i < 6; i++) {
      final a1 = (i / 6.0) * pi * 2 + t * 12.0;
      final a2 = a1 + 0.9;
      drawArcLightning(
        canvas,
        pos + Offset(cos(a1) * 18, sin(a1) * 18),
        pos + Offset(cos(a2) * 26, sin(a2) * 26),
        t, fade, strokeWidth: 2.2, segments: 4, jitter: 6.0, seed: 810 + i, drawBranches: false, drawTerminals: false,
      );
    }
    if (t > 0.56) {
      final imp = ((t - 0.56) / 0.44).clamp(0.0, 1.0);
      _drawStarburst(canvas, def, 24 + imp * 52, const Color(0xFFFFAB00), Colors.white, fade, points: 10, rot: t * 7);
    }
  }

  static void _paintChargeBeam(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
  ) {
    if (t < 0.25) {
      final ct = t / 0.25;
      canvas.drawCircle(atk, (8 + ct * 12) * fade, Paint()..color = Colors.yellowAccent.withOpacity(fade));
      for (int i = 0; i < 4; i++) {
        final ang = (i / 4.0) * pi * 2 + t * 14.0;
        drawArcLightning(
          canvas,
          atk + Offset(cos(ang) * (1.0 - ct) * 32, sin(ang) * (1.0 - ct) * 32),
          atk,
          t, fade, strokeWidth: 2.2, segments: 4, jitter: 6.0, seed: 860 + i, drawBranches: false, drawTerminals: false,
        );
      }
    } else {
      final bt = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
      final reach = min(1.0, bt * 2.2);
      final tip = Offset.lerp(atk, def, reach)!;
      _drawEnergyBeam(canvas, atk, tip, 14 * fade, Colors.amberAccent, Colors.white, fade);
      drawArcLightning(canvas, atk, tip, t, fade, strokeWidth: 3.4, segments: 8, jitter: 11.0, seed: 870, drawBranches: false);
      drawArcLightning(canvas, atk, tip, t, fade * 0.85, strokeWidth: 2.4, segments: 7, jitter: 16.0, seed: 871, drawBranches: false);
    }
  }

  static void _paintSparkDash(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
  ) {
    final dashT = Curves.easeInOut.transform(min(1.0, t / 0.58));
    final pos = Offset.lerp(atk, def, dashT)!;
    // Electrified speed trail
    for (int i = -1; i <= 1; i++) {
      final off = perp * (i * 11.0);
      drawArcLightning(
        canvas,
        atk + off * 0.5,
        pos + off * 0.4,
        t, fade * 0.9, strokeWidth: 3.0, segments: 6, jitter: 11.0, seed: 900 + i, drawBranches: i == 0, drawTerminals: false,
      );
    }
    _drawStarburst(canvas, pos, 18 * fade, Colors.yellowAccent, Colors.white, fade, points: 6, rot: t * 14);
    if (t > 0.52) {
      final imp = ((t - 0.52) / 0.48).clamp(0.0, 1.0);
      for (int s = 0; s < 6; s++) {
        final ang = (s / 6.0) * pi * 2 + t * 5.0;
        drawArcLightning(
          canvas,
          def,
          def + Offset(cos(ang) * (16 + imp * 34), sin(ang) * (12 + imp * 26)),
          t, fade, strokeWidth: 2.2, segments: 4, jitter: 7.0, seed: 910 + s, drawBranches: false, drawTerminals: false,
        );
      }
    }
  }

  static void _paintElectricCharge(
    Canvas canvas, Offset atk, double t, double fade,
  ) {
    final pulse = sin(t * pi).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(center: atk + const Offset(0, 26), width: 100 * fade, height: 30 * fade),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * fade
        ..color = Colors.yellowAccent.withOpacity(0.75 * fade),
    );
    canvas.drawCircle(atk, (26 + pulse * 18) * fade, Paint()..color = const Color(0xFFFFD600).withOpacity(0.24 * fade));
    for (int i = 0; i < 6; i++) {
      final ang = (i / 6.0) * pi * 2 + t * 8.0;
      final r1 = Offset(cos(ang) * 32, sin(ang) * 20 + 20 * (1.0 - t));
      final r2 = Offset(cos(ang + 0.4) * 20, sin(ang + 0.4) * 14 - 28 * t);
      drawArcLightning(canvas, atk + r1, atk + r2, t, fade, strokeWidth: 2.6, segments: 5, jitter: 8.0, seed: 940 + i, drawBranches: false, drawTerminals: false);
    }
  }

  static void _paintMagnetRise(
    Canvas canvas, Offset atk, double t, double fade,
  ) {
    final lift = sin(t * pi) * 14.0;
    for (int ring = 0; ring < 3; ring++) {
      final ry = atk.dy + 22 - ring * 18 - lift;
      final w = (74.0 - ring * 12.0) * fade;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(atk.dx, ry), width: w, height: w * 0.28),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.8 * fade
          ..color = (ring.isEven ? Colors.cyanAccent : Colors.yellowAccent).withOpacity(0.85 * fade),
      );
    }
    for (int i = 0; i < 4; i++) {
      final ang = (i / 4.0) * pi * 2 + t * 7.0;
      drawArcLightning(
        canvas,
        atk + Offset(cos(ang) * 34, sin(ang) * 16 + 16),
        atk + Offset(cos(ang + 0.5) * 34, sin(ang + 0.5) * 16 - 16 - lift),
        t, fade, strokeWidth: 2.2, segments: 4, jitter: 6.0, seed: 970 + i,
        outerColor: Colors.cyanAccent, midColor: Colors.yellowAccent, drawBranches: false, drawTerminals: false,
      );
    }
  }

  // ─── ELEMENTAL PUNCHES, FANGS, KICKS & CHARGES ───────────────────────────

  static void _paintElementalPunch(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp, {
    required Color outer, required Color inner, required String flavor,
  }) {
    final slam = Curves.easeOutBack.transform(min(1.0, t * 2.0));
    final punchPos = Offset.lerp(def - unit * 42.0, def, slam)!;
    // Speed lines behind fist
    _drawSpeedLines(canvas, def - unit * 64.0, unit, perp, 48.0, outer, fade);
    // Glowing gauntlet silhouette
    canvas.drawCircle(punchPos, 24 * fade, Paint()..color = outer.withOpacity(0.45 * fade));
    canvas.drawCircle(punchPos, 16 * fade, Paint()..color = outer.withOpacity(0.95 * fade));
    canvas.drawCircle(punchPos - unit * 3, 8 * fade, Paint()..color = inner.withOpacity(fade));
    if (flavor == 'electric') {
      for (int i = 0; i < 4; i++) {
        final a = (i / 4.0) * pi * 2 + t * 10;
        drawArcLightning(
          canvas, punchPos, punchPos + Offset(cos(a) * 34, sin(a) * 34),
          t, fade, strokeWidth: 2.8, segments: 5, jitter: 9.0, seed: 1010 + i, drawBranches: false,
        );
      }
    } else if (flavor == 'fire') {
      for (int i = 0; i < 6; i++) {
        final a = (i / 6.0) * pi * 2 + t * 7;
        _drawFlameWisp(canvas, def + Offset(cos(a) * (12 + t * 26), sin(a) * (12 + t * 26)), 10 * fade, outer, inner, fade);
      }
    } else if (flavor == 'ice') {
      for (int i = 0; i < 6; i++) {
        final a = (i / 6.0) * pi * 2 + t * 4;
        _drawIcicle(canvas, def + Offset(cos(a) * (14 + t * 24), sin(a) * (14 + t * 24)), a, 12 * fade, outer, inner, fade);
      }
    }
    if (t > 0.35) {
      final imp = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
      _drawStarburst(canvas, def, 14 + imp * 34, outer, inner, fade, points: 7, rot: t * 6);
    }
  }

  static void _paintElementalFang(
    Canvas canvas, Offset center, double t, double fade, {
    required Color toothColor, required Color glowColor, required String flavor, bool heavy = false,
  }) {
    final clampT = sin(min(1.0, t * 1.6) * pi * 0.5);
    final gap = (1.0 - clampT) * 26.0;
    final fangCount = heavy ? 3 : 2;
    final fangScale = heavy ? 1.25 : 1.0;

    // Aura backdrop
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 66 * fangScale * fade, height: 52 * fangScale * fade),
      Paint()..color = glowColor.withOpacity(0.24 * fade),
    );
    for (int i = -fangCount; i <= fangCount; i++) {
      if (i == 0 && !heavy) continue;
      final dx = i * 12.0 * fangScale;
      final h = (i.abs() == 1 ? 18.0 : 13.0) * fangScale;
      final topTooth = Path()
        ..moveTo(center.dx + dx - 6 * fangScale, center.dy - 18 - gap)
        ..lineTo(center.dx + dx + 6 * fangScale, center.dy - 18 - gap)
        ..lineTo(center.dx + dx, center.dy - 18 + h - gap)
        ..close();
      final botTooth = Path()
        ..moveTo(center.dx + dx - 6 * fangScale, center.dy + 18 + gap)
        ..lineTo(center.dx + dx + 6 * fangScale, center.dy + 18 + gap)
        ..lineTo(center.dx + dx, center.dy + 18 - h + gap)
        ..close();
      final fill = Paint()..color = toothColor.withOpacity(0.95 * fade);
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withOpacity(0.85 * fade);
      canvas.drawPath(topTooth, fill);
      canvas.drawPath(topTooth, edge);
      canvas.drawPath(botTooth, fill);
      canvas.drawPath(botTooth, edge);
    }
    if (t > 0.4) {
      final imp = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
      if (flavor == 'electric') {
        for (int k = 0; k < 4; k++) {
          final a = (k / 4.0) * pi * 2 + t * 8;
          drawArcLightning(canvas, center, center + Offset(cos(a) * 34, sin(a) * 28), t, fade, strokeWidth: 2.6, segments: 5, jitter: 8.0, seed: 1050 + k, drawBranches: false);
        }
      } else if (flavor == 'fire') {
        for (int k = 0; k < 6; k++) {
          final a = (k / 6.0) * pi * 2 + t * 6;
          _drawFlameWisp(canvas, center + Offset(cos(a) * (10 + imp * 26), sin(a) * (8 + imp * 20)), 8 * fade, toothColor, glowColor, fade);
        }
      } else if (flavor == 'ice') {
        for (int k = 0; k < 6; k++) {
          final a = (k / 6.0) * pi * 2 + t * 5;
          _drawIcicle(canvas, center + Offset(cos(a) * (12 + imp * 24), sin(a) * (12 + imp * 24)), a, 10 * fade, toothColor, glowColor, fade);
        }
      } else {
        _drawStarburst(canvas, center, 14 + imp * 26, glowColor, Colors.white, fade, points: 6, rot: t * 5);
      }
    }
  }

  static void _paintHeavyStrikeMove(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp, {
    required String moveId, required PokemonType moveType,
  }) {
    final c = moveType.color;
    final slam = Curves.easeOutBack.transform(min(1.0, t * 2.2));
    final fist = Offset.lerp(def - unit * 48, def, slam)!;
    _drawSpeedLines(canvas, def - unit * 68, unit, perp, 54.0, c, fade);
    if (moveId == 'arm_thrust' || moveId == 'mach_punch' || moveId == 'bullet_punch') {
      for (int k = -1; k <= 1; k++) {
        final p = Offset.lerp(def - unit * 46 + perp * (k * 16), def + perp * (k * 10), min(1.0, t * 2.5 - (k + 1) * 0.1).clamp(0.0, 1.0))!;
        canvas.drawCircle(p, 11 * fade, Paint()..color = c.withOpacity(0.9 * fade));
        canvas.drawCircle(p, 5 * fade, Paint()..color = Colors.white.withOpacity(fade));
      }
    } else {
      canvas.drawCircle(fist, 22 * fade, Paint()..color = c.withOpacity(0.4 * fade));
      canvas.drawCircle(fist, 14 * fade, Paint()..color = c.withOpacity(0.95 * fade));
      canvas.drawCircle(fist, 7 * fade, Paint()..color = Colors.white.withOpacity(fade));
    }
    if (moveId == 'dizzy_punch') {
      for (int b = 0; b < 3; b++) {
        final ang = b * (pi * 2 / 3) + t * 11;
        final sp = def + Offset(cos(ang) * 26, -24 + sin(ang) * 10);
        _drawStarburst(canvas, sp, 8 * fade, Colors.amberAccent, Colors.white, fade, points: 5, rot: t * 8);
      }
    } else if (t > 0.35) {
      final imp = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
      _drawStarburst(canvas, def, 18 + imp * 38, c, Colors.white, fade, points: 8, rot: t * 7);
    }
  }

  static void _paintKickCombo(
    Canvas canvas, Offset def, double t, double fade, Offset unit, Offset perp, {
    required Color color, bool isFire = false, bool isSweep = false,
  }) {
    final sweep = min(1.0, t * 1.9);
    if (isSweep) {
      _drawSlashArc(canvas, def + const Offset(0, 18), 44, -pi * 0.15, pi * 0.85, sweep, color, Colors.white, fade, stroke: 7.0);
    } else {
      _drawSlashArc(canvas, def, 46, -pi * 0.75, pi * 1.1, sweep, color, Colors.white, fade, stroke: 8.5);
    }
    if (isFire) {
      for (int i = 0; i < 6; i++) {
        final a = -pi * 0.75 + (i / 5.0) * pi * sweep;
        _drawFlameWisp(canvas, def + Offset(cos(a) * 34, sin(a) * 34), 9 * fade, Colors.deepOrangeAccent, Colors.yellowAccent, fade);
      }
    }
    if (t > 0.4) {
      final imp = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
      _drawStarburst(canvas, def, 14 + imp * 34, color, Colors.white, fade, points: 7, rot: t * 6);
    }
  }

  static void _paintHeavyChargeImpact(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp, {
    required String moveId, required PokemonType moveType,
  }) {
    final c = moveType.color;
    final rush = Curves.easeInCubic.transform(min(1.0, t / 0.5));
    final head = Offset.lerp(atk, def, rush)!;
    // Motion streak cone
    final tail = Offset.lerp(atk, head, 0.3)!;
    canvas.drawLine(
      tail, head,
      Paint()
        ..color = c.withOpacity(0.55 * fade)
        ..strokeWidth = 22 * fade
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      tail, head,
      Paint()
        ..color = Colors.white.withOpacity(0.85 * fade)
        ..strokeWidth = 8 * fade
        ..strokeCap = StrokeCap.round,
    );
    _drawSpeedLines(canvas, head - unit * 24, unit, perp, 48, c, fade);
    if (t > 0.42) {
      final imp = ((t - 0.42) / 0.58).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(center: def + const Offset(0, 22), width: (30 + imp * 88) * fade, height: (14 + imp * 30) * fade),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0 * fade
          ..color = c.withOpacity(0.9 * fade),
      );
      _drawStarburst(canvas, def, 18 + imp * 42, c, Colors.white, fade, points: 9, rot: t * 6);
    }
  }

  static void _paintBindingVinesOrCoils(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp, {
    required PokemonType moveType, bool isWhip = false,
  }) {
    final c = moveType.color;
    if (isWhip) {
      final whipT = min(1.0, t * 1.8);
      final end = Offset.lerp(atk, def, whipT)!;
      final p = Path()
        ..moveTo(atk.dx, atk.dy)
        ..quadraticBezierTo((atk.dx + end.dx) * 0.5 + perp.dx * 36, (atk.dy + end.dy) * 0.5 + perp.dy * 36, end.dx, end.dy);
      canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 7 * fade..color = c.withOpacity(fade)..strokeCap = StrokeCap.round);
      canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.6 * fade..color = Colors.lightGreenAccent.withOpacity(fade)..strokeCap = StrokeCap.round);
      if (t > 0.45) {
        _drawStarburst(canvas, def, 24 * fade, c, Colors.white, fade, points: 6, rot: t * 5);
      }
      return;
    }
    final squeeze = 1.0 - sin(t * pi) * 0.35;
    for (int i = 0; i < 4; i++) {
      final yOff = -22.0 + i * 14.0;
      canvas.drawOval(
        Rect.fromCenter(center: def + Offset(0, yOff), width: 60 * squeeze, height: 15),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0 * fade
          ..color = c.withOpacity(0.9 * fade),
      );
      canvas.drawOval(
        Rect.fromCenter(center: def + Offset(0, yOff), width: 60 * squeeze, height: 15),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8 * fade
          ..color = Colors.white.withOpacity(0.65 * fade),
      );
    }
  }

  static void _paintSoundWaveMove(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp, {
    required String moveId, required PokemonType moveType,
  }) {
    final c = moveId == 'snore' || moveId == 'sleep_talk'
        ? const Color(0xFFB388FF)
        : (moveId == 'bug_buzz' ? const Color(0xFF9CCC65) : moveType.color);
    final bool centeredOnAtk = moveId == 'perish_song' || moveId == 'sleep_talk' || moveId == 'uproar';
    final emitOrigin = centeredOnAtk ? atk : atk;
    final target = centeredOnAtk && moveId == 'sleep_talk' ? atk : def;

    for (int i = 0; i < 4; i++) {
      final lt = ((t - i * 0.14) / 0.72).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final pos = Offset.lerp(emitOrigin, target, lt)!;
      final radius = 14.0 + lt * 34.0;
      final angle = atan2(unit.dy, unit.dx);
      canvas.drawArc(
        Rect.fromCircle(center: pos, radius: radius),
        angle - 0.85,
        1.7,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (4.8 - i * 0.6) * fade
          ..strokeCap = StrokeCap.round
          ..color = (i.isEven ? c : Colors.white).withOpacity((1.0 - lt * 0.3) * fade),
      );
    }
    if (moveId == 'snore' || moveId == 'sleep_talk') {
      for (int z = 0; z < 3; z++) {
        final zt = ((t - z * 0.16) / 0.78).clamp(0.0, 1.0);
        if (zt <= 0) continue;
        final zp = atk + Offset(12.0 + z * 12.0, -18.0 - zt * 36.0);
        _drawZzz(canvas, zp, 7.0 + z * 2.5, Colors.white.withOpacity((1.0 - zt * 0.35) * fade));
      }
    }
    if (moveId == 'perish_song') {
      canvas.drawCircle(
        atk, (26 + t * 54) * fade,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 3.2 * fade..color = const Color(0xFF9575CD).withOpacity(0.75 * fade),
      );
    }
  }

  static void _paintIceMove(
    Canvas canvas, Size size, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp, {
    required String moveId,
  }) {
    if (moveId == 'hail') {
      for (int i = 0; i < 12; i++) {
        final lt = (t * 1.4 + i * 0.13) % 1.0;
        final x = (size.width * ((i * 73 % 100) / 100.0)) + (lt - 0.5) * 40;
        final y = lt * size.height * 0.9;
        _drawIcicle(canvas, Offset(x, y), pi * 0.6, 11 * fade, Colors.lightBlueAccent, Colors.white, fade);
      }
      return;
    }
    if (moveId == 'mist' || moveId == 'haze') {
      final center = moveId == 'mist' ? atk : def;
      for (int i = 0; i < 7; i++) {
        final ang = (i / 7.0) * pi * 2 + t * 2.4;
        final pos = center + Offset(cos(ang) * (24 + t * 26), sin(ang) * (12 + t * 14) - t * 14);
        canvas.drawOval(
          Rect.fromCenter(center: pos, width: 42 * fade, height: 22 * fade),
          Paint()..color = (moveId == 'mist' ? Colors.white : const Color(0xFFB0BEC5)).withOpacity(0.45 * fade),
        );
      }
      return;
    }
    if (moveId == 'sheer_cold') {
      canvas.drawCircle(def, 44 * sin(t * pi).clamp(0.0, 1.0) * fade,
          Paint()..color = Colors.cyanAccent.withOpacity(0.32 * fade));
      for (int k = 0; k < 6; k++) {
        final ang = (k / 6.0) * pi * 2 + t * 4;
        final p = def + Offset(cos(ang) * (10 + t * 34), sin(ang) * (10 + t * 34));
        _drawIcicle(canvas, p, ang, 16 * fade, Colors.cyanAccent, Colors.white, fade);
      }
      return;
    }
    if (moveId == 'icicle_crash') {
      for (int i = -1; i <= 1; i++) {
        final drop = Curves.easeIn.transform(((t - (i + 1) * 0.1) / 0.65).clamp(0.0, 1.0));
        final p = Offset.lerp(def + Offset(i * 22.0, -110.0), def + Offset(i * 18.0, 8.0), drop)!;
        _drawIcicle(canvas, p, pi * 0.5, 22 * fade, Colors.lightBlueAccent, Colors.white, fade);
      }
      if (t > 0.5) {
        _drawStarburst(canvas, def, 34 * fade, Colors.cyanAccent, Colors.white, fade, points: 6, rot: t * 5);
      }
      return;
    }
    // ice_shard, icicle_spear, icy_wind, powder_snow
    final count = moveId == 'ice_shard' ? 3 : 8;
    final angle = atan2(unit.dy, unit.dx);
    for (int i = 0; i < count; i++) {
      final lt = ((t - i * 0.06) / 0.58).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final spread = moveId == 'icy_wind' ? sin(lt * 10 + i) * 24.0 : (i - count * 0.5) * 5.0;
      final pos = Offset.lerp(atk, def, lt)! + perp * spread;
      _drawIcicle(canvas, pos, angle, (moveId == 'icicle_spear' ? 15.0 : 11.0) * fade, Colors.cyanAccent, Colors.white, fade);
    }
  }

  // ─── THEMED RENDERERS FOR PREVIOUSLY UNMAPPED MOVES ──────────────────────

  static void _paintWeatherMove(
    Canvas canvas, Size size, Offset atk, Offset def, double t, double fade, String moveId,
  ) {
    if (moveId == 'sunny_day') {
      final sunCenter = Offset(size.width * 0.5, size.height * 0.16);
      canvas.drawCircle(sunCenter, (34 + sin(t * pi) * 14) * fade, Paint()..color = Colors.amberAccent.withOpacity(0.35 * fade));
      canvas.drawCircle(sunCenter, 20 * fade, Paint()..color = Colors.yellowAccent.withOpacity(fade));
      for (int i = 0; i < 8; i++) {
        final ang = (i / 8.0) * pi * 2 + t * 2.5;
        canvas.drawLine(
          sunCenter + Offset(cos(ang) * 24, sin(ang) * 24),
          sunCenter + Offset(cos(ang) * (46 + t * 22), sin(ang) * (46 + t * 22)),
          Paint()..color = Colors.orangeAccent.withOpacity(0.85 * fade)..strokeWidth = 3.5 * fade..strokeCap = StrokeCap.round,
        );
      }
    } else if (moveId == 'rain_dance') {
      for (int i = 0; i < 16; i++) {
        final lt = (t * 1.5 + i * 0.11) % 1.0;
        final x = size.width * ((i * 61 % 100) / 100.0) - lt * 24;
        final y = lt * size.height * 0.92;
        canvas.drawLine(
          Offset(x, y),
          Offset(x - 8, y + 18),
          Paint()..color = Colors.lightBlueAccent.withOpacity(0.85 * fade)..strokeWidth = 2.6 * fade..strokeCap = StrokeCap.round,
        );
      }
    } else {
      // sandstorm
      for (int i = 0; i < 14; i++) {
        final lt = (t * 1.4 + i * 0.09) % 1.0;
        final y = size.height * (0.2 + (i % 7) * 0.11);
        final x = lt * size.width;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 22 * fade, height: 7 * fade),
          Paint()..color = const Color(0xFFD7CCC8).withOpacity(0.65 * fade),
        );
      }
    }
  }

  static void _paintShieldBarrier(
    Canvas canvas, Offset atk, Offset def, double t, double fade, String moveId, PokemonType moveType,
  ) {
    final center = (moveId == 'counter' || moveId == 'mirror_coat') && t > 0.45 ? def : atk;
    final c = moveId == 'magic_coat'
        ? const Color(0xFFE040FB)
        : (moveId == 'counter'
            ? const Color(0xFFFF7043)
            : (moveId == 'mirror_coat' ? Colors.cyanAccent : moveType.color));
    _drawShieldHex(canvas, atk, 34 + sin(t * pi) * 10, c, Colors.white, fade, t);
    if ((moveId == 'counter' || moveId == 'mirror_coat') && t > 0.35) {
      final beamT = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
      _drawEnergyBeam(canvas, atk, Offset.lerp(atk, center, beamT)!, 11 * fade, c, Colors.white, fade);
    }
  }

  static void _paintEntryHazard(
    Canvas canvas, Offset def, double t, double fade, String moveId,
  ) {
    final floorY = def.dy + 26;
    if (moveId == 'stealth_rock') {
      for (int i = 0; i < 5; i++) {
        final ang = (i / 5.0) * pi * 2 + t * 3.5;
        final p = def + Offset(cos(ang) * 34, sin(ang) * 18 - 6);
        _drawRockSpire(canvas, p, 10 * fade, const Color(0xFF8D7B68), fade);
      }
    } else {
      final c = moveId == 'toxic_spikes' ? Colors.purpleAccent : const Color(0xFFA1887F);
      for (int i = -2; i <= 2; i++) {
        final drop = Curves.bounceOut.transform(min(1.0, t * 1.6));
        final p = Offset(def.dx + i * 16.0, floorY - (1.0 - drop) * 36.0);
        _drawRockSpire(canvas, p, 8 * fade, c, fade);
      }
    }
  }

  static void _paintElementalSlash(
    Canvas canvas, Offset def, double t, double fade, PokemonType moveType, String moveId,
  ) {
    final c = moveType.color;
    final p1 = min(1.0, t * 2.1);
    final p2 = ((t - 0.16) * 2.1).clamp(0.0, 1.0);
    _drawSlashArc(canvas, def, 46, -pi * 0.8, pi * 0.9, p1, c, Colors.white, fade, stroke: 7.5);
    if (moveId != 'iron_tail' && moveId != 'dragon_tail' && moveId != 'false_swipe') {
      _drawSlashArc(canvas, def, 42, pi * 0.2, -pi * 0.9, p2, c, Colors.white, fade, stroke: 6.5);
    }
    if (t > 0.45) {
      _drawStarburst(canvas, def, 24 * fade, c, Colors.white, fade, points: 4, rot: t * 6);
    }
  }

  static void _paintElementalBeam(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
    PokemonType moveType, String moveId,
  ) {
    final c = moveType.color;
    final reach = min(1.0, t * 2.1);
    final tip = Offset.lerp(atk, def, reach)!;
    if (moveId == 'aura_sphere' || moveId == 'dragon_pulse' || moveId == 'dark_pulse') {
      final fly = Curves.easeOutCubic.transform(min(1.0, t / 0.65));
      final pos = Offset.lerp(atk, def, fly)!;
      _drawGlowOrb(canvas, pos, (moveId == 'aura_sphere' ? 16.0 : 18.0) * fade, c, Colors.white, fade);
      for (int r = 0; r < 3; r++) {
        final rt = ((t - r * 0.14) / 0.72).clamp(0.0, 1.0);
        if (rt <= 0) continue;
        canvas.drawCircle(
          moveId == 'dark_pulse' ? Offset.lerp(atk, def, rt)! : def,
          (12 + rt * 32) * fade,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * fade
            ..color = c.withOpacity((1.0 - rt * 0.4) * fade),
        );
      }
      return;
    }
    _drawEnergyBeam(canvas, atk, tip, 16 * fade, c, Colors.white, fade);
    // Helical pulse along beam
    final wavePath = Path()..moveTo(atk.dx, atk.dy);
    for (int i = 1; i <= 14; i++) {
      final frac = i / 14.0;
      if (frac > reach) break;
      final pt = Offset.lerp(atk, def, frac)! + perp * (sin(frac * pi * 6 - t * 18) * 11 * fade);
      wavePath.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(wavePath, Paint()..style = PaintingStyle.stroke..strokeWidth = 3 * fade..color = Colors.white.withOpacity(0.85 * fade));
    if (t > 0.45) {
      _drawStarburst(canvas, def, 30 * fade, c, Colors.white, fade, points: 8, rot: t * 6);
    }
  }

  static void _paintElementalOrbOrWave(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
    PokemonType moveType, String moveId,
  ) {
    final c = moveType.color;
    final count = (moveId == 'bullet_seed' || moveId == 'barrage' || moveId == 'rock_blast') ? 5 : 1;
    for (int i = 0; i < count; i++) {
      final lt = ((t - i * 0.1) / 0.56).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final pos = Offset.lerp(atk, def, lt)! + (count > 1 ? perp * ((i - 2) * 5.0) : Offset.zero);
      _drawGlowOrb(canvas, pos, (count > 1 ? 8.5 : 15.0) * fade, c, Colors.white, fade);
    }
    if (t > 0.48) {
      final imp = ((t - 0.48) / 0.52).clamp(0.0, 1.0);
      _drawStarburst(canvas, def, (16 + imp * 36) * fade, c, Colors.white, fade, points: 8, rot: t * 8);
    }
  }

  static void _paintEarthRockMove(
    Canvas canvas, Size size, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
    PokemonType moveType, String moveId,
  ) {
    final c = moveType.color;
    if (moveId == 'rock_polish' || moveId == 'iron_defense' || moveId == 'mud_sport') {
      _drawAuraRings(canvas, atk, t, fade, c, ascending: true);
      return;
    }
    final imp = sin(min(1.0, t * 1.4) * pi).clamp(0.0, 1.0);
    for (int i = -2; i <= 2; i++) {
      final h = (32.0 - i.abs() * 6.0) * imp * fade;
      final p = Offset(def.dx + i * 14.0, def.dy + 26.0);
      _drawRockSpire(canvas, p, max(8.0, h), c, fade);
    }
    canvas.drawOval(
      Rect.fromCenter(center: def + const Offset(0, 24), width: (36 + t * 82) * fade, height: (14 + t * 26) * fade),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5 * fade..color = c.withOpacity(0.9 * fade),
    );
  }

  static void _paintGrassMove(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp, String moveId,
  ) {
    final bool isSelf = moveId == 'synthesis' || moveId == 'ingrain' || moveId == 'aromatherapy';
    final bool isPowder = moveId == 'stun_spore' || moveId == 'rage_powder' || moveId == 'worry_seed' || moveId == 'sweet_scent';
    final target = isSelf ? atk : def;
    if (isSelf) {
      _drawAuraRings(canvas, atk, t, fade, Colors.lightGreenAccent, ascending: true);
      return;
    }
    if (isPowder) {
      for (int i = 0; i < 12; i++) {
        final a = (i / 12.0) * pi * 2 + t * 5;
        final r = 14 + sin(t * pi) * 32;
        canvas.drawCircle(
          target + Offset(cos(a) * r, sin(a) * r * 0.7 - t * 18),
          (i.isEven ? 4.5 : 3.2) * fade,
          Paint()..color = (moveId == 'stun_spore' ? Colors.amberAccent : Colors.lightGreenAccent).withOpacity(0.85 * fade),
        );
      }
      return;
    }
    // Razor/petal/leaf tornado & storm
    final angle = atan2(unit.dy, unit.dx);
    for (int i = 0; i < 10; i++) {
      final lt = ((t - i * 0.05) / 0.62).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final swirl = sin(lt * 12 + i) * 20.0;
      final p = Offset.lerp(atk, def, lt)! + perp * swirl;
      _drawPetalOrLeaf(canvas, p, angle + t * 6 + i, 9 * fade, moveId == 'petal_dance' ? Colors.pinkAccent : Colors.lightGreenAccent, fade);
    }
  }

  static void _paintFireSpecialMove(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp, String moveId,
  ) {
    final origin = (moveId == 'eruption' || moveId == 'lava_plume') ? atk : def;
    if (moveId == 'will_o_wisp') {
      for (int i = 0; i < 4; i++) {
        final ang = (i / 4.0) * pi * 2 + t * 9.0;
        final pos = Offset.lerp(atk, def, min(1.0, t * 1.4))! + Offset(cos(ang) * 24, sin(ang) * 18);
        _drawFlameWisp(canvas, pos, 9 * fade, const Color(0xFF7C4DFF), Colors.cyanAccent, fade);
      }
      return;
    }
    if (moveId == 'flame_charge') {
      _paintHeavyChargeImpact(canvas, atk, def, t, fade, unit, perp, moveId: moveId, moveType: PokemonType.fire);
      return;
    }
    for (int i = 0; i < 10; i++) {
      final a = (i / 10.0) * pi * 2 + t * 5;
      final r = 12 + Curves.easeOut.transform(t) * 44;
      _drawFlameWisp(canvas, origin + Offset(cos(a) * r, sin(a) * r * 0.78), 11 * fade, Colors.deepOrangeAccent, Colors.yellowAccent, fade);
    }
    if (atk != def && moveId != 'lava_plume') {
      _drawEnergyBeam(canvas, atk, Offset.lerp(atk, def, min(1.0, t * 1.9))!, 14 * fade, Colors.deepOrange, Colors.yellowAccent, fade);
    }
  }

  static void _paintWaterSpecialMove(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp, String moveId,
  ) {
    if (moveId == 'aqua_ring' || moveId == 'water_sport') {
      _drawAuraRings(canvas, atk, t, fade, Colors.cyanAccent, ascending: true);
      return;
    }
    if (moveId == 'whirlpool') {
      for (int i = 0; i < 4; i++) {
        final r = 14 + i * 11.0;
        canvas.drawOval(
          Rect.fromCenter(center: def + Offset(sin(t * 14 + i) * 6, 18 - i * 10.0), width: r * 2.1 * fade, height: r * 0.65 * fade),
          Paint()..style = PaintingStyle.stroke..strokeWidth = 3.2 * fade..color = (i.isEven ? Colors.cyanAccent : Colors.white).withOpacity(fade),
        );
      }
      return;
    }
    for (int i = 0; i < 9; i++) {
      final lt = ((t - i * 0.06) / 0.58).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      final pos = Offset.lerp(atk, def, lt)! + perp * (sin(lt * 10 + i) * 14.0);
      _drawGlowOrb(canvas, pos, (6.0 + (i % 3) * 2.5) * fade, const Color(0xFF0288D1), Colors.white, fade);
    }
    if (t > 0.45) {
      _drawStarburst(canvas, def, 34 * fade, Colors.cyanAccent, Colors.white, fade, points: 7, rot: t * 5);
    }
  }

  static void _paintWindOrBugMove(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
    PokemonType moveType, String moveId,
  ) {
    final c = moveType.color;
    if (moveId == 'roost') {
      _drawAuraRings(canvas, atk, t, fade, Colors.lightGreenAccent, ascending: true);
      for (int i = 0; i < 6; i++) {
        final a = (i / 6.0) * pi * 2 + t * 3.5;
        final p = atk + Offset(cos(a) * 32, sin(a) * 18 - 10 + t * 22);
        _drawPetalOrLeaf(canvas, p, a + 0.5, 8 * fade, Colors.white, fade);
      }
      return;
    }
    if (moveId == 'tailwind' || moveId == 'feather_dance') {
      for (int i = 0; i < 6; i++) {
        final y = (moveId == 'tailwind' ? atk : def).dy - 24 + i * 10.0;
        final x = (moveId == 'tailwind' ? atk : def).dx - 30 + t * 64 + sin(i) * 8;
        canvas.drawLine(
          Offset(x - 16, y), Offset(x + 16, y - 6),
          Paint()..color = c.withOpacity(0.85 * fade)..strokeWidth = 3 * fade..strokeCap = StrokeCap.round,
        );
      }
      return;
    }
    _paintHeavyChargeImpact(canvas, atk, def, t, fade, unit, perp, moveId: moveId, moveType: moveType);
  }

  static void _paintMysticShadowMove(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
    PokemonType moveType, String moveId,
  ) {
    final c = moveType.color;
    final target = (moveId == 'moonlight' || moveId == 'healing_wish' || moveId == 'grudge' || moveId == 'destiny_bond' || moveId == 'imprison' || moveId == 'nasty_plot')
        ? atk
        : def;
    for (int i = 0; i < 6; i++) {
      final a = (i / 6.0) * pi * 2 + t * 7.0;
      final rad = (1.0 - t * 0.45) * 38.0;
      final p = target + Offset(cos(a) * rad, sin(a) * rad * 0.72);
      _drawGlowOrb(canvas, p, 7.0 * fade, c, Colors.white, fade);
    }
    _drawAuraRings(canvas, target, t, fade, c, ascending: target == atk);
  }

  static void _paintBoostOrAuraMove(
    Canvas canvas, Offset atk, double t, double fade, PokemonType moveType, String moveId,
  ) {
    _drawAuraRings(canvas, atk, t, fade, moveType.color, ascending: true);
    for (int i = 0; i < 5; i++) {
      final a = (i / 5.0) * pi * 2 + t * 8.0;
      final p = atk + Offset(cos(a) * 32, sin(a) * 18 - t * 28);
      _drawStarburst(canvas, p, 7.5 * fade, moveType.color, Colors.white, fade, points: 4, rot: t * 9);
    }
  }

  static void _paintTargetedUtilityMove(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
    PokemonType moveType, String moveId,
  ) {
    if (moveId == 'lock_on' || moveId == 'mind_reader' || moveId == 'foresight' || moveId == 'odor_sleuth' || moveId == 'miracle_eye') {
      _drawReticle(canvas, def, t, fade, moveType.color);
      return;
    }
    _drawEnergyBeam(canvas, atk, Offset.lerp(atk, def, min(1.0, t * 2))!, 8 * fade, moveType.color, Colors.white, fade);
    _drawAuraRings(canvas, def, t, fade, moveType.color, ascending: false);
  }

  static void _paintPhysicalSkillMove(
    Canvas canvas, Offset atk, Offset def, double t, double fade, Offset unit, Offset perp,
    PokemonType moveType, String moveId,
  ) {
    _paintHeavyChargeImpact(canvas, atk, def, t, fade, unit, perp, moveId: moveId, moveType: moveType);
  }

  // ─── SHARED PRIMITIVE HELPERS ────────────────────────────────────────────

  static void _drawGlowOrb(
    Canvas canvas, Offset pos, double r, Color outer, Color core, double fade,
  ) {
    canvas.drawCircle(pos, r * 1.45, Paint()..color = outer.withOpacity(0.32 * fade));
    canvas.drawCircle(pos, r, Paint()..color = outer.withOpacity(0.92 * fade));
    canvas.drawCircle(pos - Offset(r * 0.2, r * 0.2), r * 0.45, Paint()..color = core.withOpacity(fade));
  }

  static void _drawEnergyBeam(
    Canvas canvas, Offset start, Offset end, double width, Color outer, Color core, double fade,
  ) {
    canvas.drawLine(start, end, Paint()..color = outer.withOpacity(0.35 * fade)..strokeWidth = width * 1.9..strokeCap = StrokeCap.round);
    canvas.drawLine(start, end, Paint()..color = outer.withOpacity(0.9 * fade)..strokeWidth = width..strokeCap = StrokeCap.round);
    canvas.drawLine(start, end, Paint()..color = core.withOpacity(fade)..strokeWidth = max(2.0, width * 0.36)..strokeCap = StrokeCap.round);
  }

  static void _drawSlashArc(
    Canvas canvas, Offset center, double r, double startAngle, double sweepAngle,
    double prog, Color outer, Color core, double fade, {double stroke = 7.0,}
  ) {
    if (prog <= 0.01) return;
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawArc(
      rect, startAngle, sweepAngle * prog, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = stroke * 1.7 * fade..strokeCap = StrokeCap.round..color = outer.withOpacity(0.4 * fade),
    );
    canvas.drawArc(
      rect, startAngle, sweepAngle * prog, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = stroke * fade..strokeCap = StrokeCap.round..color = outer.withOpacity(0.92 * fade),
    );
    canvas.drawArc(
      rect, startAngle, sweepAngle * prog, false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = max(1.6, stroke * 0.38 * fade)..strokeCap = StrokeCap.round..color = core.withOpacity(fade),
    );
  }

  static void _drawStarburst(
    Canvas canvas, Offset center, double outerR, Color outer, Color core, double fade, {
    int points = 6, double rot = 0.0,
  }) {
    final innerR = outerR * 0.38;
    final path = Path();
    final step = pi / points;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final a = rot + i * step;
      final pt = center + Offset(cos(a) * r, sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = outer.withOpacity(0.88 * fade));
    canvas.drawCircle(center, innerR * 0.8, Paint()..color = core.withOpacity(fade));
  }

  static void _drawSpeedLines(
    Canvas canvas, Offset origin, Offset unit, Offset perp, double len, Color color, double fade,
  ) {
    for (int i = -2; i <= 2; i++) {
      final p1 = origin + perp * (i * 9.0);
      final p2 = p1 + unit * (len * (1.0 - i.abs() * 0.14));
      canvas.drawLine(
        p1, p2,
        Paint()..color = color.withOpacity(0.75 * fade)..strokeWidth = 2.6 * fade..strokeCap = StrokeCap.round,
      );
    }
  }

  static void _drawShieldHex(
    Canvas canvas, Offset center, double radius, Color outer, Color core, double fade, double t,
  ) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = (i / 6.0) * pi * 2 - pi / 2;
      final pt = center + Offset(cos(a) * radius, sin(a) * radius * 1.08);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = outer.withOpacity(0.24 * fade));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.2 * fade..color = core.withOpacity(0.92 * fade));
  }

  static void _drawAuraRings(
    Canvas canvas, Offset center, double t, double fade, Color color, {required bool ascending,}
  ) {
    for (int r = 0; r < 3; r++) {
      final rt = ((t - r * 0.14) / 0.72).clamp(0.0, 1.0);
      if (rt <= 0) continue;
      final yShift = ascending ? -rt * 38.0 + 18.0 : rt * 22.0 - 12.0;
      canvas.drawOval(
        Rect.fromCenter(center: center + Offset(0, yShift), width: (78 - r * 12) * fade, height: 22 * fade),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 * fade
          ..color = (r.isEven ? color : Colors.white).withOpacity((1.0 - rt * 0.35) * fade),
      );
    }
  }

  static void _drawIcicle(
    Canvas canvas, Offset pos, double angle, double len, Color outer, Color core, double fade,
  ) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(len, 0)
      ..lineTo(-len * 0.65, -len * 0.36)
      ..lineTo(-len * 0.4, 0)
      ..lineTo(-len * 0.65, len * 0.36)
      ..close();
    canvas.drawPath(path, Paint()..color = outer.withOpacity(0.92 * fade));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = core.withOpacity(fade));
    canvas.restore();
  }

  static void _drawRockSpire(
    Canvas canvas, Offset base, double height, Color color, double fade,
  ) {
    final path = Path()
      ..moveTo(base.dx - height * 0.42, base.dy)
      ..lineTo(base.dx - height * 0.12, base.dy - height)
      ..lineTo(base.dx + height * 0.18, base.dy - height * 0.82)
      ..lineTo(base.dx + height * 0.44, base.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.92 * fade));
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..color = Colors.white.withOpacity(0.45 * fade));
  }

  static void _drawFlameWisp(
    Canvas canvas, Offset pos, double r, Color outer, Color core, double fade,
  ) {
    final path = Path()
      ..moveTo(pos.dx, pos.dy - r * 1.4)
      ..quadraticBezierTo(pos.dx + r, pos.dy - r * 0.2, pos.dx + r * 0.6, pos.dy + r * 0.7)
      ..quadraticBezierTo(pos.dx, pos.dy + r * 1.1, pos.dx - r * 0.6, pos.dy + r * 0.7)
      ..quadraticBezierTo(pos.dx - r, pos.dy - r * 0.2, pos.dx, pos.dy - r * 1.4)
      ..close();
    canvas.drawPath(path, Paint()..color = outer.withOpacity(0.9 * fade));
    canvas.drawCircle(pos + Offset(0, r * 0.2), r * 0.42, Paint()..color = core.withOpacity(fade));
  }

  static void _drawPetalOrLeaf(
    Canvas canvas, Offset pos, double angle, double r, Color color, double fade,
  ) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    final path = Path()
      ..moveTo(r, 0)
      ..quadraticBezierTo(0, -r * 0.65, -r, 0)
      ..quadraticBezierTo(0, r * 0.65, r, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.92 * fade));
    canvas.drawLine(Offset(-r * 0.7, 0), Offset(r * 0.7, 0), Paint()..color = Colors.white.withOpacity(0.65 * fade)..strokeWidth = 1.3);
    canvas.restore();
  }

  static void _drawReticle(
    Canvas canvas, Offset center, double t, double fade, Color color,
  ) {
    final r = (44.0 - min(1.0, t * 1.4) * 16.0) * fade;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * fade
      ..color = color.withOpacity(0.95 * fade);
    canvas.drawCircle(center, r, p);
    canvas.drawCircle(center, r * 0.5, p);
    canvas.drawLine(center - Offset(r + 10, 0), center + Offset(r + 10, 0), p);
    canvas.drawLine(center - Offset(0, r + 10), center + Offset(0, r + 10), p);
  }

  static void _drawZzz(Canvas canvas, Offset pos, double sz, Color color) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final path = Path()
      ..moveTo(pos.dx - sz * 0.5, pos.dy - sz * 0.5)
      ..lineTo(pos.dx + sz * 0.5, pos.dy - sz * 0.5)
      ..lineTo(pos.dx - sz * 0.5, pos.dy + sz * 0.5)
      ..lineTo(pos.dx + sz * 0.5, pos.dy + sz * 0.5);
    canvas.drawPath(path, p);
  }
}
