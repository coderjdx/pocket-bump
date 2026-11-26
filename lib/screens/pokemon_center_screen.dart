import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
import '../services/sound_service.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokeball_sprite.dart';
import 'move_tutor_screen.dart';
import 'poke_mart_screen.dart';

class PokemonCenterScreen extends StatefulWidget {
  const PokemonCenterScreen({super.key});

  @override
  State<PokemonCenterScreen> createState() => _PokemonCenterScreenState();
}

class _PokemonCenterScreenState extends State<PokemonCenterScreen> {
  bool _isHealing = false;
  int _placedBalls = 0;
  int _pulseCount = 0;
  bool _pulseLit = false;
  String _nurseMessage =
      "Welcome to the Pokémon Center! Shall we restore your Pokémon to perfect condition?";

  @override
  void initState() {
    super.initState();
    SoundService.instance.playBgm(BgmTrack.pokemonCenter);
  }

  @override
  void dispose() {
    SoundService.instance.playBgm(BgmTrack.hubTown);
    super.dispose();
  }

  Future<void> _runClassicHealAnimation(Trainer trainer) async {
    if (_isHealing) return;

    setState(() {
      _isHealing = true;
      _placedBalls = 0;
      _pulseCount = 0;
      _pulseLit = false;
      _nurseMessage = "Okay, I'll take your Pokémon for a few seconds...";
    });

    for (int i = 1; i <= trainer.party.length; i++) {
      await Future.delayed(const Duration(milliseconds: 210));
      if (!mounted) return;
      HapticFeedback.selectionClick();
      SoundService.instance.playUiTap();
      setState(() {
        _placedBalls = i;
      });
    }

    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    SoundService.instance.playCenterHealJingle();
    setState(() {
      _nurseMessage = "Restoring HP, PP, and curing status conditions...";
    });

    for (int pulse = 1; pulse <= 4; pulse++) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _pulseLit = true;
        _pulseCount = pulse;
      });
      await Future.delayed(const Duration(milliseconds: 230));
      if (!mounted) return;
      setState(() {
        _pulseLit = false;
      });
      await Future.delayed(const Duration(milliseconds: 140));
    }

    if (!mounted) return;

    trainer.healAndResetAllParty();
    trainer.saveProgress();
    HapticFeedback.heavyImpact();

    setState(() {
      _isHealing = false;
      _placedBalls = trainer.party.length;
      _pulseCount = 0;
      _pulseLit = false;
      _nurseMessage =
          "Thank you for waiting! Your Pokémon are fighting fit! We hope to see you again!";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Your entire party was restored to perfect condition! Full HP, PP, and status cured.",
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final int fossils = trainer.getItemCount('unknown_fossil');
    final int vouchers = trainer.getItemCount('fossil_restoration_voucher');
    final int heartScales = trainer.getItemCount('heart_scale');
    final bool needsHeal = trainer.party.any(
      (mon) =>
          mon.currentHp < mon.maxHp ||
          mon.status != StatusCondition.none ||
          mon.moves.any((m) => m.currentPp < m.maxPp),
    );

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: "POKÉMON CENTER",
        barColor: PokeColors.centerRose,
        bottomBorderColor: PokeColors.centerRoseDark,
        onBack: _isHealing ? () {} : null,
        actions: [
          PokeCurrencyPill(trainer.money),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/bg_pokemon_center.png',
            topOpacity: 0.18,
            midOpacity: 0.40,
            bottomOpacity: 0.84,
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHealingMachineConsole(trainer, needsHeal),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _buildNurseJoyStage(trainer, needsHeal),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isHealing
                          ? null
                          : () => _runClassicHealAnimation(trainer),
                      icon: Icon(
                        _isHealing
                            ? Icons.auto_awesome
                            : Icons.favorite_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _isHealing ? "HEALING POKÉMON..." : "HEAL POKÉMON",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.centerRose,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            PokeColors.centerRose.withOpacity(0.4),
                        disabledForegroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: PokePortraitButton(
                          label: "POKÉ MART",
                          subtitle: "Items & Balls",
                          icon: Icons.storefront_rounded,
                          topColor: PokeColors.pokeBlue,
                          bottomColor: PokeColors.pokeBlueDark,
                          height: 112,
                          iconSize: 30,
                          onTap: _isHealing
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const PokeMartScreen(),
                                    ),
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PokePortraitButton(
                          label: "POKÉ LAB",
                          subtitle: "${fossils + vouchers} Items",
                          icon: Icons.science_rounded,
                          topColor: PokeColors.pokeGreen,
                          bottomColor: PokeColors.pokeGreenDark,
                          height: 112,
                          iconSize: 30,
                          onTap: _isHealing
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const PokemonLabScreen(),
                                    ),
                                  );
                                },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PokePortraitButton(
                          label: "MOVE TUTOR",
                          subtitle: "Egg Moves",
                          icon: Icons.favorite_rounded,
                          topColor: PokeColors.centerRose,
                          bottomColor: PokeColors.centerRoseDark,
                          height: 112,
                          iconSize: 30,
                          badgeText: "x$heartScales",
                          onTap: _isHealing
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MoveTutorScreen(),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNurseJoyStage(Trainer trainer, bool needsHeal) {
    final bool glowing = _isHealing && _pulseLit;
    final Color statusColor = _isHealing
        ? PokeColors.badgeGoldDark
        : (needsHeal ? PokeColors.bagOrange : PokeColors.pokeGreenDark);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: PokeDecorations.card(
        fill: PokeColors.creamSurface.withOpacity(0.95),
        border: glowing ? PokeColors.badgeGold : PokeColors.centerRose,
        radius: 16,
        borderWidth: 1.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.medical_services_rounded,
                      color: PokeColors.centerRose, size: 14),
                  SizedBox(width: 6),
                  Text(
                    "POKÉMON CENTER • NURSE JOY",
                    style: TextStyle(
                      color: PokeColors.inkDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withOpacity(0.55)),
                ),
                child: Text(
                  _isHealing
                      ? "RECOVERING..."
                      : (needsHeal ? "NEEDS CARE" : "FULL HEALTH"),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: glowing ? 190 : 160,
                  height: glowing ? 190 : 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: glowing
                          ? [
                              PokeColors.badgeGold.withOpacity(0.38),
                              PokeColors.centerRose.withOpacity(0.16),
                              Colors.transparent,
                            ]
                          : [
                              PokeColors.centerRose.withOpacity(0.18),
                              Colors.transparent,
                            ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: AnimatedScale(
                    scale: glowing ? 1.04 : 1.0,
                    duration: const Duration(milliseconds: 140),
                    child: Image.asset(
                      'assets/images/nurse_joy.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: PokeDecorations.card(
              fill: PokeColors.cardWhite,
              border: glowing ? PokeColors.badgeGold : PokeColors.centerRose,
              radius: 12,
              borderWidth: 1.4,
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: PokeColors.centerRose,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "NURSE JOY",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _nurseMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PokeColors.inkDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealingMachineConsole(Trainer trainer, bool needsHeal) {
    final bool glowing = _isHealing && _pulseLit;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(12),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: glowing ? PokeColors.badgeGold : PokeColors.centerRose,
        radius: 18,
        borderWidth: glowing ? 2.0 : 1.6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (glowing ? PokeColors.badgeGold : PokeColors.centerRose)
                      .withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: glowing ? PokeColors.badgeGold : PokeColors.centerRose,
                  ),
                ),
                child: Icon(
                  glowing ? Icons.auto_awesome : Icons.local_hospital_rounded,
                  color: glowing
                      ? PokeColors.badgeGoldDark
                      : PokeColors.centerRose,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "RECOVERY MACHINE",
                          style: TextStyle(
                            color: PokeColors.centerRoseDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 9.5,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (_isHealing)
                          Text(
                            _pulseCount > 0
                                ? "CHIME $_pulseCount/4"
                                : "LOADING $_placedBalls/${trainer.party.length}",
                            style: TextStyle(
                              color: glowing
                                  ? PokeColors.badgeGoldDark
                                  : PokeColors.centerRose,
                              fontWeight: FontWeight.w900,
                              fontSize: 9.5,
                              letterSpacing: 0.6,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _nurseMessage,
                      style: const TextStyle(
                        color: PokeColors.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Classic 2x3 Metallic Recovery Tray with 6 Poké Ball Sockets
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE5EAF2), Color(0xFFD2DAE6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: glowing
                    ? PokeColors.badgeGold
                    : PokeColors.frameBorder.withOpacity(0.45),
                width: 1.4,
              ),
            ),
            child: Column(
              children: [
                for (int row = 0; row < 2; row++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (int col = 0; col < 3; col++)
                        _buildMachineSocket(
                          index: row * 3 + col,
                          trainer: trainer,
                        ),
                    ],
                  ),
                  if (row == 0) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineSocket({
    required int index,
    required Trainer trainer,
  }) {
    final bool hasMon = index < trainer.party.length;
    final bool isPlaced =
        hasMon && (_isHealing ? index < _placedBalls : true);
    final bool isLit = _isHealing && isPlaced && _pulseLit;
    final PokemonInstance? mon = hasMon ? trainer.party[index] : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isLit
              ? [
                  const Color(0xFFFFF176),
                  const Color(0xFFFFB300),
                ]
              : [
                  PokeColors.cardWhite,
                  const Color(0xFFC7D0DF),
                ],
        ),
        border: Border.all(
          color: isLit
              ? PokeColors.badgeGoldDark
              : (isPlaced
                  ? PokeColors.centerRose
                  : PokeColors.frameBorderSoft),
          width: isLit ? 2.2 : 1.4,
        ),
        boxShadow: isLit
            ? [
                BoxShadow(
                  color: const Color(0xFFFFEE58).withOpacity(0.75),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isPlaced && mon != null
            ? AnimatedScale(
                scale: isLit ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: Opacity(
                  opacity: (!_isHealing && mon.isFainted) ? 0.45 : 1.0,
                  child: PokeBallSpriteWidget(
                    ballType: mon.caughtBall,
                    size: 26,
                    buttonGlowColor: isLit ? const Color(0xFFFFEE58) : null,
                  ),
                ),
              )
            : Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: PokeColors.panelSoft,
                  border: Border.all(color: PokeColors.frameBorderSoft),
                ),
              ),
      ),
    );
  }
}

class PokemonLabScreen extends StatefulWidget {
  const PokemonLabScreen({super.key});

  @override
  State<PokemonLabScreen> createState() => _PokemonLabScreenState();
}

class _PokemonLabScreenState extends State<PokemonLabScreen> {
  void _restoreFossil(Trainer trainer) {
    if (trainer.getItemCount('unknown_fossil') <= 0 ||
        trainer.getItemCount('fossil_restoration_voucher') <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You need 1 Unknown Fossil and 1 Fossil Restoration Voucher to restore a fossil.",
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (trainer.isStorageFull) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Both your Party and all 16 PC Boxes are full (320/320)! Release a Pokémon first.",
          ),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    trainer.adjustItemCount('unknown_fossil', -1);
    trainer.adjustItemCount('fossil_restoration_voucher', -1);

    final fossilPool = PokedexDatabase.firstStageFossilSpeciesIds.where((id) {
      final spec = PokedexDatabase.species[id];
      return spec != null && spec.isAvailableInVersion(trainer.gameVersion);
    }).toList();
    final chosenPool = fossilPool.isNotEmpty
        ? fossilPool
        : PokedexDatabase.firstStageFossilSpeciesIds;
    final chosenId = chosenPool[Random().nextInt(chosenPool.length)];
    final restoredMon = PokedexDatabase.createPokemon(
      chosenId,
      level: 10,
      respectMinEncounterLevel: false,
      hiddenAbilityChance: 0.08,
    );
    final boxNum = trainer.addPokemon(restoredMon);
    trainer.saveProgress();
    HapticFeedback.heavyImpact();
    SoundService.instance.playPokemonCry(restoredMon.species.id);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) SoundService.instance.playLevelUpSfx();
    });

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: PokeColors.pokeGreen, width: 1.6),
        ),
        title: const Row(
          children: [
            Icon(Icons.science, color: PokeColors.pokeGreenDark, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "FOSSIL RESTORATION COMPLETE!",
                style: TextStyle(
                  color: PokeColors.pokeGreenDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: Image.network(
                restoredMon.spriteUrl,
                width: 90,
                height: 90,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, __, ___) => Image.network(
                  restoredMon.staticSpriteUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.catching_pokemon,
                    color: PokeColors.pokeGreen,
                    size: 56,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You went to a Poké Lab to get the fossil restored! The scientists revived a Lv. ${restoredMon.level} ${restoredMon.species.name}!",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PokeColors.inkDark,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Ability: ${restoredMon.abilityDefinition?.name ?? restoredMon.abilityId}${restoredMon.isHiddenAbility ? ' (Hidden Ability!)' : ''}",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: restoredMon.isHiddenAbility
                    ? PokeColors.badgeGoldDark
                    : PokeColors.pokeBlueDark,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              boxNum == null
                  ? "${restoredMon.species.name} joined your Party!"
                  : "${restoredMon.species.name} was transferred to PC Box #$boxNum!",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PokeColors.pokeGreenDark,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dlgCtx);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokeColors.pokeGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              "AWESOME!",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final int fossils = trainer.getItemCount('unknown_fossil');
    final int vouchers = trainer.getItemCount('fossil_restoration_voucher');
    final bool canRestore = fossils > 0 && vouchers > 0 && !trainer.isStorageFull;

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: "POKÉMON LAB",
        barColor: PokeColors.pokeGreen,
        bottomBorderColor: PokeColors.pokeGreenDark,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/bg_pokemon_lab.png',
            topOpacity: 0.18,
            midOpacity: 0.44,
            bottomOpacity: 0.86,
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: PokeDecorations.card(
                      fill: PokeColors.creamSurface,
                      border: PokeColors.pokeGreen,
                      radius: 16,
                      borderWidth: 1.6,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: PokeColors.pokeGreen.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: PokeColors.pokeGreen.withOpacity(0.55),
                            ),
                          ),
                          child: const Icon(
                            Icons.science_rounded,
                            color: PokeColors.pokeGreenDark,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "FOSSIL RESTORATION CHAMBER",
                                style: TextStyle(
                                  color: PokeColors.pokeGreenDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "Combine 1 Unknown Fossil and 1 Fossil Restoration Voucher to revive a random Lv. 10 first-stage Fossil Pokémon!",
                                style: TextStyle(
                                  color: PokeColors.inkMuted,
                                  fontSize: 10.8,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCountCard(
                          icon: Icons.album_rounded,
                          color: PokeColors.bagOrangeDark,
                          title: "Unknown Fossils",
                          count: fossils,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCountCard(
                          icon: Icons.confirmation_number_rounded,
                          color: PokeColors.pokeBlueDark,
                          title: "Restoration Vouchers",
                          count: vouchers,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: PokeDecorations.card(
                        fill: PokeColors.creamSurface,
                        border: PokeColors.frameBorderSoft,
                        radius: 18,
                        borderWidth: 1.5,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "PREHISTORIC REVIVAL SPECIMENS (LV. 10)",
                            style: TextStyle(
                              color: PokeColors.inkDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 10.5,
                              letterSpacing: 0.9,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: PokedexDatabase.firstStageFossilSpeciesIds
                                .map((id) {
                              final spec = PokedexDatabase.species[id]!;
                              final bool obtained = trainer.isSpeciesCaught(id);
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: PokeDecorations.card(
                                      fill: obtained
                                          ? PokeColors.cardWhite
                                          : PokeColors.panelSoft,
                                      border: obtained
                                          ? PokeColors.pokeGreen
                                          : PokeColors.frameBorderSoft,
                                      radius: 16,
                                      borderWidth: 1.5,
                                    ),
                                    child: Center(
                                      child: obtained
                                          ? Image.network(
                                              spec.spriteUrl,
                                              width: 54,
                                              height: 54,
                                              fit: BoxFit.contain,
                                              filterQuality: FilterQuality.none,
                                              errorBuilder: (_, __, ___) =>
                                                  Image.network(
                                                spec.staticSpriteUrl,
                                                width: 54,
                                                height: 54,
                                                fit: BoxFit.contain,
                                                filterQuality:
                                                    FilterQuality.none,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                  Icons.catching_pokemon,
                                                  color: PokeColors.pokeGreen,
                                                ),
                                              ),
                                            )
                                          : const Text(
                                              "?",
                                              style: TextStyle(
                                                color: PokeColors.inkMuted,
                                                fontSize: 34,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    obtained ? spec.name : "???",
                                    style: TextStyle(
                                      color: obtained
                                          ? PokeColors.inkDark
                                          : PokeColors.inkMuted,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    "Lv. 10",
                                    style: TextStyle(
                                      color: obtained
                                          ? PokeColors.pokeGreenDark
                                          : PokeColors.inkSubtle,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: PokeDecorations.inset(radius: 10),
                            child: const Text(
                              "Unknown Fossils and Fossil Restoration Vouchers drop as rare rewards when re-challenging Kanto Gym Leaders.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: PokeColors.inkMuted,
                                fontSize: 10.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: canRestore ? () => _restoreFossil(trainer) : null,
                      icon: const Icon(Icons.biotech_rounded, size: 20),
                      label: Text(
                        canRestore
                            ? "RESTORE FOSSIL (1 FOSSIL + 1 VOUCHER)"
                            : (trainer.isStorageFull
                                ? "STORAGE FULL (320/320)"
                                : "NEED 1 FOSSIL & 1 VOUCHER"),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: 0.7,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.pokeGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: PokeColors.panelSoft,
                        disabledForegroundColor: PokeColors.inkSubtle,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountCard({
    required IconData icon,
    required Color color,
    required String title,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: count > 0 ? color : PokeColors.frameBorderSoft,
        radius: 16,
        borderWidth: count > 0 ? 1.6 : 1.2,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            "x$count",
            style: TextStyle(
              color: count > 0 ? color : PokeColors.inkSubtle,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PokeColors.inkDark,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
