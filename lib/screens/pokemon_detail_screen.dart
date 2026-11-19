import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
import '../services/tm_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/move_learn_dialog.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/type_badge.dart';

class PokemonDetailScreen extends StatefulWidget {
  final int partyIndex;

  const PokemonDetailScreen({
    super.key,
    required this.partyIndex,
  });

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> {
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
        return Colors.orangeAccent;
      case MoveCategory.special:
        return Colors.lightBlueAccent;
      case MoveCategory.status:
        return Colors.purpleAccent;
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
        backgroundColor: const Color(0xFF141828),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: reserveMove.type.color.withOpacity(0.55)),
        ),
        title: Text(
          "Swap in ${reserveMove.name}",
          style: const TextStyle(
            color: Colors.white,
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
                    color: Colors.white70, fontSize: 11.5, height: 1.3),
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
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D2338),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: cur.type.color.withOpacity(0.45)),
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
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
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
                                    color: Colors.white60,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.swap_horiz_rounded,
                              color: Colors.amberAccent, size: 20),
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
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white60)),
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
          "Use 1x ${tmItem.name} to teach ${tmMove.name} to ${mon.nickname}?",
    );
    if (!outcome.learned) return;

    trainer.adjustItemCount(tmItem.id, -1);
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
        if (widget.partyIndex < 0 || widget.partyIndex >= trainer.party.length) {
          return Scaffold(
            backgroundColor: const Color(0xFF0E1220),
            appBar: AppBar(title: const Text("POKÉMON SUMMARY")),
            body: const Center(
              child: Text("Pokémon not found in party.",
                  style: TextStyle(color: Colors.white70)),
            ),
          );
        }

        final mon = trainer.party[widget.partyIndex];
        final Color typeColor = mon.species.types.first.color;
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
            backgroundColor: const Color(0xFF0C101C),
            appBar: AppBar(
              backgroundColor: const Color(0xFF101526),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                "#${mon.species.id.toString().padLeft(3, '0')} • ${mon.species.name.toUpperCase()}",
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              centerTitle: true,
              actions: [
                if (widget.partyIndex != 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: TextButton.icon(
                      onPressed: () {
                        trainer.setLeadPokemon(widget.partyIndex);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text("${mon.nickname} is now your Lead Pokémon!"),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.star_rounded,
                          color: Colors.amberAccent, size: 16),
                      label: const Text(
                        "LEAD",
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        typeColor.withOpacity(0.24),
                        const Color(0xFF13182A),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0D18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                              color: mon.isShiny
                                  ? Colors.amberAccent.withOpacity(0.85)
                                  : typeColor.withOpacity(0.65),
                              width: mon.isShiny ? 2.0 : 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: (mon.isShiny
                                      ? Colors.amberAccent
                                      : typeColor)
                                  .withOpacity(0.28),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Builder(builder: (_) {
                                final double heroSize = mon.species
                                    .scaledUiSize(72, minSize: 38);
                                return Image.network(
                                  mon.spriteUrl,
                                  width: 78,
                                  height: heroSize,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.none,
                                  errorBuilder: (_, __, ___) => Image.network(
                                    mon.staticSpriteUrl,
                                    width: 78,
                                    height: heroSize,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.none,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.catching_pokemon,
                                      color: typeColor,
                                      size: (heroSize * 0.68).clamp(24.0, 46.0),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            if (mon.isShiny)
                              const Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.amberAccent,
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
                                          Colors.amberAccent.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color:
                                            Colors.amberAccent.withOpacity(0.8),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          color: Colors.amberAccent,
                                          size: 10,
                                        ),
                                        SizedBox(width: 2),
                                        Text(
                                          "SHINY",
                                          style: TextStyle(
                                            color: Colors.amberAccent,
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
                                  child: Text(
                                    mon.nickname,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.amberAccent
                                            .withOpacity(0.55)),
                                  ),
                                  child: Text(
                                    "Lv.${mon.level}",
                                    style: const TextStyle(
                                      color: Colors.amberAccent,
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
                                        ? Colors.amberAccent
                                        : Colors.white38,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            HpBar(currentHp: mon.currentHp, maxHp: mon.maxHp),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "HP ${mon.currentHp}/${mon.maxHp}${mon.isFainted ? ' • FAINTED' : (mon.status != StatusCondition.none ? ' • ${mon.status.shortLabel}' : '')}",
                                  style: TextStyle(
                                    color: mon.isFainted
                                        ? Colors.redAccent
                                        : Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  mon.level >= 100
                                      ? "MAX LEVEL"
                                      : "Next Lv: $expRemaining EXP",
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
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
                                minHeight: 3.5,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.cyanAccent),
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
                  color: const Color(0xFF101526),
                  child: const TabBar(
                    indicatorColor: Colors.amberAccent,
                    labelColor: Colors.amberAccent,
                    unselectedLabelColor: Colors.white60,
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
    final stats = [
      ('HP', mon.maxHp, mon.species.baseHp, const Color(0xFF66BB6A)),
      ('Attack', mon.atk, mon.species.baseAtk, const Color(0xFFFF7043)),
      ('Defense', mon.def, mon.species.baseDef, const Color(0xFFFFCA28)),
      ('Sp. Atk', mon.spa, mon.species.baseSpA, const Color(0xFF42A5F5)),
      ('Sp. Def', mon.spd, mon.species.baseSpD, const Color(0xFF26C6DA)),
      ('Speed', mon.spe, mon.species.baseSpe, const Color(0xFFAB47BC)),
    ];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "BATTLE STATS",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 10),
              ...stats.map((s) {
                final String label = s.$1;
                final int val = s.$2;
                final int baseVal = s.$3;
                final Color color = s.$4;
                final double ratio = (val / 280.0).clamp(0.06, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 38,
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
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 7,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 52,
                        child: Text(
                          "Base $baseVal",
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white38,
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
          decoration: BoxDecoration(
            color: const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "POKÉMON DETAILS",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 10),
              _infoRow("Species",
                  "#${mon.species.id.toString().padLeft(3, '0')} ${mon.species.name}"),
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
                valueColor: obeys ? Colors.greenAccent : Colors.orangeAccent,
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
              style: const TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
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
          decoration: BoxDecoration(
            color: const Color(0xFF141A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: currentHeld != null
                  ? currentHeld.color.withOpacity(0.6)
                  : Colors.white12,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "CURRENTLY HELD ITEM",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 10),
              if (currentHeld == null)
                const Text(
                  "None equipped. Select any Berry or Held Item below to give it to this Pokémon.",
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                )
              else
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: currentHeld.color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(currentHeld.icon,
                          color: currentHeld.color, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentHeld.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currentHeld.description,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11),
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
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                            color: Colors.redAccent.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      child: const Text(
                        "TAKE",
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
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
            color: Colors.white60,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        if (bagHoldables.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF141A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              "No Berries or Held Items in your Bag right now.\nDefeat or catch wild Pokémon for Berries, or re-challenge Gym Leaders for rare Held Items!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
          )
        else
          ...bagHoldables.map((item) {
            final count = trainer.getItemCount(item.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF141A2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: item.color.withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, color: item.color, size: 22),
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "x$count",
                                style: TextStyle(
                                  color: item.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 10.5),
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
                        backgroundColor: item.color.withOpacity(0.22),
                        foregroundColor: item.color,
                        side: BorderSide(color: item.color.withOpacity(0.6)),
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
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
            ),
            const Text(
              "Reorder or swap below",
              style: TextStyle(color: Colors.white38, fontSize: 10),
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
              decoration: BoxDecoration(
                color: const Color(0xFF141A2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: m.type.color.withOpacity(0.55)),
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            TypeBadge(type: m.type),
                            const SizedBox(width: 5),
                            Text(
                              _categoryTag(m.category),
                              style: TextStyle(
                                color: _categoryColor(m.category),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "PWR ${m.powerLabel} • ACC ${m.accuracy}% • PP ${m.currentPp}/${m.maxPp}",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10),
                        ),
                        Text(
                          m.description,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 10),
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
                                color: Colors.white70, size: 18),
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
                                color: Colors.white70, size: 18),
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
            color: Colors.cyanAccent,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          "Includes all level-up moves up to Lv. ${mon.level}, pre-evolution moves, and TMs — swap freely anytime.",
          style: const TextStyle(color: Colors.white54, fontSize: 10.5),
        ),
        const SizedBox(height: 8),
        if (reserveMoves.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF141A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              "All moves unlocked up to Lv. ${mon.level} are already equipped above. New moves will appear here as this Pokémon levels up or learns TMs.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          )
        else
          ...reserveMoves.map((rm) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF141A2E),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: rm.type.color.withOpacity(0.35)),
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
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              TypeBadge(type: rm.type),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "PWR ${rm.powerLabel} • ACC ${rm.accuracy}% • PP ${rm.maxPp}",
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 10),
                          ),
                          Text(
                            rm.description,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () =>
                          _promptSwapRememberedMove(trainer, mon, rm),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.cyanAccent,
                        side: BorderSide(
                            color: Colors.cyanAccent.withOpacity(0.6)),
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
            color: Colors.amberAccent,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        if (ownedTms.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF141A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            child: const Text(
              "No Gen 1 TMs in your Bag yet. Re-challenge cleared Gym Leaders in the Pokémon League to earn rare TM drops!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          )
        else
          ...ownedTms.map((tm) {
            final count = trainer.getItemCount(tm.id);
            final tmMove = TmService.getMoveForTm(tm);
            if (tmMove == null) return const SizedBox.shrink();
            final bool compatible = TmService.canLearnTm(mon.species, tm);
            final bool alreadyActive =
                mon.moves.any((m) => m.id == tmMove.id);
            final bool alreadyLearned =
                mon.learnedMoveIds.contains(tmMove.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Opacity(
                opacity: compatible && !alreadyLearned ? 1.0 : 0.55,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A2E),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: tm.color.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(tm.icon, color: tm.color, size: 22),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    "${tm.name} (x$count)",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
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
                                  color: Colors.white60, fontSize: 10),
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
                          backgroundColor: tm.color.withOpacity(0.24),
                          foregroundColor: tm.color,
                          side: BorderSide(color: tm.color.withOpacity(0.6)),
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
