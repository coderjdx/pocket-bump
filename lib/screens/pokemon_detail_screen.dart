import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_region.dart';
import '../models/item.dart';
import '../models/move.dart';
import '../models/pokemon_gender.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_nature.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/egg_move_service.dart';
import '../services/pokedex_database.dart';
import '../services/sound_service.dart';
import '../services/tm_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/move_learn_dialog.dart';
import '../widgets/nickname_dialog.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/pokemon_sprite_image.dart';
import '../widgets/type_badge.dart';

class PokemonDetailScreen extends StatefulWidget {
  final int? partyIndex;
  final int? pcBoxIndex;
  final int? pcSlotIndex;

  const PokemonDetailScreen({
    super.key,
    this.partyIndex,
    this.pcBoxIndex,
    this.pcSlotIndex,
  }) : assert(
          partyIndex != null || (pcBoxIndex != null && pcSlotIndex != null),
          'Provide either partyIndex or both pcBoxIndex and pcSlotIndex.',
        );

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> {
  PokemonInstance? _resolvePokemon(Trainer trainer) {
    final pIdx = widget.partyIndex;
    if (pIdx != null) {
      if (pIdx >= 0 && pIdx < trainer.party.length) {
        return trainer.party[pIdx];
      }
      return null;
    }
    final bIdx = widget.pcBoxIndex;
    final sIdx = widget.pcSlotIndex;
    if (bIdx != null &&
        sIdx != null &&
        bIdx >= 0 &&
        bIdx < trainer.pcBoxes.length &&
        sIdx >= 0 &&
        sIdx < trainer.pcBoxes[bIdx].length) {
      return trainer.pcBoxes[bIdx][sIdx];
    }
    return null;
  }

  String _categoryTag(MoveCategory c) {
    switch (c) {
      case MoveCategory.physical:
        return 'PHYS';
      case MoveCategory.special:
        return 'SPEC';
      case MoveCategory.status:
        return 'STAT';
    }
  }

  Color _categoryColor(MoveCategory c) {
    switch (c) {
      case MoveCategory.physical:
        return const Color(0xFFD84315);
      case MoveCategory.special:
        return PokeColors.pokeBlueDark;
      case MoveCategory.status:
        return const Color(0xFF7B1FA2);
    }
  }

  String _evolutionSummary(PokemonSpecies spec) {
    return PokedexDatabase.evolutionRequirementLabel(spec) ?? "Final Form";
  }

  Future<void> _promptSwapRememberedMove(
    Trainer trainer,
    PokemonInstance mon,
    Move reserveMove,
  ) async {
    if (mon.moves.length < 4) {
      mon.equipReserveMove(reserveMove);
      trainer.saveProgress();
      trainer.notifyListeners();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${mon.nickname} equipped ${reserveMove.name}!"),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final int? slotIdx = await showDialog<int>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: reserveMove.type.color, width: 1.6),
        ),
        title: Text(
          "Swap in ${reserveMove.name}",
          style: const TextStyle(
            color: PokeColors.inkDark,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Choose an active move to swap out for ${reserveMove.name}. The replaced move stays remembered so you can swap it back anytime.",
                style: const TextStyle(
                    color: PokeColors.inkMuted, fontSize: 11.5, height: 1.3),
              ),
              const SizedBox(height: 10),
              ...List.generate(mon.moves.length, (i) {
                final cur = mon.moves[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: InkWell(
                    onTap: () => Navigator.pop(dlgCtx, i),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: PokeDecorations.card(
                        border: cur.type.color,
                        radius: 12,
                        borderWidth: 1.4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        cur.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: PokeColors.inkDark,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    TypeBadge(type: cur.type),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "PWR ${cur.powerLabel} • ACC ${cur.accuracy}% • PP ${cur.currentPp}/${cur.maxPp}",
                                  style: const TextStyle(
                                    color: PokeColors.inkMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.swap_horiz_rounded,
                              color: PokeColors.pokeBlue, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, null),
            child: const Text("Cancel",
                style: TextStyle(color: PokeColors.inkMuted)),
          ),
        ],
      ),
    );

    if (slotIdx != null) {
      final oldName = mon.moves[slotIdx].name;
      mon.swapActiveMove(slotIdx, reserveMove);
      trainer.saveProgress();
      trainer.notifyListeners();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Swapped $oldName out for ${reserveMove.name} on ${mon.nickname}!"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _teachTmToPokemon(
    Trainer trainer,
    PokemonInstance mon,
    Item tmItem,
    Move tmMove,
  ) async {
    if (trainer.getItemCount(tmItem.id) <= 0) return;
    if (mon.moves.any((m) => m.id == tmMove.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${mon.nickname} already knows ${tmMove.name}!"),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final outcome = await showMoveLearnDialog(
      context,
      pokemon: mon,
      newMove: tmMove,
      recordOnSkip: false,
      headerNote:
          "Teach ${tmMove.name} to ${mon.nickname} using ${tmItem.name}? (Reusable)",
    );
    if (!outcome.learned) return;

    trainer.saveProgress();
    trainer.notifyListeners();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome.forgottenMove != null
              ? "${mon.nickname} forgot ${outcome.forgottenMove!.name} and learned ${tmMove.name}!"
              : "${mon.nickname} learned ${tmMove.name}!",
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Trainer>(
      builder: (context, trainer, _) {
        final mon = _resolvePokemon(trainer);
        if (mon == null) {
          return Scaffold(
            backgroundColor: PokeColors.canvasCream,
            appBar: buildPokeAppBar(
              context: context,
              title: "POKÉMON SUMMARY",
              barColor: PokeColors.pokeRed,
            ),
            body: const Center(
              child: Text("Pokémon not found.",
                  style: TextStyle(color: PokeColors.inkMuted)),
            ),
          );
        }

        final Color typeColor = mon.species.types.first.color;
        final Color typeHeader = PokeColors.darken(typeColor, 0.16);
        final int prevLvlExp =
            (mon.level - 1) * (mon.level - 1) * (mon.level - 1);
        final int nextLvlExp = mon.expForNextLevel;
        final double expProgress = nextLvlExp > prevLvlExp
            ? ((mon.currentExp - prevLvlExp) / (nextLvlExp - prevLvlExp))
                .clamp(0.0, 1.0)
            : 1.0;
        final int expRemaining =
            mon.level >= 100 ? 0 : (nextLvlExp - mon.currentExp).clamp(0, 9999999);

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: PokeColors.canvasCream,
            appBar: AppBar(
              backgroundColor: typeHeader,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 2,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                "#${mon.species.id.toString().padLeft(3, '0')} • ${mon.species.name.toUpperCase()}",
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              actions: [
                if (widget.partyIndex != null && widget.partyIndex != 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: TextButton.icon(
                      onPressed: () {
                        trainer.setLeadPokemon(widget.partyIndex!);
                        Navigator.pop(context, 'promoted_to_lead');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text("${mon.nickname} is now your Lead Pokémon!"),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.star_rounded,
                          color: Color(0xFFFFE082), size: 16),
                      label: const Text(
                        "LEAD",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                else if (widget.pcBoxIndex != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "BOX ${widget.pcBoxIndex! + 1}",
                          style: TextStyle(
                            color: typeHeader,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            body: Column(
              children: [
                // ─── HERO SUMMARY HEADER ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  decoration: BoxDecoration(
                    color: PokeColors.creamSurface,
                    border: Border(
                      bottom: BorderSide(color: typeHeader, width: 1.8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: PokeDecorations.card(
                          fill: PokeColors.cardWhite,
                          border: mon.isShiny ? PokeColors.badgeGold : typeHeader,
                          radius: 18,
                          borderWidth: 2.0,
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: GestureDetector(
                                onTap: () => SoundService.instance
                                    .playPokemonCry(mon.species.id),
                                child: Builder(builder: (_) {
                                  final double heroSize = mon.species
                                      .scaledUiSize(72, minSize: 38);
                                  return PokemonSpriteImage.fromInstance(
                                    mon,
                                    width: 78,
                                    height: heroSize,
                                    fallbackIconSize:
                                        (heroSize * 0.68).clamp(24.0, 46.0),
                                    fallbackIconColor: typeColor,
                                  );
                                }),
                              ),
                            ),
                            if (mon.isShiny)
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: PokeColors.badgeGoldDark,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                PokeBallSpriteWidget(
                                    ballType: mon.caughtBall, size: 16),
                                const SizedBox(width: 6),
                                if (mon.isShiny) ...[
                                  Container(
                                    margin: const EdgeInsets.only(right: 5),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color:
                                          PokeColors.badgeGold.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: PokeColors.badgeGoldDark,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          color: PokeColors.badgeGoldDark,
                                          size: 10,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          "SHINY",
                                          style: TextStyle(
                                            color: PokeColors.badgeGoldDark,
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              mon.nickname,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: PokeColors.inkDark,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          if (mon.gender !=
                                              PokemonGender.genderless) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              mon.gender.symbol,
                                              style: TextStyle(
                                                color: mon.gender.color,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (mon.nickname != mon.species.name)
                                        Text(
                                          mon.species.name,
                                          style: const TextStyle(
                                            color: PokeColors.inkMuted,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (mon.canSetNickname)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () async {
                                        SoundService.instance.playUiTap();
                                        final chosen =
                                            await showNicknamePokemonDialog(
                                          context,
                                          pokemon: mon,
                                        );
                                        if (!mounted || chosen == null) return;
                                        if (trainer.setPokemonNickname(
                                            mon, chosen)) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  "${mon.species.name} was permanently nicknamed ${mon.nickname}!"),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: PokeColors.pokeBlue
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: PokeColors.pokeBlue),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.edit_rounded,
                                                size: 11,
                                                color: PokeColors.pokeBlueDark),
                                            SizedBox(width: 3),
                                            Text(
                                              "NAME",
                                              style: TextStyle(
                                                color: PokeColors.pokeBlueDark,
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Tooltip(
                                      message: "Nickname is permanent",
                                      child: Icon(
                                        Icons.lock_rounded,
                                        size: 14,
                                        color: PokeColors.inkSubtle,
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: PokeColors.badgeGold.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: PokeColors.badgeGoldDark),
                                  ),
                                  child: Text(
                                    "Lv.${mon.level}",
                                    style: const TextStyle(
                                      color: PokeColors.badgeGoldDark,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                ...mon.species.types.map((t) => Padding(
                                      padding: const EdgeInsets.only(right: 5),
                                      child: TypeBadge(type: t),
                                    )),
                                const Spacer(),
                                Text(
                                  mon.hasHeldItem
                                      ? "Held: ${ItemDatabase.byId(mon.heldItemId!)?.name ?? mon.heldItemId}"
                                      : "No Held Item",
                                  style: TextStyle(
                                    color: mon.hasHeldItem
                                        ? PokeColors.badgeGoldDark
                                        : PokeColors.inkSubtle,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            HpBar(
                              currentHp: mon.currentHp,
                              maxHp: mon.maxHp,
                              textColor: PokeColors.inkMuted,
                              hpLabelColor: PokeColors.badgeGoldDark,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "HP ${mon.currentHp}/${mon.maxHp}${mon.isFainted ? ' • FAINTED' : (mon.status != StatusCondition.none ? ' • ${mon.status.shortLabel}' : '')}",
                                  style: TextStyle(
                                    color: mon.isFainted
                                        ? PokeColors.pokeRed
                                        : PokeColors.inkMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  mon.level >= 100
                                      ? "MAX LEVEL"
                                      : "Next Lv: $expRemaining EXP",
                                  style: const TextStyle(
                                    color: PokeColors.pokeBlueDark,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: expProgress,
                                minHeight: 4,
                                backgroundColor: PokeColors.panelSoft,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    PokeColors.pokeBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── TABS ─────────────────────────────────────────────────
                Container(
                  color: typeHeader,
                  child: const TabBar(
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                    tabs: [
                      Tab(text: "STATS & INFO"),
                      Tab(text: "HELD ITEM"),
                      Tab(text: "MOVES"),
                    ],
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    children: [
                      _buildStatsTab(trainer, mon, expRemaining),
                      _buildHeldItemTab(trainer, mon),
                      _buildMovesTab(trainer, mon),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTab(
      Trainer trainer, PokemonInstance mon, int expRemaining) {
    final bool obeys = mon.level <= trainer.maxObedienceLevel;
    final ability = mon.abilityDefinition;
    final stats = [
      ('hp', 'HP', mon.maxHp, mon.species.baseHp, mon.hpIv, PokeColors.pokeGreen),
      ('atk', 'Attack', mon.atk, mon.species.baseAtk, mon.atkIv, PokeColors.pokeRed),
      ('def', 'Defense', mon.def, mon.species.baseDef, mon.defIv, PokeColors.bagOrange),
      ('spa', 'Sp. Atk', mon.spa, mon.species.baseSpA, mon.spaIv, PokeColors.pokeBlue),
      ('spd', 'Sp. Def', mon.spd, mon.species.baseSpD, mon.spdIv, PokeColors.linkTeal),
      ('spe', 'Speed', mon.spe, mon.species.baseSpe, mon.speIv, const Color(0xFF7B1FA2)),
    ];
    final originDisplay =
        GameRegionExtension.fromStorageKey(mon.originRegion).displayName;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: PokeDecorations.card(
            fill: PokeColors.cardWhite,
            border: mon.isHiddenAbility
                ? PokeColors.badgeGoldDark
                : PokeColors.pokeBlue,
            radius: 16,
            borderWidth: 1.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: mon.isHiddenAbility
                        ? PokeColors.badgeGoldDark
                        : PokeColors.pokeBlue,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    "ABILITY",
                    style: TextStyle(
                      color: PokeColors.inkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const Spacer(),
                  if (mon.isHiddenAbility)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: PokeColors.badgeGold.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: PokeColors.badgeGoldDark,
                        ),
                      ),
                      child: const Text(
                        "HIDDEN ABILITY",
                        style: TextStyle(
                          color: PokeColors.badgeGoldDark,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                ability?.name ?? mon.abilityId,
                style: TextStyle(
                  color: mon.isHiddenAbility
                      ? PokeColors.badgeGoldDark
                      : PokeColors.inkDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (ability != null) ...[
                const SizedBox(height: 4),
                Text(
                  ability.description,
                  style: const TextStyle(
                    color: PokeColors.inkMuted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: PokeDecorations.card(
                  fill: PokeColors.cardWhite,
                  border: PokeColors.frameBorderSoft,
                  radius: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "NATURE",
                      style: TextStyle(
                        color: PokeColors.inkMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mon.nature.displayName,
                      style: const TextStyle(
                        color: PokeColors.inkDark,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      mon.nature.shortEffectLabel,
                      style: const TextStyle(
                        color: PokeColors.pokeBlueDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: PokeDecorations.card(
                  fill: PokeColors.cardWhite,
                  border: PokeColors.frameBorderSoft,
                  radius: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "FRIENDSHIP",
                          style: TextStyle(
                            color: PokeColors.inkMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        Icon(
                          Icons.favorite_rounded,
                          size: 13,
                          color: mon.friendship >= 220
                              ? PokeColors.centerRoseDark
                              : PokeColors.centerRose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "${mon.friendship} / 255",
                      style: const TextStyle(
                        color: PokeColors.inkDark,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (mon.friendship / 255.0).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: PokeColors.panelSoft,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          mon.friendship >= 220
                              ? PokeColors.centerRoseDark
                              : PokeColors.centerRose,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: PokeDecorations.card(
            fill: PokeColors.cardWhite,
            border: PokeColors.frameBorderSoft,
            radius: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "BATTLE STATS",
                    style: TextStyle(
                      color: PokeColors.inkDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.9,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: mon.ivTotal >= 151
                          ? PokeColors.badgeGold.withOpacity(0.20)
                          : PokeColors.panelSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "IVs ${mon.ivTotal}/186 • ${mon.ivRatingLabel}",
                      style: TextStyle(
                        color: mon.ivTotal >= 151
                            ? PokeColors.badgeGoldDark
                            : PokeColors.inkMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...stats.map((s) {
                final String key = s.$1;
                final String label = s.$2;
                final int val = s.$3;
                final int baseVal = s.$4;
                final int iv = s.$5;
                final Color color = s.$6;
                final bool isUp = mon.nature.increasedStat == key;
                final bool isDown = mon.nature.decreasedStat == key;
                final double ratio = (val / 280.0).clamp(0.06, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          isUp ? "$label ▲" : (isDown ? "$label ▼" : label),
                          style: TextStyle(
                            color: isUp
                                ? PokeColors.pokeRedDark
                                : (isDown
                                    ? PokeColors.pokeBlueDark
                                    : PokeColors.inkMuted),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          "$val",
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 7,
                            backgroundColor: PokeColors.panelSoft,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        width: 38,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: iv == 31
                              ? PokeColors.badgeGold.withOpacity(0.20)
                              : PokeColors.panelSoft,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          "IV $iv",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: iv == 31
                                ? PokeColors.badgeGoldDark
                                : PokeColors.inkMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 44,
                        child: Text(
                          "B $baseVal",
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: PokeColors.inkSubtle,
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: PokeDecorations.card(
            fill: PokeColors.cardWhite,
            border: PokeColors.frameBorderSoft,
            radius: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "POKÉMON DETAILS",
                style: TextStyle(
                  color: PokeColors.inkDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 10),
              _infoRow("Species",
                  "#${mon.species.id.toString().padLeft(3, '0')} ${mon.species.name}"),
              _infoRow("Gender", mon.gender.displayName),
              _infoRow("Origin Region", originDisplay),
              _infoRow(
                "Nickname",
                mon.hasCustomNickname
                    ? "${mon.nickname} (Permanent)"
                    : "Not set",
              ),
              _infoRow(
                "Original Trainer",
                mon.originalTrainerDisplay(fallbackName: trainer.name),
              ),
              _infoRow(
                "Location",
                widget.partyIndex != null
                    ? "Party (#${widget.partyIndex! + 1})"
                    : "PC Box ${widget.pcBoxIndex! + 1} • Slot ${widget.pcSlotIndex! + 1}",
              ),
              _infoRow("Caught In",
                  ItemDatabase.byId(mon.caughtBall)?.name ?? 'Poké Ball'),
              _infoRow("Rarity Tier", mon.species.rarity.displayName),
              _infoRow("Total EXP", "${mon.currentExp}"),
              _infoRow("EXP to Next Level",
                  mon.level >= 100 ? "MAX (Lv. 100)" : "$expRemaining EXP"),
              _infoRow("Evolution", _evolutionSummary(mon.species)),
              _infoRow(
                "Obedience",
                obeys
                    ? "Obeys all orders (Cap Lv.${trainer.maxObedienceLevel})"
                    : "May disobey! Requires more Badges (Cap Lv.${trainer.maxObedienceLevel})",
                valueColor:
                    obeys ? PokeColors.pokeGreenDark : PokeColors.bagOrangeDark,
              ),
              _infoRow(
                "Total PP",
                "${mon.moves.fold<int>(0, (s, m) => s + m.currentPp)} / ${mon.moves.fold<int>(0, (s, m) => s + m.maxPp)}",
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(color: PokeColors.inkMuted, fontSize: 11.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? PokeColors.inkDark,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeldItemTab(Trainer trainer, PokemonInstance mon) {
    final Item? currentHeld =
        mon.hasHeldItem ? ItemDatabase.byId(mon.heldItemId!) : null;
    final bagHoldables = ItemDatabase.allItems.values
        .where((item) =>
            (item.isBerry || item.isHeldItem) &&
            trainer.getItemCount(item.id) > 0)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: PokeDecorations.card(
            fill: PokeColors.cardWhite,
            border: currentHeld != null
                ? currentHeld.color
                : PokeColors.frameBorderSoft,
            radius: 16,
            borderWidth: 1.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "CURRENTLY HELD ITEM",
                style: TextStyle(
                  color: PokeColors.inkDark,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 10),
              if (currentHeld == null)
                const Text(
                  "None equipped. Select any Berry or Held Item below to give it to this Pokémon.",
                  style: TextStyle(color: PokeColors.inkMuted, fontSize: 12),
                )
              else
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: currentHeld.color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(currentHeld.icon,
                          color: PokeColors.darken(currentHeld.color, 0.14),
                          size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentHeld.name,
                            style: const TextStyle(
                              color: PokeColors.inkDark,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            currentHeld.description,
                            style: const TextStyle(
                                color: PokeColors.inkMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        final taken = mon.unequipHeldItem();
                        if (taken != null) {
                          trainer.adjustItemCount(taken, 1);
                          trainer.saveProgress();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PokeColors.pokeRed,
                        side: const BorderSide(color: PokeColors.pokeRed),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      child: const Text(
                        "TAKE",
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          "BAG HELD ITEMS & BERRIES",
          style: TextStyle(
            color: PokeColors.inkMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        if (bagHoldables.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: PokeDecorations.card(
              fill: PokeColors.creamSurface,
              border: PokeColors.frameBorderSoft,
              radius: 14,
            ),
            child: const Text(
              "No Berries or Held Items in your Bag right now.\nDefeat or catch wild Pokémon for Berries, or re-challenge Gym Leaders for rare Held Items!",
              textAlign: TextAlign.center,
              style: TextStyle(color: PokeColors.inkMuted, fontSize: 11.5),
            ),
          )
        else
          ...bagHoldables.map((item) {
            final count = trainer.getItemCount(item.id);
            final itemDark = PokeColors.darken(item.color, 0.16);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: PokeDecorations.card(
                  border: item.color.withOpacity(0.55),
                  radius: 14,
                  borderWidth: 1.4,
                ),
                child: Row(
                  children: [
                    Icon(item.icon, color: itemDark, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  color: PokeColors.inkDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "x$count",
                                style: TextStyle(
                                  color: itemDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: const TextStyle(
                                color: PokeColors.inkMuted, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final old = mon.unequipHeldItem();
                        if (old != null) {
                          trainer.adjustItemCount(old, 1);
                        }
                        mon.equipHeldItem(item.id);
                        trainer.adjustItemCount(item.id, -1);
                        trainer.saveProgress();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text("${mon.nickname} is now holding ${item.name}!"),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: itemDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        "GIVE",
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMovesTab(Trainer trainer, PokemonInstance mon) {
    final reserveMoves = mon.rememberedReserveMoves;
    final ownedTms = TmService.allTms
        .where((tm) => trainer.getItemCount(tm.id) > 0)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "ACTIVE MOVESET (${mon.moves.length}/4)",
              style: const TextStyle(
                color: PokeColors.inkDark,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
            ),
            const Text(
              "Reorder or swap below",
              style: TextStyle(color: PokeColors.inkMuted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(mon.moves.length, (idx) {
          final m = mon.moves[idx];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              decoration: PokeDecorations.card(
                border: m.type.color,
                radius: 14,
                borderWidth: 1.4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: PokeColors.inkDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            TypeBadge(type: m.type),
                            if (EggMoveService.isEggMoveForSpecies(
                                mon.species, m.id)) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color:
                                      PokeColors.centerRose.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(5),
                                  border:
                                      Border.all(color: PokeColors.centerRose),
                                ),
                                child: const Text(
                                  "EGG",
                                  style: TextStyle(
                                    color: PokeColors.centerRoseDark,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(width: 5),
                            Text(
                              _categoryTag(m.category),
                              style: TextStyle(
                                color: _categoryColor(m.category),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "PWR ${m.powerLabel} • ACC ${m.accuracy}% • PP ${m.currentPp}/${m.maxPp}",
                          style: const TextStyle(
                              color: PokeColors.inkDark,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                        Text(
                          m.description,
                          style: const TextStyle(
                              color: PokeColors.inkMuted, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (idx > 0)
                        InkWell(
                          onTap: () {
                            mon.swapMoveSlots(idx, idx - 1);
                            trainer.saveProgress();
                            trainer.notifyListeners();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.keyboard_arrow_up_rounded,
                                color: PokeColors.inkMuted, size: 18),
                          ),
                        ),
                      if (idx < mon.moves.length - 1)
                        InkWell(
                          onTap: () {
                            mon.swapMoveSlots(idx, idx + 1);
                            trainer.saveProgress();
                            trainer.notifyListeners();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.keyboard_arrow_down_rounded,
                                color: PokeColors.inkMuted, size: 18),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 12),
        Text(
          "REMEMBERED & LEARNABLE MOVES (${reserveMoves.length})",
          style: const TextStyle(
            color: PokeColors.pokeBlueDark,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          "Includes all level-up moves up to Lv. ${mon.level}, pre-evolution moves, and TMs — swap freely anytime.",
          style: const TextStyle(color: PokeColors.inkMuted, fontSize: 10.5),
        ),
        const SizedBox(height: 8),
        if (reserveMoves.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: PokeDecorations.card(
              fill: PokeColors.creamSurface,
              border: PokeColors.frameBorderSoft,
              radius: 14,
            ),
            child: Text(
              "All moves unlocked up to Lv. ${mon.level} are already equipped above. New moves will appear here as this Pokémon levels up or learns TMs.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: PokeColors.inkMuted, fontSize: 11),
            ),
          )
        else
          ...reserveMoves.map((rm) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: PokeDecorations.card(
                  border: rm.type.color.withOpacity(0.6),
                  radius: 13,
                  borderWidth: 1.3,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  rm.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: PokeColors.inkDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              TypeBadge(type: rm.type),
                              if (EggMoveService.isEggMoveForSpecies(
                                  mon.species, rm.id)) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color:
                                        PokeColors.centerRose.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(5),
                                    border:
                                        Border.all(color: PokeColors.centerRose),
                                  ),
                                  child: const Text(
                                    "EGG",
                                    style: TextStyle(
                                      color: PokeColors.centerRoseDark,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "PWR ${rm.powerLabel} • ACC ${rm.accuracy}% • PP ${rm.maxPp}",
                            style: const TextStyle(
                                color: PokeColors.inkDark,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                          Text(
                            rm.description,
                            style: const TextStyle(
                                color: PokeColors.inkMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () =>
                          _promptSwapRememberedMove(trainer, mon, rm),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PokeColors.pokeBlueDark,
                        side: const BorderSide(color: PokeColors.pokeBlue),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        mon.moves.length < 4 ? "EQUIP" : "SWAP IN",
                        style: const TextStyle(
                            fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 14),
        Text(
          "TEACH GEN 1 TM FROM BAG (${ownedTms.length})",
          style: const TextStyle(
            color: PokeColors.badgeGoldDark,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        if (ownedTms.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: PokeDecorations.card(
              fill: PokeColors.creamSurface,
              border: PokeColors.frameBorderSoft,
              radius: 14,
            ),
            child: const Text(
              "No Gen 1 TMs in your Bag yet. Re-challenge cleared Gym Leaders in the Pokémon League to earn rare TM drops!",
              textAlign: TextAlign.center,
              style: TextStyle(color: PokeColors.inkMuted, fontSize: 11),
            ),
          )
        else
          ...ownedTms.map((tm) {
            final tmMove = TmService.getMoveForTm(tm);
            if (tmMove == null) return const SizedBox.shrink();
            final bool compatible = TmService.canLearnTm(mon.species, tm);
            final bool alreadyActive =
                mon.moves.any((m) => m.id == tmMove.id);
            final bool alreadyLearned =
                mon.learnedMoveIds.contains(tmMove.id);
            final tmDark = PokeColors.darken(tm.color, 0.16);

            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Opacity(
                opacity: compatible && !alreadyLearned ? 1.0 : 0.60,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: PokeDecorations.card(
                    border: tmDark.withOpacity(0.5),
                    radius: 13,
                    borderWidth: 1.3,
                  ),
                  child: Row(
                    children: [
                      Icon(tm.icon, color: tmDark, size: 22),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    tm.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: PokeColors.inkDark,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: PokeDecorations.inset(radius: 5),
                                  child: Text(
                                    "∞",
                                    style: TextStyle(
                                      color: tmDark,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                TypeBadge(type: tmMove.type),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              compatible
                                  ? (alreadyActive
                                      ? "Already in active moveset"
                                      : (alreadyLearned
                                          ? "Already remembered — swap in above for free!"
                                          : "PWR ${tmMove.powerLabel} • ACC ${tmMove.accuracy}% • PP ${tmMove.maxPp}"))
                                  : "${mon.species.name} cannot learn ${tmMove.name}",
                              style: const TextStyle(
                                  color: PokeColors.inkMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: (compatible && !alreadyLearned)
                            ? () => _teachTmToPokemon(trainer, mon, tm, tmMove)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tmDark,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: PokeColors.panelSoft,
                          disabledForegroundColor: PokeColors.inkSubtle,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: Text(
                          alreadyLearned
                              ? "KNOWN"
                              : (compatible ? "TEACH" : "N/A"),
                          style: const TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
