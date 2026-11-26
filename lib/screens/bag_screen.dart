import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_species.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
import '../services/sound_service.dart';
import '../services/tm_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/move_learn_dialog.dart';
import '../widgets/move_pp_picker_dialog.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokeball_sprite.dart';
import 'evolution_screen.dart';

class _BagPocketDef {
  final String label;
  final IconData icon;
  final Color color;
  final List<ItemCategory> categories;
  final bool includeExpShare;
  final String emptyHint;

  const _BagPocketDef({
    required this.label,
    required this.icon,
    required this.color,
    required this.categories,
    this.includeExpShare = false,
    required this.emptyHint,
  });
}

class BagScreen extends StatefulWidget {
  const BagScreen({super.key});

  @override
  State<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends State<BagScreen> {
  static const List<_BagPocketDef> _pockets = [
    _BagPocketDef(
      label: 'Medicine',
      icon: Icons.healing_rounded,
      color: PokeColors.centerRose,
      categories: [ItemCategory.medicine],
      emptyHint: 'Buy Potions, Status Healers, and Revives at the Poké Mart.',
    ),
    _BagPocketDef(
      label: 'Poké Balls',
      icon: Icons.catching_pokemon,
      color: PokeColors.pokeRed,
      categories: [ItemCategory.pokeball],
      emptyHint:
          'Stock up on Poké Balls at the Poké Mart or find Special Balls in Expeditions.',
    ),
    _BagPocketDef(
      label: 'Berries',
      icon: Icons.eco_rounded,
      color: PokeColors.pokeGreen,
      categories: [ItemCategory.berry],
      emptyHint: 'Berries can drop from Wild Encounters and Adventures.',
    ),
    _BagPocketDef(
      label: 'Held Items',
      icon: Icons.shield_rounded,
      color: PokeColors.bagOrange,
      categories: [ItemCategory.heldItem],
      emptyHint:
          'Defeat Gym Leaders and wild Pokémon to earn Held Items for your team.',
    ),
    _BagPocketDef(
      label: 'TMs',
      icon: Icons.album_rounded,
      color: PokeColors.leagueIndigo,
      categories: [ItemCategory.tm],
      emptyHint:
          'Earn reusable TMs from Gym Leaders and Team Rocket encounters.',
    ),
    _BagPocketDef(
      label: 'Key & Special',
      icon: Icons.vpn_key_rounded,
      color: PokeColors.badgeGoldDark,
      categories: [
        ItemCategory.evolutionStone,
        ItemCategory.tutorItem,
        ItemCategory.adventureMap,
        ItemCategory.fossil,
      ],
      includeExpShare: true,
      emptyHint:
          'Evolution Stones, Heart Scales, Adventure Maps, and Fossils appear here.',
    ),
  ];

  int _countPocketItems(Trainer trainer, _BagPocketDef pocket) {
    int total = 0;
    for (final item in ItemDatabase.allItems.values) {
      if (pocket.categories.contains(item.category) &&
          trainer.getItemCount(item.id) > 0) {
        total++;
      }
    }
    return total;
  }

  List<Item> _itemsForPocket(Trainer trainer, _BagPocketDef pocket) {
    final items = ItemDatabase.allItems.values
        .where((item) =>
            pocket.categories.contains(item.category) &&
            trainer.getItemCount(item.id) > 0)
        .toList();
    items.sort((a, b) {
      final catCmp = a.category.index.compareTo(b.category.index);
      if (catCmp != 0) return catCmp;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Trainer>(
      builder: (context, trainer, _) {
        return DefaultTabController(
          length: _pockets.length,
          child: Scaffold(
            backgroundColor: PokeColors.canvasCream,
            appBar: AppBar(
              backgroundColor: PokeColors.bagOrange,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 2,
              titleSpacing: 8,
              title: Row(
                children: [
                  const Icon(Icons.backpack_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'TRAINER BAG',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: PokeColors.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: PokeColors.bagOrangeDark, width: 1.3),
                    ),
                    child: Text(
                      '${trainer.totalItems} ITEMS',
                      style: const TextStyle(
                        color: PokeColors.bagOrangeDark,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Container(
                  color: PokeColors.bagOrangeDark,
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                    tabs: _pockets.map((pocket) {
                      final distinct = _countPocketItems(trainer, pocket);
                      return Tab(
                        height: 44,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(pocket.icon, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              pocket.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            if (distinct > 0) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.24),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$distinct',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            body: TabBarView(
              children: _pockets.map((pocket) {
                final items = _itemsForPocket(trainer, pocket);
                return _buildPocketList(context, trainer, pocket, items);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPocketList(
    BuildContext context,
    Trainer trainer,
    _BagPocketDef pocket,
    List<Item> items,
  ) {
    if (items.isEmpty && !pocket.includeExpShare) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: PokeDecorations.card(
              fill: PokeColors.creamSurface,
              border: PokeColors.frameBorderSoft,
              radius: 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(pocket.icon, size: 48, color: PokeColors.inkSubtle),
                const SizedBox(height: 12),
                Text(
                  'No ${pocket.label} Yet',
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  pocket.emptyHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: PokeColors.inkMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final int totalRows = items.length + (pocket.includeExpShare ? 1 : 0);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: totalRows,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (c, idx) {
        if (pocket.includeExpShare && idx == 0) {
          return _buildExpShareCard(trainer);
        }
        final item = items[pocket.includeExpShare ? idx - 1 : idx];
        return _buildItemCard(context, trainer, item);
      },
    );
  }

  Widget _buildExpShareCard(Trainer trainer) {
    final bool unlocked = trainer.hasExpShare;
    final bool active = trainer.isExpShareActive;
    if (!unlocked) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: PokeDecorations.card(
          fill: PokeColors.creamSurface,
          border: PokeColors.frameBorderSoft,
          radius: 16,
          borderWidth: 1.4,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PokeColors.panelSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: PokeColors.inkSubtle,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'EXP Share',
                        style: TextStyle(
                          color: PokeColors.inkMuted,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: PokeDecorations.inset(radius: 6),
                        child: const Text(
                          'LOCKED',
                          style: TextStyle(
                            color: PokeColors.inkSubtle,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Defeat Giovanni at Viridian Gym (8th Gym) to unlock the EXP Share.',
                    style: TextStyle(color: PokeColors.inkMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.lock_rounded,
              color: PokeColors.inkSubtle,
              size: 20,
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: active ? PokeColors.pokeBlue : PokeColors.frameBorderSoft,
        radius: 16,
        borderWidth: active ? 1.8 : 1.4,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (active ? PokeColors.pokeBlue : PokeColors.inkSubtle)
                  .withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.share_rounded,
              color: active ? PokeColors.pokeBlueDark : PokeColors.inkMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'EXP Share',
                      style: TextStyle(
                        color: PokeColors.inkDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: PokeColors.badgeGold.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PokeColors.badgeGold),
                      ),
                      child: const Text(
                        'KEY ITEM',
                        style: TextStyle(
                          color: PokeColors.badgeGoldDark,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Shares battle Experience Points across your entire carried party.',
                  style: TextStyle(color: PokeColors.inkMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: active,
            activeColor: PokeColors.pokeBlue,
            onChanged: (_) {
              SoundService.instance.playUiTap();
              trainer.toggleExpShare();
              trainer.saveProgress();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Trainer trainer, Item item) {
    final int count = trainer.getItemCount(item.id);
    final bool canDiscard = !item.isTm &&
        !item.isAdventureMap &&
        !item.isFossil &&
        !item.isTutorItem;
    final Color itemDark = PokeColors.darken(item.color, 0.16);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: item.color.withOpacity(0.55),
        radius: 16,
        borderWidth: 1.4,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: item.color.withOpacity(0.45)),
            ),
            child: Center(
              child: item.isBall
                  ? PokeBallSpriteWidget(ballType: item.id, size: 30)
                  : Icon(item.icon, color: itemDark, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                          color: PokeColors.inkDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: itemDark.withOpacity(0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        item.rarity.name.toUpperCase(),
                        style: TextStyle(
                          color: itemDark,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: PokeDecorations.inset(radius: 8),
                      child: Text(
                        item.isTm
                            ? '∞'
                            : (item.isAdventureMap ? 'UNLOCKED' : 'x$count'),
                        style: TextStyle(
                          color: count > 0 ? itemDark : PokeColors.inkSubtle,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: const TextStyle(
                      color: PokeColors.inkMuted, fontSize: 11),
                ),
                if (item.isMedicine || item.id == 'leppa_berry') ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 30,
                    child: ElevatedButton(
                      onPressed: count > 0
                          ? () => _useBagMedicineOnPartyPokemon(
                                context,
                                trainer,
                                item,
                              )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: itemDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Use on Pokémon',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ] else if (item.isEvolutionStone) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 30,
                    child: ElevatedButton.icon(
                      onPressed: count > 0
                          ? () => _useEvolutionStone(context, trainer, item)
                          : null,
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: const Text(
                        'Evolve Pokémon',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: itemDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ] else if (item.isTm) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 30,
                    child: ElevatedButton.icon(
                      onPressed: count > 0
                          ? () => _useTmFromBag(context, trainer, item)
                          : null,
                      icon: const Icon(Icons.album_rounded, size: 14),
                      label: const Text(
                        'Teach Pokémon',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: itemDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ] else if (item.isAdventureMap) ...[
                  const SizedBox(height: 6),
                  _hintChip(
                    'Adventure Map: unlocks this Biome in Battle → Adventures',
                    PokeColors.panelSoft,
                    PokeColors.pokeGreenDark,
                  ),
                ] else if (item.isTutorItem) ...[
                  const SizedBox(height: 6),
                  _hintChip(
                    'Move Tutor currency: teach Egg Moves at Facilities → Move Tutor',
                    PokeColors.centerRose.withOpacity(0.12),
                    PokeColors.centerRoseDark,
                  ),
                ] else if (item.isFossil) ...[
                  const SizedBox(height: 6),
                  _hintChip(
                    'Research item: restore Fossils at Facilities → Pokémon Lab',
                    PokeColors.badgeGold.withOpacity(0.16),
                    PokeColors.badgeGoldDark,
                  ),
                ] else if (item.isHeldItem || item.isBerry) ...[
                  const SizedBox(height: 6),
                  _hintChip(
                    item.isBerry
                        ? 'Held item: auto-consumed in battle or equip via Pokémon'
                        : 'Held item: equip via Pokémon to boost battle power',
                    PokeColors.panelSoft,
                    PokeColors.inkMuted,
                  ),
                ],
              ],
            ),
          ),
          if (canDiscard) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Discard 1',
              onPressed: count > 0
                  ? () {
                      trainer.adjustItemCount(item.id, -1);
                      trainer.saveProgress();
                    }
                  : null,
              icon: Icon(
                Icons.delete_outline_rounded,
                color: count > 0 ? PokeColors.pokeRed : PokeColors.inkSubtle,
                size: 20,
              ),
              constraints: const BoxConstraints(),
              padding: const EdgeInsets.all(6),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hintChip(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _useEvolutionStone(
    BuildContext parentContext,
    Trainer trainer,
    Item stoneItem,
  ) {
    final compatible = trainer.party
        .where((p) =>
            ItemDatabase.getStoneEvolutionTarget(stoneItem.id, p.species.id) !=
            null)
        .toList();

    if (compatible.isEmpty) {
      ScaffoldMessenger.of(parentContext).showSnackBar(
        SnackBar(
          content: Text(
              'No Pokémon in your party can evolve using ${stoneItem.name}.'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final Color stoneDark = PokeColors.darken(stoneItem.color, 0.16);
    showDialog(
      context: parentContext,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: PokeColors.creamSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: stoneDark, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(stoneItem.icon, color: stoneDark, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Use ${stoneItem.name}',
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a party Pokémon to evolve:',
                style: TextStyle(color: PokeColors.inkMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...compatible.map((mon) {
                final targetId = ItemDatabase.getStoneEvolutionTarget(
                    stoneItem.id, mon.species.id)!;
                final targetSpecies = PokedexDatabase.species[targetId];
                return InkWell(
                  onTap: () {
                    Navigator.pop(dlgCtx);
                    if (targetSpecies == null) return;
                    _executeStoneEvolution(
                        parentContext, trainer, mon, stoneItem, targetSpecies);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: PokeDecorations.card(
                      border: stoneDark.withOpacity(0.5),
                      radius: 12,
                      borderWidth: 1.4,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: Image.network(
                            mon.spriteUrl,
                            width: 42,
                            height: 42,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => Image.network(
                              mon.staticSpriteUrl,
                              width: 42,
                              height: 42,
                              filterQuality: FilterQuality.none,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.catching_pokemon,
                                color: PokeColors.inkSubtle,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mon.nickname,
                                style: const TextStyle(
                                  color: PokeColors.inkDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Lv. ${mon.level}',
                                style: const TextStyle(
                                  color: PokeColors.inkMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward,
                            color: PokeColors.inkSubtle, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          targetSpecies?.name ?? '???',
                          style: TextStyle(
                            color: stoneDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel',
                  style: TextStyle(color: PokeColors.inkMuted)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _executeStoneEvolution(
    BuildContext parentContext,
    Trainer trainer,
    PokemonInstance mon,
    Item stoneItem,
    PokemonSpecies nextSpecies,
  ) async {
    if (trainer.getItemCount(stoneItem.id) <= 0) return;
    trainer.adjustItemCount(stoneItem.id, -1);
    final fromSpecies = mon.species;
    final oldName = mon.nickname;
    final List<Move> pendingEvoMoves = [];
    final evoMoves = mon.evolve(
      nextSpecies,
      PokedexDatabase.movesUnlockedAtExactLevel(nextSpecies, mon.level),
      pendingMovesOut: pendingEvoMoves,
    );
    trainer.markPokemonCaught(nextSpecies.id, isShiny: mon.isShiny);
    trainer.saveProgress();

    await EvolutionScreen.show(
      parentContext,
      fromSpecies: fromSpecies,
      toSpecies: nextSpecies,
      oldNickname: oldName,
      learnedMoves: evoMoves,
      isShiny: mon.isShiny,
    );
    if (mounted && pendingEvoMoves.isNotEmpty) {
      for (final newMove in pendingEvoMoves) {
        final outcome = await showMoveLearnDialog(
          context,
          pokemon: mon,
          newMove: newMove,
          recordOnSkip: true,
        );
        if (outcome.learned) {
          trainer.saveProgress();
        }
      }
      trainer.saveProgress();
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _useBagMedicineOnPartyPokemon(
    BuildContext parentContext,
    Trainer trainer,
    Item medicineItem,
  ) {
    final Color medDark = PokeColors.darken(medicineItem.color, 0.16);
    showDialog(
      context: parentContext,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: PokeColors.creamSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: medDark, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(medicineItem.icon, color: medDark, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'USE ${medicineItem.name.toUpperCase()} ON:',
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: trainer.party.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, idx) {
                final mon = trainer.party[idx];
                final bool usable =
                    ItemDatabase.canUseMedicineOn(medicineItem.id, mon);
                final bool isPpItem =
                    ItemDatabase.isPpRestoreItem(medicineItem.id);
                final int curPp =
                    mon.moves.fold<int>(0, (s, m) => s + m.currentPp);
                final int maxPp =
                    mon.moves.fold<int>(0, (s, m) => s + m.maxPp);

                return InkWell(
                  onTap: usable
                      ? () async {
                          int? moveIndex;
                          if (ItemDatabase.isSingleMovePpItem(
                              medicineItem.id)) {
                            moveIndex = await showMovePpPickerDialog(
                              dlgCtx,
                              pokemon: mon,
                              item: medicineItem,
                            );
                            if (moveIndex == null) return;
                          }
                          final String msg =
                              ItemDatabase.applyMedicineToPokemon(
                            itemId: medicineItem.id,
                            targetMon: mon,
                            moveIndex: moveIndex,
                          );
                          trainer.adjustItemCount(medicineItem.id, -1);
                          trainer.saveProgress();
                          if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                          if (mounted) setState(() {});
                          if (parentContext.mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Opacity(
                    opacity: usable ? 1.0 : 0.45,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: PokeDecorations.card(
                        fill: PokeColors.cardWhite,
                        border: usable
                            ? medDark.withOpacity(0.65)
                            : PokeColors.frameBorderSoft,
                        radius: 12,
                        borderWidth: 1.4,
                      ),
                      child: Row(
                        children: [
                          Image.network(
                            mon.spriteUrl,
                            width: 38,
                            height: 38,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.catching_pokemon,
                              color: PokeColors.inkSubtle,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${mon.nickname} • Lv.${mon.level}',
                                  style: const TextStyle(
                                    color: PokeColors.inkDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                HpBar(
                                  currentHp: mon.currentHp,
                                  maxHp: mon.maxHp,
                                  textColor: PokeColors.inkMuted,
                                  hpLabelColor: PokeColors.badgeGoldDark,
                                ),
                                Text(
                                  isPpItem
                                      ? 'PP $curPp/$maxPp • HP ${mon.currentHp}/${mon.maxHp}'
                                      : "HP ${mon.currentHp}/${mon.maxHp}${mon.status != StatusCondition.none ? ' • ${mon.status.shortLabel}' : ''}",
                                  style: const TextStyle(
                                    color: PokeColors.inkMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            usable ? 'USE' : 'N/A',
                            style: TextStyle(
                              color: usable ? medDark : PokeColors.inkSubtle,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancel',
                  style: TextStyle(color: PokeColors.inkMuted)),
            ),
          ],
        );
      },
    );
  }

  void _useTmFromBag(
    BuildContext parentContext,
    Trainer trainer,
    Item tmItem,
  ) {
    final tmMove = TmService.getMoveForTm(tmItem);
    if (tmMove == null) return;
    final Color tmDark = PokeColors.darken(tmItem.color, 0.16);

    showDialog(
      context: parentContext,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: tmDark, width: 1.5),
        ),
        title: Row(
          children: [
            Icon(tmItem.icon, color: tmDark, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Teach ${tmItem.name}',
                style: const TextStyle(
                  color: PokeColors.inkDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dlgCtx).size.height * 0.48,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: trainer.party.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, idx) {
                final mon = trainer.party[idx];
                final compatible = TmService.canLearnTm(mon.species, tmItem);
                final known = mon.learnedMoveIds.contains(tmMove.id);
                final canTeach = compatible && !known;
                return InkWell(
                  onTap: canTeach
                      ? () async {
                          Navigator.pop(dlgCtx);
                          final outcome = await showMoveLearnDialog(
                            context,
                            pokemon: mon,
                            newMove: tmMove,
                            recordOnSkip: false,
                            headerNote:
                                'Teach ${tmMove.name} to ${mon.nickname} using ${tmItem.name}? (Reusable)',
                          );
                          if (outcome.learned) {
                            trainer.saveProgress();
                            trainer.notifyListeners();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    outcome.forgottenMove != null
                                        ? '${mon.nickname} forgot ${outcome.forgottenMove!.name} and learned ${tmMove.name}!'
                                        : '${mon.nickname} learned ${tmMove.name}!',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Opacity(
                    opacity: canTeach ? 1.0 : 0.45,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: PokeDecorations.card(
                        fill: PokeColors.cardWhite,
                        border: canTeach
                            ? tmDark.withOpacity(0.65)
                            : PokeColors.frameBorderSoft,
                        radius: 12,
                        borderWidth: 1.4,
                      ),
                      child: Row(
                        children: [
                          Image.network(
                            mon.spriteUrl,
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.catching_pokemon,
                              color: PokeColors.inkSubtle,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${mon.nickname} • Lv.${mon.level}',
                                  style: const TextStyle(
                                    color: PokeColors.inkDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                                Text(
                                  known
                                      ? 'Already learned ${tmMove.name}'
                                      : (compatible
                                          ? 'Compatible'
                                          : 'Not compatible'),
                                  style: TextStyle(
                                    color: canTeach
                                        ? PokeColors.pokeGreenDark
                                        : PokeColors.inkMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            known ? 'KNOWN' : (compatible ? 'TEACH' : 'N/A'),
                            style: TextStyle(
                              color: canTeach ? tmDark : PokeColors.inkSubtle,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Cancel',
                style: TextStyle(color: PokeColors.inkMuted)),
          ),
        ],
      ),
    );
  }
}
