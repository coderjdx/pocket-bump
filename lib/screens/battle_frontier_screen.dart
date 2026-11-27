import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/ability.dart';
import '../models/game_region.dart';
import '../models/item.dart';
import '../models/pokemon_gender.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_nature.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/battle_frontier_database.dart';
import '../services/sound_service.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokemon_head_portrait.dart';
import '../widgets/pokemon_sprite_image.dart';
import '../widgets/trainer_sprite.dart';
import '../widgets/type_badge.dart';
import 'battle_screen.dart';
import 'double_battle_screen.dart';

class BattleFrontierScreen extends StatefulWidget {
  const BattleFrontierScreen({super.key});

  @override
  State<BattleFrontierScreen> createState() => _BattleFrontierScreenState();
}

class _BattleFrontierScreenState extends State<BattleFrontierScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedFrontierBox = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _launchBattleTower(Trainer trainer, {required bool isDoubles}) async {
    final int minRequired = isDoubles ? 2 : 1;
    if (trainer.frontierParty.length < minRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDoubles
                ? 'Battle Tower Doubles requires at least 2 Pokémon in your Frontier Party!'
                : 'Add at least 1 Pokémon to your Frontier Party in the PC & Team tab!',
          ),
        ),
      );
      _tabController.animateTo(1);
      return;
    }

    SoundService.instance.playUiTap();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FrontierTowerRunScreen(isDoubles: isDoubles),
      ),
    );
  }

  Future<void> _launchBattleFactory({required bool isDoubles}) async {
    SoundService.instance.playUiTap();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FrontierFactoryRunScreen(isDoubles: isDoubles),
      ),
    );
  }

  Future<void> _openRegionalImportSheet(Trainer trainer) async {
    final unlocked = GameRegion.values
        .where((r) => trainer.canTransferRegionToFrontier(r))
        .toList();
    if (unlocked.isEmpty) return;

    GameRegion selectedRegion = unlocked.contains(trainer.activeRegion)
        ? trainer.activeRegion
        : unlocked.first;
    int selectedBox = 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final regionSave = trainer.saveForRegion(selectedRegion);
          final boxList = regionSave.pcBoxes[selectedBox];

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PokeSheetHeader(
                      icon: Icons.move_to_inbox_rounded,
                      accentColor: PokeColors.leagueIndigo,
                      title: 'IMPORT TO FRONTIER PC',
                      subtitle: 'Select an unlocked region PC box to transfer',
                      onClose: () => Navigator.pop(ctx),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: unlocked.map((reg) {
                        final active = reg == selectedRegion;
                        return ChoiceChip(
                          label: Text(
                            '${reg.displayName} PC',
                            style: TextStyle(
                              color: active ? Colors.white : PokeColors.inkDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 11.5,
                            ),
                          ),
                          selected: active,
                          selectedColor: reg.accentColor,
                          backgroundColor: PokeColors.cardWhite,
                          onSelected: (_) {
                            setSheetState(() {
                              selectedRegion = reg;
                              selectedBox = 0;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: Trainer.numPcBoxes,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, idx) {
                          final sel = idx == selectedBox;
                          final cnt = regionSave.pcBoxes[idx].length;
                          return ChoiceChip(
                            label: Text(
                              'Box ${idx + 1} ($cnt)',
                              style: TextStyle(
                                color: sel ? Colors.white : PokeColors.inkDark,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            selected: sel,
                            selectedColor: PokeColors.leagueIndigo,
                            backgroundColor: PokeColors.cardWhite,
                            onSelected: (_) =>
                                setSheetState(() => selectedBox = idx),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: boxList.isEmpty
                          ? const Center(
                              child: Text(
                                'No Pokémon stored in this regional PC Box.',
                                style: TextStyle(
                                  color: PokeColors.inkMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: boxList.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 7),
                              itemBuilder: (_, idx) {
                                final mon = boxList[idx];
                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: PokeDecorations.card(
                                    fill: PokeColors.cardWhite,
                                    border: PokeColors.frameBorderSoft,
                                    radius: 13,
                                  ),
                                  child: Row(
                                    children: [
                                      PokemonHeadPortrait(
                                        pokemon: mon,
                                        size: 40,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                              '${mon.nature.displayName} • Origin: ${selectedRegion.displayName}',
                                              style: const TextStyle(
                                                color: PokeColors.inkMuted,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton(
                                        onPressed: () {
                                          final ok = trainer
                                              .transferPcPokemonToFrontier(
                                            selectedRegion,
                                            selectedBox,
                                            idx,
                                          );
                                          if (ok) {
                                            SoundService.instance.playUiTap();
                                            setSheetState(() {});
                                            setState(() {});
                                          } else {
                                            ScaffoldMessenger.of(ctx)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Frontier PC Storage is full!',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              PokeColors.leagueIndigo,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(9),
                                          ),
                                        ),
                                        child: const Text(
                                          'IMPORT',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showFrontierPokemonSheet(
    Trainer trainer,
    PokemonInstance mon, {
    int? partyIndex,
    int? boxIndex,
    int? slotIndex,
  }) async {
    final originRegion = GameRegionExtension.fromStorageKey(mon.originRegion);
    final abName = AbilityDatabase.all[mon.abilityId]?.name ?? mon.abilityId;
    final heldName = mon.heldItemId != null
        ? (ItemDatabase.byId(mon.heldItemId!)?.name ?? mon.heldItemId!)
        : 'None';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    PokemonSpriteImage.fromInstance(
                      mon,
                      width: 68,
                      height: 68,
                      fallbackIconColor: mon.species.types.first.color,
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
                                  '${mon.nickname} ${mon.gender.symbol}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: PokeColors.inkDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: originRegion.accentColor,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  originRegion.displayName.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Lv.${mon.level} ${mon.species.name} • ${mon.nature.displayName} (${mon.nature.shortEffectLabel})',
                            style: const TextStyle(
                              color: PokeColors.inkMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: mon.species.types
                                .map((t) => Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: TypeBadge(type: t),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: PokeDecorations.inset(radius: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ability: $abName${mon.abilitySlot == 3 ? ' (Hidden)' : ''} • Held Item: $heldName',
                        style: const TextStyle(
                          color: PokeColors.inkDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Stats: HP ${mon.maxHp} | Atk ${mon.atk} | Def ${mon.def} | SpA ${mon.spa} | SpD ${mon.spd} | Spe ${mon.spe}',
                        style: const TextStyle(
                          color: PokeColors.inkMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'IVs: ${mon.hpIv}/${mon.atkIv}/${mon.defIv}/${mon.spaIv}/${mon.spdIv}/${mon.speIv}',
                        style: const TextStyle(
                          color: PokeColors.leagueIndigo,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: mon.moves
                      .map((m) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: PokeDecorations.card(
                              fill: PokeColors.cardWhite,
                              border: m.type.color.withOpacity(0.65),
                              radius: 9,
                              borderWidth: 1.2,
                            ),
                            child: Text(
                              m.name,
                              style: const TextStyle(
                                color: PokeColors.inkDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (partyIndex != null && partyIndex > 0)
                      ElevatedButton.icon(
                        onPressed: () {
                          trainer.setFrontierLead(partyIndex);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                        label: const Text('MAKE LEAD'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PokeColors.pokeBlue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (partyIndex != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          final ok = trainer.depositFrontierPokemon(partyIndex);
                          Navigator.pop(ctx);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Frontier PC Boxes are full!')),
                            );
                          }
                        },
                        icon: const Icon(Icons.archive_rounded, size: 16),
                        label: const Text('TO FRONTIER PC'),
                      ),
                    if (boxIndex != null && slotIndex != null)
                      ElevatedButton.icon(
                        onPressed: trainer.frontierParty.length >= 6
                            ? null
                            : () {
                                trainer.withdrawFrontierPokemon(
                                    boxIndex, slotIndex);
                                Navigator.pop(ctx);
                              },
                        icon: const Icon(Icons.group_add_rounded, size: 16),
                        label: const Text('ADD TO FRONTIER PARTY'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PokeColors.pokeGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openEquipFrontierItemDialog(trainer, mon);
                      },
                      icon: const Icon(Icons.backpack_rounded, size: 16),
                      label: Text(
                          mon.heldItemId == null ? 'EQUIP ITEM' : 'CHANGE ITEM'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.bagOrangeDark,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final bool ok = partyIndex != null
                            ? trainer
                                .returnFrontierPartyPokemonToOrigin(partyIndex)
                            : trainer.returnFrontierPokemonToOrigin(
                                boxIndex!, slotIndex!);
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? '${mon.nickname} returned safely to ${originRegion.displayName} PC!'
                                    : '${originRegion.displayName} PC Boxes are full!',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.reply_rounded, size: 16),
                      label: Text('RETURN TO ${originRegion.displayName.toUpperCase()} PC'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: originRegion.accentColor,
                        side: BorderSide(color: originRegion.accentColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openEquipFrontierItemDialog(
    Trainer trainer,
    PokemonInstance mon,
  ) async {
    final heldCandidates = trainer.frontierCustomItems.entries
        .where((e) {
          final def = ItemDatabase.byId(e.key);
          return e.value > 0 && def != null && (def.isHeldItem || def.isBerry);
        })
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PokeSheetHeader(
                icon: Icons.inventory_2_rounded,
                accentColor: PokeColors.bagOrangeDark,
                title: 'FRONTIER HELD ITEMS',
                subtitle: 'Equip a Frontier item onto ${mon.nickname}',
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 10),
              if (mon.heldItemId != null)
                ListTile(
                  leading: const Icon(Icons.remove_circle_outline,
                      color: PokeColors.pokeRed),
                  title: Text(
                    'Unequip ${ItemDatabase.byId(mon.heldItemId!)?.name ?? mon.heldItemId}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () {
                    trainer.equipFrontierItemOnPokemon(mon, null);
                    Navigator.pop(ctx);
                  },
                ),
              if (heldCandidates.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No held items in your Frontier Bag yet. Buy Focus Sash, Expert Belt, Leftovers, or Life Orb in the BP Shop!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PokeColors.inkMuted, fontSize: 12),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: heldCandidates.length,
                    itemBuilder: (_, idx) {
                      final entry = heldCandidates[idx];
                      final item = ItemDatabase.byId(entry.key)!;
                      return ListTile(
                        leading: Icon(item.icon, color: item.color),
                        title: Text(
                          '${item.name} (x${entry.value})',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            trainer.equipFrontierItemOnPokemon(mon, item.id);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PokeColors.bagOrangeDark,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('EQUIP',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTrainingTargetPicker(
    Trainer trainer,
    String mode,
  ) async {
    final allMons = <PokemonInstance>[
      ...trainer.frontierParty,
      for (final b in trainer.frontierPcBoxes) ...b,
    ];
    if (allMons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Import a Pokémon into the Battle Frontier PC or Party first!'),
        ),
      );
      return;
    }

    PokemonInstance? picked;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.65,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                PokeSheetHeader(
                  icon: Icons.fitness_center_rounded,
                  accentColor: PokeColors.leagueIndigo,
                  title: 'SELECT FRONTIER POKÉMON',
                  subtitle: 'Choose a Pokémon to train',
                  onClose: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: allMons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, idx) {
                      final mon = allMons[idx];
                      final ab =
                          AbilityDatabase.all[mon.abilityId]?.name ?? mon.abilityId;
                      return ListTile(
                        tileColor: PokeColors.cardWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                              color: PokeColors.frameBorderSoft),
                        ),
                        leading: PokemonHeadPortrait(pokemon: mon, size: 38),
                        title: Text(
                          '${mon.nickname} • Lv.${mon.level}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        subtitle: Text(
                          '${mon.nature.displayName} • $ab • IVs ${mon.hpIv}/${mon.atkIv}/${mon.defIv}/${mon.spaIv}/${mon.spdIv}/${mon.speIv}',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        onTap: () {
                          picked = mon;
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (picked == null || !mounted) return;
    final mon = picked!;
    if (mode == 'mint') {
      await _openNatureMintDialog(trainer, mon);
    } else if (mode == 'cap') {
      await _openBottleCapDialog(trainer, mon);
    } else if (mode == 'gold_cap') {
      if (trainer.frontierBattlePoints < BattleFrontierDatabase.goldBottleCapCostBp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough BP (requires 50 BP)!')),
        );
        return;
      }
      if (!mon.hyperTrainAll()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${mon.nickname} already has 31 in all IVs!')),
        );
        return;
      }
      trainer.spendBattlePoints(BattleFrontierDatabase.goldBottleCapCostBp);
      trainer.saveProgress();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Gold Bottle Cap applied! ${mon.nickname}\'s IVs are now 31/31/31/31/31/31!'),
        ),
      );
    } else if (mode == 'patch') {
      if (trainer.frontierBattlePoints < BattleFrontierDatabase.abilityPatchCostBp) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough BP (requires 40 BP)!')),
        );
        return;
      }
      final prevName = AbilityDatabase.all[mon.abilityId]?.name ?? mon.abilityId;
      if (!mon.applyAbilityPatch()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${mon.nickname} has no alternate or Hidden Ability to switch to!')),
        );
        return;
      }
      trainer.spendBattlePoints(BattleFrontierDatabase.abilityPatchCostBp);
      trainer.saveProgress();
      final newName = AbilityDatabase.all[mon.abilityId]?.name ?? mon.abilityId;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Ability Patch used on ${mon.nickname}: $prevName → $newName!'),
        ),
      );
    }
  }

  Future<void> _openNatureMintDialog(
    Trainer trainer,
    PokemonInstance mon,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.68,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                PokeSheetHeader(
                  icon: Icons.eco_rounded,
                  accentColor: PokeColors.pokeGreen,
                  title: 'NATURE MINT (25 BP)',
                  subtitle:
                      'Current: ${mon.nature.displayName} (${mon.nature.shortEffectLabel})',
                  onClose: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: PokemonNature.values.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (_, idx) {
                      final nat = PokemonNature.values[idx];
                      final isCur = nat == mon.nature;
                      return ListTile(
                        tileColor: isCur
                            ? PokeColors.panelSoft
                            : PokeColors.cardWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                          side: BorderSide(
                            color: isCur
                                ? PokeColors.pokeGreen
                                : PokeColors.frameBorderSoft,
                          ),
                        ),
                        title: Text(
                          '${nat.displayName} Mint',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                        subtitle: Text(nat.shortEffectLabel),
                        trailing: isCur
                            ? const Text('ACTIVE',
                                style: TextStyle(
                                    color: PokeColors.pokeGreenDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.5))
                            : ElevatedButton(
                                onPressed: trainer.frontierBattlePoints <
                                        BattleFrontierDatabase.natureMintCostBp
                                    ? null
                                    : () {
                                        trainer.spendBattlePoints(
                                            BattleFrontierDatabase
                                                .natureMintCostBp);
                                        mon.applyNatureMint(nat);
                                        trainer.saveProgress();
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                '${mon.nickname}\'s stats changed to ${nat.displayName} (${nat.shortEffectLabel})!'),
                                          ),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PokeColors.pokeGreen,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('25 BP'),
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openBottleCapDialog(
    Trainer trainer,
    PokemonInstance mon,
  ) async {
    final stats = [
      ('hp', 'HP', mon.hpIv),
      ('atk', 'Attack', mon.atkIv),
      ('def', 'Defense', mon.defIv),
      ('spa', 'Sp. Atk', mon.spaIv),
      ('spd', 'Sp. Def', mon.spdIv),
      ('spe', 'Speed', mon.speIv),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PokeSheetHeader(
                icon: Icons.star_rounded,
                accentColor: PokeColors.badgeGoldDark,
                title: 'BOTTLE CAP (20 BP)',
                subtitle: 'Hyper Train 1 IV of ${mon.nickname} to 31',
                onClose: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 10),
              for (final s in stats)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    tileColor: PokeColors.cardWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                      side: const BorderSide(color: PokeColors.frameBorderSoft),
                    ),
                    title: Text('${s.$2} IV: ${s.$3} / 31',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 13)),
                    trailing: s.$3 >= 31
                        ? const Text('MAX (31)',
                            style: TextStyle(
                                color: PokeColors.pokeGreenDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 10.5))
                        : ElevatedButton(
                            onPressed: trainer.frontierBattlePoints <
                                    BattleFrontierDatabase.bottleCapCostBp
                                ? null
                                : () {
                                    trainer.spendBattlePoints(
                                        BattleFrontierDatabase.bottleCapCostBp);
                                    mon.hyperTrainStat(s.$1);
                                    trainer.saveProgress();
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Hyper Trained ${mon.nickname}\'s ${s.$2} IV to 31!'),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PokeColors.badgeGoldDark,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('20 BP'),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final bool unlocked = trainer.isBattleFrontierUnlocked;

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: AppBar(
        backgroundColor: PokeColors.leagueIndigo,
        foregroundColor: Colors.white,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'BATTLE FRONTIER',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: PokeCounterPill(
                icon: Icons.emoji_events_rounded,
                iconColor: PokeColors.badgeGoldDark,
                text: '${trainer.frontierBattlePoints} BP',
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: PokeColors.badgeGold,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.7,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.stadium_rounded, size: 18), text: 'BATTLE'),
            Tab(icon: Icon(Icons.storage_rounded, size: 18), text: 'PC & TEAM'),
            Tab(icon: Icon(Icons.storefront_rounded, size: 18), text: 'BP SHOP'),
          ],
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: BattleFrontierDatabase.frontierBgAsset,
            topOpacity: 0.22,
            midOpacity: 0.48,
            bottomOpacity: 0.88,
          ),
          if (!unlocked)
            _buildLockedOverlay(trainer)
          else
            TabBarView(
              controller: _tabController,
              children: [
                _buildBattleTab(trainer),
                _buildPcAndTeamTab(trainer),
                _buildShopTab(trainer),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLockedOverlay(Trainer trainer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: PokeDecorations.card(
            fill: PokeColors.creamSurface,
            border: PokeColors.pokeRed,
            radius: 20,
            borderWidth: 1.8,
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, color: PokeColors.pokeRed, size: 46),
              SizedBox(height: 12),
              Text(
                'BATTLE FRONTIER LOCKED',
                style: TextStyle(
                  color: PokeColors.inkDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Become the Kanto Pokémon League Champion first to unlock the Battle Frontier, origin-locked PC transfers across unlocked regions, Battle Tower, and Battle Factory!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBattleTab(Trainer trainer) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        // Frontier Status & Active Team Card
        Container(
          padding: const EdgeInsets.all(13),
          decoration: PokeDecorations.card(
            fill: PokeColors.creamSurface,
            border: PokeColors.leagueIndigo,
            radius: 17,
            borderWidth: 1.6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.stadium_rounded,
                      color: PokeColors.leagueIndigo, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'FRONTIER RECORDS & SQUAD',
                      style: TextStyle(
                        color: PokeColors.leagueIndigo,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  Text(
                    '${trainer.frontierBattlePoints} BP',
                    style: const TextStyle(
                      color: PokeColors.badgeGoldDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _streakBadge(
                      'Tower 1v1',
                      '${trainer.frontierTowerBestSingles} Wins',
                      PokeColors.pokeRed,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _streakBadge(
                      'Tower 2v2',
                      '${trainer.frontierTowerBestDoubles} Wins',
                      PokeColors.pokeBlue,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _streakBadge(
                      'Factory 1v1',
                      '${trainer.frontierFactoryBestSingles} Wins',
                      PokeColors.linkTealDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _streakBadge(
                      'Factory 2v2',
                      '${trainer.frontierFactoryBestDoubles} Wins',
                      PokeColors.badgeGoldDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (trainer.frontierParty.isEmpty)
                InkWell(
                  onTap: () => _tabController.animateTo(1),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: PokeDecorations.inset(radius: 11),
                    child: const Text(
                      'Frontier Party is empty. Tap here or open PC & TEAM to import Pokémon from Kanto / Johto!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: PokeColors.leagueIndigo,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Text(
                      'Frontier Party (${trainer.frontierParty.length}/6)',
                      style: const TextStyle(
                        color: PokeColors.inkDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        trainer.healAllFrontierParty();
                        SoundService.instance.playUiTap();
                      },
                      icon: const Icon(Icons.favorite_rounded, size: 14),
                      label: const Text('HEAL SQUAD',
                          style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (int i = 0; i < trainer.frontierParty.length; i++)
                      InkWell(
                        onTap: () => _showFrontierPokemonSheet(
                          trainer,
                          trainer.frontierParty[i],
                          partyIndex: i,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: PokeDecorations.inset(
                            fill: PokeColors.cardWhite,
                            radius: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PokemonHeadPortrait(
                                pokemon: trainer.frontierParty[i],
                                size: 24,
                                borderRadius: 6,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${trainer.frontierParty[i].nickname} Lv.${trainer.frontierParty[i].level}',
                                style: const TextStyle(
                                  color: PokeColors.inkDark,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // BATTLE TOWER CARD
        Container(
          padding: const EdgeInsets.all(15),
          decoration: PokeDecorations.card(
            fill: PokeColors.cardWhite,
            border: PokeColors.pokeRed,
            radius: 18,
            borderWidth: 1.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: PokeColors.pokeRed.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PokeColors.pokeRed),
                    ),
                    child: const Icon(Icons.castle_rounded,
                        color: PokeColors.pokeRedDark, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BATTLE TOWER',
                          style: TextStyle(
                            color: PokeColors.inkDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Real Levels (No Level Scaling) • Auto-Heal • No Bag',
                          style: TextStyle(
                            color: PokeColors.pokeRedDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter with your Frontier Party using their exact real levels (up to 3 for Singles or 4 for Doubles). Opponents escalate from Lv. 50 toward Lv. 100, with Frontier Brain Bosses every 7th match!',
                style: TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 11.5,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _launchBattleTower(trainer, isDoubles: false),
                      icon: const Icon(Icons.person_rounded, size: 17),
                      label: const Text(
                        '3v3 SINGLES',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 11.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.pokeRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _launchBattleTower(trainer, isDoubles: true),
                      icon: const Icon(Icons.groups_rounded, size: 17),
                      label: const Text(
                        '4v4 DOUBLES',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 11.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.leagueIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // BATTLE FACTORY CARD
        Container(
          padding: const EdgeInsets.all(15),
          decoration: PokeDecorations.card(
            fill: PokeColors.cardWhite,
            border: PokeColors.linkTealDark,
            radius: 18,
            borderWidth: 1.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: PokeColors.linkTeal.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PokeColors.linkTealDark),
                    ),
                    child: const Icon(Icons.precision_manufacturing_rounded,
                        color: PokeColors.linkTealDark, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BATTLE FACTORY',
                          style: TextStyle(
                            color: PokeColors.inkDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Lv. 70 Rental Draft • Post-Win 1-for-1 Swaps',
                          style: TextStyle(
                            color: PokeColors.linkTealDark,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Draft a team from 6 competitive Lv. 70 rental Pokémon across Kanto & Johto! After each victory, earn BP and optionally swap one rental with an opponent\'s Pokémon.',
                style: TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 11.5,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _launchBattleFactory(isDoubles: false),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                      label: const Text(
                        '3v3 RENTAL',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 11.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.linkTealDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _launchBattleFactory(isDoubles: true),
                      icon: const Icon(Icons.groups_rounded, size: 17),
                      label: const Text(
                        '4v4 RENTAL',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 11.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.bagOrangeDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _streakBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: PokeDecorations.inset(
        fill: PokeColors.cardWhite,
        border: color.withOpacity(0.5),
        radius: 10,
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PokeColors.inkMuted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPcAndTeamTab(Trainer trainer) {
    final currentBox = trainer.frontierPcBoxes[_selectedFrontierBox];
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: PokeDecorations.card(
            fill: PokeColors.creamSurface,
            border: PokeColors.leagueIndigo,
            radius: 16,
            borderWidth: 1.5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORIGIN-LOCKED TRANSFERS',
                          style: TextStyle(
                            color: PokeColors.leagueIndigo,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.7,
                          ),
                        ),
                        Text(
                          'Bring PC Pokémon from any unlocked region into Frontier. They can only return to their origin region.',
                          style: TextStyle(
                            color: PokeColors.inkMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openRegionalImportSheet(trainer),
                    icon: const Icon(Icons.move_to_inbox_rounded, size: 16),
                    label: const Text(
                      'IMPORT PC',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PokeColors.leagueIndigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Frontier Party section
        Text(
          'FRONTIER PARTY (${trainer.frontierParty.length}/6)',
          style: const TextStyle(
            color: PokeColors.inkDark,
            fontWeight: FontWeight.w900,
            fontSize: 11.5,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 6),
        if (trainer.frontierParty.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: PokeDecorations.card(
              fill: PokeColors.cardWhite,
              border: PokeColors.frameBorderSoft,
              radius: 14,
            ),
            child: const Text(
              'No Pokémon in your Frontier Party yet. Import from Regional PC above, then tap a stored Pokémon below to add it!',
              textAlign: TextAlign.center,
              style: TextStyle(color: PokeColors.inkMuted, fontSize: 11.5),
            ),
          )
        else
          for (int i = 0; i < trainer.frontierParty.length; i++) ...[
            _buildFrontierMonTile(
              trainer,
              trainer.frontierParty[i],
              onTap: () => _showFrontierPokemonSheet(
                trainer,
                trainer.frontierParty[i],
                partyIndex: i,
              ),
              badgeText: i == 0 ? 'LEAD' : '#${i + 1}',
            ),
            const SizedBox(height: 7),
          ],

        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              'FRONTIER PC (${trainer.totalFrontierPcPokemon} STORED)',
              style: const TextStyle(
                color: PokeColors.inkDark,
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: Trainer.numPcBoxes,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, idx) {
              final sel = idx == _selectedFrontierBox;
              final cnt = trainer.frontierPcBoxes[idx].length;
              return ChoiceChip(
                label: Text(
                  'Box ${idx + 1} ($cnt)',
                  style: TextStyle(
                    color: sel ? Colors.white : PokeColors.inkDark,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                selected: sel,
                selectedColor: PokeColors.leagueIndigo,
                backgroundColor: PokeColors.cardWhite,
                onSelected: (_) => setState(() => _selectedFrontierBox = idx),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (currentBox.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: PokeDecorations.card(
              fill: PokeColors.cardWhite,
              border: PokeColors.frameBorderSoft,
              radius: 14,
            ),
            child: const Text(
              'This Frontier PC Box is empty.',
              textAlign: TextAlign.center,
              style: TextStyle(color: PokeColors.inkMuted, fontSize: 11.5),
            ),
          )
        else
          for (int i = 0; i < currentBox.length; i++) ...[
            _buildFrontierMonTile(
              trainer,
              currentBox[i],
              onTap: () => _showFrontierPokemonSheet(
                trainer,
                currentBox[i],
                boxIndex: _selectedFrontierBox,
                slotIndex: i,
              ),
            ),
            const SizedBox(height: 7),
          ],
      ],
    );
  }

  Widget _buildFrontierMonTile(
    Trainer trainer,
    PokemonInstance mon, {
    required VoidCallback onTap,
    String? badgeText,
  }) {
    final origin = GameRegionExtension.fromStorageKey(mon.originRegion);
    final heldName = mon.heldItemId != null
        ? (ItemDatabase.byId(mon.heldItemId!)?.name ?? mon.heldItemId!)
        : 'No Item';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: PokeDecorations.card(
          fill: PokeColors.cardWhite,
          border: origin.accentColor.withOpacity(0.55),
          radius: 14,
          borderWidth: 1.3,
        ),
        child: Row(
          children: [
            PokemonHeadPortrait(pokemon: mon, size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${mon.nickname} • Lv.${mon.level}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PokeColors.inkDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: origin.accentColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          origin.displayName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 8.5,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: PokeColors.leagueIndigo,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 8.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${mon.nature.displayName} (${mon.nature.shortEffectLabel}) • $heldName',
                    style: const TextStyle(
                      color: PokeColors.inkMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: PokeColors.inkSubtle),
          ],
        ),
      ),
    );
  }

  Widget _buildShopTab(Trainer trainer) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
      children: [
        // Training Counter Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: PokeDecorations.card(
            fill: PokeColors.creamSurface,
            border: PokeColors.badgeGoldDark,
            radius: 17,
            borderWidth: 1.6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fitness_center_rounded,
                      color: PokeColors.badgeGoldDark, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'FRONTIER TRAINING COUNTER',
                      style: TextStyle(
                        color: PokeColors.badgeGoldDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  Text(
                    '${trainer.frontierBattlePoints} BP',
                    style: const TextStyle(
                      color: PokeColors.inkDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Spend BP directly on any Frontier Party or Frontier PC Pokémon:',
                style: TextStyle(color: PokeColors.inkMuted, fontSize: 11),
              ),
              const SizedBox(height: 10),
              _trainingServiceRow(
                title: 'Nature Mint',
                subtitle: 'Change effective Nature stat modifiers & recalculate',
                costBp: BattleFrontierDatabase.natureMintCostBp,
                icon: Icons.eco_rounded,
                color: PokeColors.pokeGreenDark,
                onTap: () => _openTrainingTargetPicker(trainer, 'mint'),
              ),
              const SizedBox(height: 7),
              _trainingServiceRow(
                title: 'Bottle Cap',
                subtitle: 'Hyper Train any 1 IV to 31',
                costBp: BattleFrontierDatabase.bottleCapCostBp,
                icon: Icons.star_rounded,
                color: PokeColors.badgeGoldDark,
                onTap: () => _openTrainingTargetPicker(trainer, 'cap'),
              ),
              const SizedBox(height: 7),
              _trainingServiceRow(
                title: 'Gold Bottle Cap',
                subtitle: 'Hyper Train all 6 IVs to 31',
                costBp: BattleFrontierDatabase.goldBottleCapCostBp,
                icon: Icons.auto_awesome_rounded,
                color: PokeColors.bagOrangeDark,
                onTap: () => _openTrainingTargetPicker(trainer, 'gold_cap'),
              ),
              const SizedBox(height: 7),
              _trainingServiceRow(
                title: 'Ability Patch',
                subtitle: 'Unlock Hidden Ability or swap species ability slot',
                costBp: BattleFrontierDatabase.abilityPatchCostBp,
                icon: Icons.psychology_rounded,
                color: PokeColors.leagueIndigo,
                onTap: () => _openTrainingTargetPicker(trainer, 'patch'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'BP ITEM EXCHANGE (STORED IN FRONTIER BAG)',
          style: TextStyle(
            color: PokeColors.inkDark,
            fontWeight: FontWeight.w900,
            fontSize: 11.5,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 8),
        for (final entry in BattleFrontierDatabase.shopItems) ...[
          _buildShopItemRow(trainer, entry),
          const SizedBox(height: 7),
        ],
      ],
    );
  }

  Widget _trainingServiceRow({
    required String title,
    required String subtitle,
    required int costBp,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: color.withOpacity(0.45),
        radius: 12,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: PokeColors.inkDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5)),
                Text(subtitle,
                    style: const TextStyle(
                        color: PokeColors.inkMuted, fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
            child: Text('$costBp BP',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItemRow(Trainer trainer, FrontierShopEntry entry) {
    final item = ItemDatabase.byId(entry.itemId);
    if (item == null) return const SizedBox.shrink();
    final owned = trainer.getFrontierItemCount(entry.itemId);
    final canAfford = trainer.frontierBattlePoints >= entry.bpCost;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: PokeColors.frameBorderSoft,
        radius: 13,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: PokeColors.inkDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (owned > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Owned: $owned',
                        style: const TextStyle(
                          color: PokeColors.pokeGreenDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  item.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: PokeColors.inkMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: !canAfford
                ? null
                : () {
                    trainer.spendBattlePoints(entry.bpCost);
                    trainer.adjustFrontierItemCount(entry.itemId, 1);
                    SoundService.instance.playUiTap();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Purchased ${item.name} for ${entry.bpCost} BP!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokeColors.leagueIndigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
            child: Text('${entry.bpCost} BP',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 11)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// BATTLE TOWER STREAK RUNNER (Real Levels — NO Level Scaling)
// =============================================================================

class _FrontierTowerRunScreen extends StatefulWidget {
  final bool isDoubles;

  const _FrontierTowerRunScreen({required this.isDoubles});

  @override
  State<_FrontierTowerRunScreen> createState() =>
      _FrontierTowerRunScreenState();
}

class _FrontierTowerRunScreenState extends State<_FrontierTowerRunScreen> {
  int _wins = 0;
  int _totalBpEarned = 0;
  bool _busy = false;
  bool _finished = false;
  bool _defeated = false;
  late FrontierOpponent _nextOpponent;

  @override
  void initState() {
    super.initState();
    _nextOpponent = BattleFrontierDatabase.buildTowerOpponent(
      streakNumber: 1,
      isDoubles: widget.isDoubles,
    );
  }

  Future<void> _fightNextMatch(Trainer trainer) async {
    if (_busy || _finished) return;
    final int takeCount = widget.isDoubles ? 4 : 3;
    final activeSquad = trainer.frontierParty.take(takeCount).toList();
    if (activeSquad.isEmpty ||
        (widget.isDoubles && activeSquad.length < 2)) {
      return;
    }

    // Snapshot initial held items so single-use Focus Sash / berries restore after the Frontier round
    final initialItems = <PokemonInstance, String?>{
      for (final m in activeSquad) m: m.heldItemId,
    };
    for (final m in activeSquad) {
      m.resetBattleStateAndHeal();
    }

    setState(() => _busy = true);
    bool won = false;
    try {
      trainer.setBattlePartyOverride(activeSquad, suppressBadgeBonuses: true);
      final opp = _nextOpponent;
      final bool? res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => widget.isDoubles
              ? DoubleBattleScreen(
                  opponentTeam: opp.team,
                  trainerName: opp.name,
                  trainerTitle: opp.title,
                  trainerIntroLine: opp.introDialogue,
                  trainerDefeatLine: opp.defeatDialogue,
                  opponentSpriteId: opp.spriteId,
                  battleBackgroundAsset: BattleFrontierDatabase.frontierBgAsset,
                  bgmCategory: opp.isBoss
                      ? BattleBgmCategory.special
                      : BattleBgmCategory.gym,
                  isFrontierBattle: true,
                  continueButtonLabel: 'COLLECT BP & CONTINUE',
                  defeatButtonLabel: 'EXIT TOWER',
                )
              : BattleScreen(
                  opponentPokemon: opp.team.first,
                  opponentTeam: opp.team,
                  isWild: false,
                  trainerName: opp.name,
                  trainerTitle: opp.title,
                  trainerIntroLine: opp.introDialogue,
                  trainerDefeatLine: opp.defeatDialogue,
                  opponentSpriteId: opp.spriteId,
                  battleBackgroundAsset: BattleFrontierDatabase.frontierBgAsset,
                  bgmCategory: opp.isBoss
                      ? BattleBgmCategory.special
                      : BattleBgmCategory.gym,
                  isFrontierBattle: true,
                  continueButtonLabel: 'COLLECT BP & CONTINUE',
                  defeatButtonLabel: 'EXIT TOWER',
                ),
        ),
      );
      won = res == true;
    } finally {
      for (final entry in initialItems.entries) {
        entry.key.heldItemId = entry.value;
        entry.key.resetBattleStateAndHeal();
      }
      trainer.clearBattlePartyOverride();
    }

    if (!mounted) return;
    if (won) {
      HapticFeedback.mediumImpact();
      final int streakNum = _wins + 1;
      final int bp = BattleFrontierDatabase.bpRewardForMatch(
        streakNumber: streakNum,
        isFactory: false,
      );
      trainer.addBattlePoints(bp);
      trainer.recordFrontierTowerStreak(
        isDoubles: widget.isDoubles,
        streak: streakNum,
      );
      await trainer.saveProgress();
      setState(() {
        _wins = streakNum;
        _totalBpEarned += bp;
        _nextOpponent = BattleFrontierDatabase.buildTowerOpponent(
          streakNumber: _wins + 1,
          isDoubles: widget.isDoubles,
        );
        _busy = false;
      });
    } else {
      setState(() {
        _busy = false;
        _finished = true;
        _defeated = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final int nextMatch = _wins + 1;
    final int nextLv =
        BattleFrontierDatabase.opponentLevelForTowerStreak(nextMatch);

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: widget.isDoubles
            ? 'TOWER • 4v4 DOUBLES'
            : 'TOWER • 3v3 SINGLES',
        barColor: PokeColors.pokeRed,
        bottomBorderColor: PokeColors.pokeRedDark,
        actions: [
          PokeCounterPill(
            icon: Icons.emoji_events_rounded,
            iconColor: PokeColors.badgeGoldDark,
            text: '$_wins WINS',
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: BattleFrontierDatabase.frontierBgAsset,
            topOpacity: 0.24,
            midOpacity: 0.50,
            bottomOpacity: 0.88,
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _finished
                  ? _buildSummaryCard()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: PokeDecorations.card(
                            fill: PokeColors.creamSurface,
                            border: _nextOpponent.isBoss
                                ? PokeColors.badgeGoldDark
                                : PokeColors.pokeRed,
                            radius: 18,
                            borderWidth: 1.8,
                          ),
                          child: Column(
                            children: [
                              TrainerSpriteWidget(
                                spriteId: _nextOpponent.spriteId,
                                size: 92,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _nextOpponent.isBoss
                                      ? PokeColors.badgeGoldDark
                                      : PokeColors.pokeRed,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _nextOpponent.isBoss
                                      ? 'FRONTIER BRAIN BOSS • MATCH #$nextMatch'
                                      : 'TOWER MATCH #$nextMatch',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _nextOpponent.name,
                                style: const TextStyle(
                                  color: PokeColors.inkDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                ),
                              ),
                              Text(
                                '${_nextOpponent.team.length} Pokémon • Opponent Lv.$nextLv • Auto-Heal Active',
                                style: const TextStyle(
                                  color: PokeColors.inkMuted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Streak BP Earned This Run: +$_totalBpEarned BP',
                                style: const TextStyle(
                                  color: PokeColors.badgeGoldDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed:
                                _busy ? null : () => _fightNextMatch(trainer),
                            icon: const Icon(Icons.sports_martial_arts_rounded),
                            label: Text(
                              'BATTLE MATCH #$nextMatch',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PokeColors.pokeRed,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _busy ? null : () => Navigator.pop(context),
                          child: Text(
                            _wins > 0
                                ? 'RETIRE STREAK (KEEP +$_totalBpEarned BP)'
                                : 'LEAVE BATTLE TOWER',
                            style: const TextStyle(fontWeight: FontWeight.w900),
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

  Widget _buildSummaryCard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: PokeDecorations.card(
            fill: PokeColors.creamSurface,
            border: PokeColors.pokeRed,
            radius: 20,
            borderWidth: 1.8,
          ),
          child: Column(
            children: [
              Icon(
                _defeated ? Icons.close_rounded : Icons.emoji_events_rounded,
                size: 52,
                color: PokeColors.pokeRed,
              ),
              const SizedBox(height: 10),
              Text(
                _defeated ? 'TOWER STREAK ENDED' : 'TOWER RUN COMPLETE',
                style: const TextStyle(
                  color: PokeColors.inkDark,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You achieved $_wins consecutive ${widget.isDoubles ? 'Doubles' : 'Singles'} wins and earned +$_totalBpEarned BP!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: PokeColors.leagueIndigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
            child: const Text('RETURN TO FRONTIER',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// BATTLE FACTORY RENTAL DRAFT & SWAP RUNNER
// =============================================================================

class _FrontierFactoryRunScreen extends StatefulWidget {
  final bool isDoubles;

  const _FrontierFactoryRunScreen({required this.isDoubles});

  @override
  State<_FrontierFactoryRunScreen> createState() =>
      _FrontierFactoryRunScreenState();
}

class _FrontierFactoryRunScreenState extends State<_FrontierFactoryRunScreen> {
  late final List<PokemonInstance> _draftPool;
  final Set<int> _selectedIndices = {};
  List<PokemonInstance> _rentalTeam = [];
  List<PokemonInstance>? _lastDefeatedOpponentTeam;
  int _wins = 0;
  int _totalBpEarned = 0;
  bool _drafted = false;
  bool _offeringSwap = false;
  bool _finished = false;
  bool _busy = false;
  late FrontierOpponent _nextOpponent;

  int get _teamLimit => widget.isDoubles ? 4 : 3;

  @override
  void initState() {
    super.initState();
    _draftPool = BattleFrontierDatabase.rollFactoryDraftPool(count: 6, level: 70);
  }

  void _confirmDraft() {
    if (_selectedIndices.length != _teamLimit) return;
    _rentalTeam = [
      for (final idx in _selectedIndices) _draftPool[idx],
    ];
    _nextOpponent = BattleFrontierDatabase.buildFactoryOpponent(
      streakNumber: 1,
      isDoubles: widget.isDoubles,
      excludeSpeciesIds: _rentalTeam.map((m) => m.species.id).toSet(),
    );
    setState(() => _drafted = true);
  }

  Future<void> _fightFactoryMatch(Trainer trainer) async {
    if (_busy || _finished || _rentalTeam.isEmpty) return;
    final initialItems = <PokemonInstance, String?>{
      for (final m in _rentalTeam) m: m.heldItemId,
    };
    for (final m in _rentalTeam) {
      m.resetBattleStateAndHeal();
    }

    final opp = _nextOpponent;
    setState(() => _busy = true);
    bool won = false;
    try {
      trainer.setBattlePartyOverride(_rentalTeam, suppressBadgeBonuses: true);
      final bool? res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => widget.isDoubles
              ? DoubleBattleScreen(
                  opponentTeam: opp.team,
                  trainerName: opp.name,
                  trainerTitle: opp.title,
                  trainerIntroLine: opp.introDialogue,
                  trainerDefeatLine: opp.defeatDialogue,
                  opponentSpriteId: opp.spriteId,
                  battleBackgroundAsset: BattleFrontierDatabase.frontierBgAsset,
                  bgmCategory: opp.isBoss
                      ? BattleBgmCategory.special
                      : BattleBgmCategory.gym,
                  isFrontierBattle: true,
                  continueButtonLabel: 'COLLECT BP & CONTINUE',
                  defeatButtonLabel: 'EXIT FACTORY',
                )
              : BattleScreen(
                  opponentPokemon: opp.team.first,
                  opponentTeam: opp.team,
                  isWild: false,
                  trainerName: opp.name,
                  trainerTitle: opp.title,
                  trainerIntroLine: opp.introDialogue,
                  trainerDefeatLine: opp.defeatDialogue,
                  opponentSpriteId: opp.spriteId,
                  battleBackgroundAsset: BattleFrontierDatabase.frontierBgAsset,
                  bgmCategory: opp.isBoss
                      ? BattleBgmCategory.special
                      : BattleBgmCategory.gym,
                  isFrontierBattle: true,
                  continueButtonLabel: 'COLLECT BP & CONTINUE',
                  defeatButtonLabel: 'EXIT FACTORY',
                ),
        ),
      );
      won = res == true;
    } finally {
      for (final entry in initialItems.entries) {
        entry.key.heldItemId = entry.value;
        entry.key.resetBattleStateAndHeal();
      }
      for (final m in opp.team) {
        m.resetBattleStateAndHeal();
      }
      trainer.clearBattlePartyOverride();
    }

    if (!mounted) return;
    if (won) {
      HapticFeedback.mediumImpact();
      final int streakNum = _wins + 1;
      final int bp = BattleFrontierDatabase.bpRewardForMatch(
        streakNumber: streakNum,
        isFactory: true,
      );
      trainer.addBattlePoints(bp);
      trainer.recordFrontierFactoryStreak(
        isDoubles: widget.isDoubles,
        streak: streakNum,
      );
      await trainer.saveProgress();
      setState(() {
        _wins = streakNum;
        _totalBpEarned += bp;
        _lastDefeatedOpponentTeam = opp.team;
        _offeringSwap = true;
        _busy = false;
      });
    } else {
      setState(() {
        _busy = false;
        _finished = true;
      });
    }
  }

  void _advanceAfterSwap({int? dropMyIdx, int? takeOppIdx}) {
    if (dropMyIdx != null &&
        takeOppIdx != null &&
        _lastDefeatedOpponentTeam != null &&
        dropMyIdx >= 0 &&
        dropMyIdx < _rentalTeam.length &&
        takeOppIdx >= 0 &&
        takeOppIdx < _lastDefeatedOpponentTeam!.length) {
      _rentalTeam[dropMyIdx] = _lastDefeatedOpponentTeam![takeOppIdx];
    }
    setState(() {
      _offeringSwap = false;
      _lastDefeatedOpponentTeam = null;
      _nextOpponent = BattleFrontierDatabase.buildFactoryOpponent(
        streakNumber: _wins + 1,
        isDoubles: widget.isDoubles,
        excludeSpeciesIds: _rentalTeam.map((m) => m.species.id).toSet(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: widget.isDoubles
            ? 'FACTORY • 4v4 RENTAL'
            : 'FACTORY • 3v3 RENTAL',
        barColor: PokeColors.linkTealDark,
        bottomBorderColor: PokeColors.leagueIndigoDark,
        actions: [
          PokeCounterPill(
            icon: Icons.emoji_events_rounded,
            iconColor: PokeColors.badgeGoldDark,
            text: '$_wins WINS',
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: BattleFrontierDatabase.frontierBgAsset,
            topOpacity: 0.24,
            midOpacity: 0.50,
            bottomOpacity: 0.88,
          ),
          SafeArea(
            top: false,
            child: !_drafted
                ? _buildDraftScreen()
                : _finished
                    ? _buildFinishedScreen()
                    : _offeringSwap
                        ? _buildSwapScreen()
                        : _buildBattleReadyScreen(trainer),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftScreen() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: PokeDecorations.card(
              fill: PokeColors.creamSurface,
              border: PokeColors.linkTealDark,
              radius: 14,
            ),
            child: Row(
              children: [
                const Icon(Icons.precision_manufacturing_rounded,
                    color: PokeColors.linkTealDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Draft $_teamLimit Lv. 70 Rentals (${_selectedIndices.length}/$_teamLimit selected)',
                    style: const TextStyle(
                      color: PokeColors.inkDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
            itemCount: _draftPool.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, idx) {
              final mon = _draftPool[idx];
              final selected = _selectedIndices.contains(idx);
              final ab =
                  AbilityDatabase.all[mon.abilityId]?.name ?? mon.abilityId;
              final item = ItemDatabase.byId(mon.heldItemId ?? '')?.name ?? 'None';
              return InkWell(
                onTap: () {
                  SoundService.instance.playUiTap();
                  setState(() {
                    if (selected) {
                      _selectedIndices.remove(idx);
                    } else if (_selectedIndices.length < _teamLimit) {
                      _selectedIndices.add(idx);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(11),
                  decoration: PokeDecorations.card(
                    fill: selected ? const Color(0xFFE0F2F1) : PokeColors.cardWhite,
                    border: selected
                        ? PokeColors.linkTealDark
                        : PokeColors.frameBorderSoft,
                    radius: 14,
                    borderWidth: selected ? 2.0 : 1.2,
                  ),
                  child: Row(
                    children: [
                      PokemonSpriteImage.fromInstance(
                        mon,
                        width: 48,
                        height: 48,
                        fallbackIconColor: mon.species.types.first.color,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${mon.species.name} • Lv.${mon.level} • ${mon.nature.displayName}',
                              style: const TextStyle(
                                color: PokeColors.inkDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '$ab • $item',
                              style: const TextStyle(
                                color: PokeColors.linkTealDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              mon.moves.map((m) => m.name).join(' • '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PokeColors.inkMuted,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? PokeColors.linkTealDark
                            : PokeColors.inkSubtle,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _selectedIndices.length == _teamLimit
                  ? _confirmDraft
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.linkTealDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                'LOCK IN $_teamLimit RENTALS',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBattleReadyScreen(Trainer trainer) {
    final int nextMatch = _wins + 1;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: PokeDecorations.card(
              fill: PokeColors.creamSurface,
              border: PokeColors.linkTealDark,
              radius: 18,
              borderWidth: 1.7,
            ),
            child: Column(
              children: [
                TrainerSpriteWidget(
                  spriteId: _nextOpponent.spriteId,
                  size: 86,
                ),
                const SizedBox(height: 6),
                Text(
                  'FACTORY MATCH #$nextMatch • ${_nextOpponent.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Lv. 70 Rental Squad • Streak BP: +$_totalBpEarned BP',
                  style: const TextStyle(
                    color: PokeColors.badgeGoldDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _rentalTeam
                      .map((m) => Chip(
                            avatar: PokemonHeadPortrait(
                                pokemon: m, size: 22, borderRadius: 6),
                            label: Text(m.species.name,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w800)),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _fightFactoryMatch(trainer),
              icon: const Icon(Icons.sports_martial_arts_rounded),
              label: Text(
                'START FACTORY MATCH #$nextMatch',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.linkTealDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('RETIRE STREAK',
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapScreen() {
    int? dropIdx;
    int? takeIdx;
    final oppTeam = _lastDefeatedOpponentTeam ?? const [];

    return StatefulBuilder(
      builder: (ctx, setSwapState) => Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: PokeDecorations.card(
                fill: PokeColors.creamSurface,
                border: PokeColors.badgeGoldDark,
                radius: 14,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VICTORY! RENTAL EXCHANGE',
                    style: TextStyle(
                      color: PokeColors.badgeGoldDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Optionally trade 1 of your rentals for 1 from your defeated opponent, or keep your team.',
                    style: TextStyle(color: PokeColors.inkMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text('GIVE UP ONE RENTAL:',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            const SizedBox(height: 5),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (int i = 0; i < _rentalTeam.length; i++)
                  ChoiceChip(
                    label: Text(_rentalTeam[i].species.name,
                        style: TextStyle(
                          color: dropIdx == i
                              ? Colors.white
                              : PokeColors.inkDark,
                          fontWeight: FontWeight.w800,
                        )),
                    selected: dropIdx == i,
                    selectedColor: PokeColors.pokeRed,
                    onSelected: (_) => setSwapState(() => dropIdx = i),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('CLAIM OPPONENT RENTAL:',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
            const SizedBox(height: 5),
            Expanded(
              child: ListView.separated(
                itemCount: oppTeam.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, idx) {
                  final mon = oppTeam[idx];
                  final sel = takeIdx == idx;
                  final item =
                      ItemDatabase.byId(mon.heldItemId ?? '')?.name ?? 'None';
                  return ListTile(
                    tileColor:
                        sel ? const Color(0xFFE0F2F1) : PokeColors.cardWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: sel
                            ? PokeColors.linkTealDark
                            : PokeColors.frameBorderSoft,
                      ),
                    ),
                    leading: PokemonHeadPortrait(pokemon: mon, size: 38),
                    title: Text(
                      '${mon.species.name} (${mon.nature.displayName} • $item)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 12.5),
                    ),
                    subtitle: Text(
                      mon.moves.map((m) => m.name).join(' • '),
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    onTap: () => setSwapState(() => takeIdx = idx),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _advanceAfterSwap(),
                    child: const Text('KEEP CURRENT TEAM',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 11.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (dropIdx != null && takeIdx != null)
                        ? () => _advanceAfterSwap(
                              dropMyIdx: dropIdx,
                              takeOppIdx: takeIdx,
                            )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PokeColors.linkTealDark,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('SWAP & CONTINUE',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 11.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedScreen() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: PokeDecorations.card(
              fill: PokeColors.creamSurface,
              border: PokeColors.linkTealDark,
              radius: 20,
              borderWidth: 1.8,
            ),
            child: Column(
              children: [
                const Icon(Icons.close_rounded,
                    size: 52, color: PokeColors.pokeRed),
                const SizedBox(height: 10),
                const Text(
                  'FACTORY STREAK ENDED',
                  style: TextStyle(
                    color: PokeColors.inkDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You achieved $_wins consecutive ${widget.isDoubles ? 'Doubles' : 'Singles'} wins and earned +$_totalBpEarned BP!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: PokeColors.inkMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.leagueIndigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              child: const Text('RETURN TO FRONTIER',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}
