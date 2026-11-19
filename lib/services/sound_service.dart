import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/move.dart';
import '../models/pokemon_type.dart';

enum BgmTrack {
  none,
  titleLab,
  hubTown,
  pokemonCenter,
  battleWild,
  battleGym,
  battleExpedition,
  battleSpecial,
}

enum BattleBgmCategory {
  wild,
  gym,
  expedition,
  special,
}

class SoundService extends ChangeNotifier {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const String _prefMuted = 'sound_muted';
  static const String _prefBgmMuted = 'sound_bgm_muted';
  static const String _prefSfxMuted = 'sound_sfx_muted';
  static const String _prefBgmVol = 'sound_bgm_volume';
  static const String _prefSfxVol = 'sound_sfx_volume';

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _cryPlayer = AudioPlayer();
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());
  int _sfxCursor = 0;

  bool _initialized = false;
  bool _isMuted = false;
  bool _bgmMuted = false;
  bool _sfxMuted = false;
  double _bgmVolume = 0.45;
  double _sfxVolume = 0.80;

  BgmTrack _currentBgm = BgmTrack.none;
  BgmTrack _requestedBgm = BgmTrack.none;
  bool _bgmStartedOnce = false;
  bool _pausedByLifecycle = false;

  bool get isMuted => _isMuted;
  bool get isBgmMuted => _isMuted || _bgmMuted;
  bool get isSfxMuted => _isMuted || _sfxMuted;
  bool get bgmToggle => _bgmMuted;
  bool get sfxToggle => _sfxMuted;
  double get bgmVolume => _bgmVolume;
  double get sfxVolume => _sfxVolume;
  BgmTrack get currentBgm => _currentBgm;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMuted = prefs.getBool(_prefMuted) ?? false;
      _bgmMuted = prefs.getBool(_prefBgmMuted) ?? false;
      _sfxMuted = prefs.getBool(_prefSfxMuted) ?? false;
      _bgmVolume = (prefs.getDouble(_prefBgmVol) ?? 0.45).clamp(0.0, 1.0);
      _sfxVolume = (prefs.getDouble(_prefSfxVol) ?? 0.80).clamp(0.0, 1.0);

      final mixContext = AudioContextConfig(
        focus: AudioContextConfigFocus.mixWithOthers,
      ).build();

      await AudioPlayer.global.setAudioContext(mixContext);
      await _bgmPlayer.setAudioContext(mixContext);
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _cryPlayer.setAudioContext(mixContext);
      await _cryPlayer.setReleaseMode(ReleaseMode.stop);
      for (final p in _sfxPool) {
        await p.setAudioContext(mixContext);
        await p.setReleaseMode(ReleaseMode.stop);
      }
    } catch (_) {
      // Ignore initialization errors on unsupported headless hosts
    }
  }

  Future<void> _savePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefMuted, _isMuted);
      await prefs.setBool(_prefBgmMuted, _bgmMuted);
      await prefs.setBool(_prefSfxMuted, _sfxMuted);
      await prefs.setDouble(_prefBgmVol, _bgmVolume);
      await prefs.setDouble(_prefSfxVol, _sfxVolume);
    } catch (_) {}
  }

  Future<void> toggleAllMute() async {
    _isMuted = !_isMuted;
    await _applyBgmState();
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setBgmMuted(bool muted) async {
    _bgmMuted = muted;
    await _applyBgmState();
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setSfxMuted(bool muted) async {
    _sfxMuted = muted;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setBgmVolume(double vol) async {
    _bgmVolume = vol.clamp(0.0, 1.0);
    await _applyBgmState();
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setSfxVolume(double vol) async {
    _sfxVolume = vol.clamp(0.0, 1.0);
    await _savePrefs();
    notifyListeners();
  }

  String? _assetForBgm(BgmTrack track) {
    switch (track) {
      case BgmTrack.none:
        return null;
      case BgmTrack.titleLab:
        return 'audio/bgm/bgm_title_lab.m4a';
      case BgmTrack.hubTown:
        return 'audio/bgm/bgm_hub_town.m4a';
      case BgmTrack.pokemonCenter:
        return 'audio/bgm/bgm_pokemon_center.m4a';
      case BgmTrack.battleWild:
        return 'audio/bgm/bgm_battle_wild.m4a';
      case BgmTrack.battleGym:
        return 'audio/bgm/bgm_battle_gym.m4a';
      case BgmTrack.battleExpedition:
        return 'audio/bgm/bgm_battle_expedition.m4a';
      case BgmTrack.battleSpecial:
        return 'audio/bgm/bgm_battle_special.m4a';
    }
  }

  Future<void> _applyBgmState() async {
    try {
      if (isBgmMuted || _requestedBgm == BgmTrack.none) {
        await _bgmPlayer.pause();
        return;
      }
      await _bgmPlayer.setVolume(_bgmVolume);
      if (_currentBgm == _requestedBgm && _bgmStartedOnce) {
        await _bgmPlayer.resume();
      } else {
        await playBgm(_requestedBgm, forceRestart: true);
      }
    } catch (_) {}
  }

  /// Unlocks WebAudio autoplay seamlessly on first pointer gesture.
  void unlockOnUserGesture() {
    if (!kIsWeb) return;
    if (_requestedBgm != BgmTrack.none && !_bgmStartedOnce && !isBgmMuted) {
      playBgm(_requestedBgm, forceRestart: true);
    }
  }

  Future<void> handleAppLifecycle(AppLifecycleState state) async {
    try {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.detached) {
        _pausedByLifecycle = true;
        await _bgmPlayer.pause();
      } else if (state == AppLifecycleState.resumed && _pausedByLifecycle) {
        _pausedByLifecycle = false;
        if (!isBgmMuted && _requestedBgm != BgmTrack.none) {
          await _bgmPlayer.resume();
        }
      }
    } catch (_) {}
  }

  Future<void> playBgm(BgmTrack track, {bool forceRestart = false}) async {
    _requestedBgm = track;
    final asset = _assetForBgm(track);
    if (asset == null) {
      _currentBgm = BgmTrack.none;
      _bgmStartedOnce = false;
      try {
        await _bgmPlayer.stop();
      } catch (_) {}
      return;
    }

    if (!forceRestart && _currentBgm == track && _bgmStartedOnce) {
      return;
    }

    if (isBgmMuted) {
      _currentBgm = track;
      try {
        await _bgmPlayer.stop();
      } catch (_) {}
      return;
    }

    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(_bgmVolume);
      await _bgmPlayer.play(AssetSource(asset));
      _currentBgm = track;
      _bgmStartedOnce = true;
    } catch (_) {
      // On Web before first interaction, autoplay may throw; unlockOnUserGesture retries cleanly.
      _currentBgm = track;
      _bgmStartedOnce = false;
    }
  }

  Future<void> playBattleBgm(BattleBgmCategory category) {
    final track = switch (category) {
      BattleBgmCategory.wild => BgmTrack.battleWild,
      BattleBgmCategory.gym => BgmTrack.battleGym,
      BattleBgmCategory.expedition => BgmTrack.battleExpedition,
      BattleBgmCategory.special => BgmTrack.battleSpecial,
    };
    return playBgm(track, forceRestart: true);
  }

  Future<void> stopBgm() => playBgm(BgmTrack.none);

  Future<void> playVictoryFanfare({bool isTrainer = false}) async {
    if (isBgmMuted) return;
    _requestedBgm = BgmTrack.none;
    _currentBgm = BgmTrack.none;
    _bgmStartedOnce = false;
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.stop);
      await _bgmPlayer.setVolume(_bgmVolume);
      await _bgmPlayer.play(
        AssetSource(
          isTrainer
              ? 'audio/bgm/jingle_victory_trainer.m4a'
              : 'audio/bgm/jingle_victory.m4a',
        ),
      );
    } catch (_) {}
  }

  Future<void> playEvolutionFanfare() async {
    if (isSfxMuted && isBgmMuted) return;
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.stop);
      await _bgmPlayer.setVolume(max(_bgmVolume, 0.55));
      await _bgmPlayer.play(AssetSource('audio/bgm/jingle_evolution.m4a'));
      _currentBgm = BgmTrack.none;
      _bgmStartedOnce = false;
    } catch (_) {}
  }

  double max(double a, double b) => a > b ? a : b;

  // ─── SFX HELPERS ────────────────────────────────────────────────────────────
  Future<void> _playSfxAsset(String assetPath, {double volumeScale = 1.0}) async {
    if (isSfxMuted) return;
    final player = _sfxPool[_sfxCursor];
    _sfxCursor = (_sfxCursor + 1) % _sfxPool.length;
    try {
      await player.stop();
      await player.setVolume((_sfxVolume * volumeScale).clamp(0.0, 1.0));
      await player.play(AssetSource(assetPath));
    } catch (_) {}
  }

  // Phase 1: Pokémon Cries
  Future<void> playPokemonCry(int speciesId, {bool fainted = false}) async {
    if (isSfxMuted || speciesId < 1 || speciesId > 151) return;
    try {
      await _cryPlayer.stop();
      await _cryPlayer.setVolume((_sfxVolume * 0.92).clamp(0.0, 1.0));
      await _cryPlayer.play(AssetSource('audio/cries/$speciesId.mp3'));
      await _cryPlayer.setPlaybackRate(fainted ? 0.74 : 1.0);
    } catch (_) {}
  }

  // Phase 1: Move & Hit SFX
  Future<void> playMoveSfx(PokemonType type, MoveCategory category) {
    if (category == MoveCategory.status) {
      return _playSfxAsset('audio/sfx/sfx_move_status.wav', volumeScale: 0.75);
    }
    final asset = switch (type) {
      PokemonType.fire => 'audio/sfx/sfx_move_fire.wav',
      PokemonType.water => 'audio/sfx/sfx_move_water.wav',
      PokemonType.electric => 'audio/sfx/sfx_move_electric.wav',
      PokemonType.grass || PokemonType.bug => 'audio/sfx/sfx_move_grass.wav',
      PokemonType.ice => 'audio/sfx/sfx_move_ice.wav',
      PokemonType.psychic || PokemonType.fairy => 'audio/sfx/sfx_move_psychic.wav',
      PokemonType.rock || PokemonType.ground => 'audio/sfx/sfx_move_rock_ground.wav',
      PokemonType.ghost || PokemonType.dark || PokemonType.poison => 'audio/sfx/sfx_move_ghost_dark.wav',
      PokemonType.dragon => 'audio/sfx/sfx_move_dragon.wav',
      _ => 'audio/sfx/sfx_move_physical.wav',
    };
    return _playSfxAsset(asset, volumeScale: 0.85);
  }

  Future<void> playHitSfx({
    double effectiveness = 1.0,
    bool isCrit = false,
    bool isMiss = false,
  }) {
    if (isMiss) return _playSfxAsset('audio/sfx/sfx_miss.wav', volumeScale: 0.8);
    if (isCrit) return _playSfxAsset('audio/sfx/sfx_hit_crit.wav');
    if (effectiveness >= 2.0) return _playSfxAsset('audio/sfx/sfx_hit_super.wav');
    if (effectiveness > 0.0 && effectiveness < 1.0) {
      return _playSfxAsset('audio/sfx/sfx_hit_weak.wav', volumeScale: 0.85);
    }
    return _playSfxAsset('audio/sfx/sfx_hit_normal.wav');
  }

  Future<void> playFaintSfx() => _playSfxAsset('audio/sfx/sfx_faint.wav');
  Future<void> playStatChangeSfx({required bool isUp}) => _playSfxAsset(
      isUp ? 'audio/sfx/sfx_stat_up.wav' : 'audio/sfx/sfx_stat_down.wav',
      volumeScale: 0.8);
  Future<void> playHealSfx() =>
      _playSfxAsset('audio/sfx/sfx_heal.wav', volumeScale: 0.85);
  Future<void> playStatusAilmentSfx() =>
      _playSfxAsset('audio/sfx/sfx_status_ailment.wav', volumeScale: 0.78);
  Future<void> playLevelUpSfx() =>
      _playSfxAsset('audio/sfx/sfx_level_up.wav', volumeScale: 0.95);

  // Poké Ball Capture Sequence SFX
  Future<void> playBallThrowSfx() => _playSfxAsset('audio/sfx/sfx_ball_throw.wav');
  Future<void> playBallOpenSfx() => _playSfxAsset('audio/sfx/sfx_ball_open.wav');
  Future<void> playBallWobbleSfx() =>
      _playSfxAsset('audio/sfx/sfx_ball_wobble.wav', volumeScale: 0.85);
  Future<void> playBallCatchSfx() => _playSfxAsset('audio/sfx/sfx_ball_catch.wav');
  Future<void> playBallBreakSfx() => _playSfxAsset('audio/sfx/sfx_ball_break.wav');

  // Phase 3: UI SFX
  Future<void> playUiTap() =>
      _playSfxAsset('audio/sfx/sfx_ui_tap.wav', volumeScale: 0.65);
  Future<void> playUiConfirm() =>
      _playSfxAsset('audio/sfx/sfx_ui_confirm.wav', volumeScale: 0.75);
  Future<void> playUiCancel() =>
      _playSfxAsset('audio/sfx/sfx_ui_cancel.wav', volumeScale: 0.70);
  Future<void> playUiError() =>
      _playSfxAsset('audio/sfx/sfx_ui_error.wav', volumeScale: 0.80);
  Future<void> playUiBuy() =>
      _playSfxAsset('audio/sfx/sfx_ui_buy.wav', volumeScale: 0.85);
  Future<void> playCenterHealJingle() =>
      _playSfxAsset('audio/sfx/sfx_ui_heal.wav', volumeScale: 0.92);
  Future<void> playBumpChime() =>
      _playSfxAsset('audio/sfx/sfx_ui_bump.wav', volumeScale: 0.85);
}
