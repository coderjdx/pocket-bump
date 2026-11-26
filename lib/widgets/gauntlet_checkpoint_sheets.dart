import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../screens/pokemon_detail_screen.dart';
import 'hp_bar.dart';
import 'move_pp_picker_dialog.dart';
import 'poke_theme.dart';
import 'pokemon_sprite_image.dart';

/// Shared row of 4 tall portrait buttons for multi-stage gauntlets with rest checkpoints:
/// Next Battle, Bag, Pokémon, and Give Up.
class GauntletCheckpointActionBar extends StatelessWidget {
  final Color nextBattleColor;
  final String nextBattleLabel;
  final bool busy;
  final VoidCallback onNextBattle;
  final VoidCallback onBag;
  final VoidCallback onPokemon;
  final VoidCallback onGiveUp;

  const GauntletCheckpointActionBar({
    super.key,
    required this.nextBattleColor,
    this.nextBattleLabel = 'NEXT BATTLE',
    required this.busy,
    required this.onNextBattle,
    required this.onBag,
    required this.onPokemon,
    required this.onGiveUp,
  });

  @override
  Widget build(BuildContext context) {
    final Color nextTop = nextBattleColor;
    final Color nextBottom = PokeColors.darken(nextBattleColor, 0.16);
    return Opacity(
      opacity: busy ? 0.65 : 1.0,
      child: Row(
        children: [
          Expanded(
            child: PokePortraitButton(
              label: nextBattleLabel,
              icon: Icons.play_arrow_rounded,
              topColor: nextTop,
              bottomColor: nextBottom,
              height: 118,
              iconSize: 34,
              onTap: busy ? null : onNextBattle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PokePortraitButton(
              label: 'BAG',
              icon: Icons.backpack_rounded,
              topColor: PokeColors.bagOrange,
              bottomColor: PokeColors.bagOrangeDark,
              height: 118,
              iconSize: 32,
              onTap: busy ? null : onBag,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PokePortraitButton(
              label: 'POKÉMON',
              icon: Icons.catching_pokemon,
              topColor: PokeColors.pokeGreen,
              bottomColor: PokeColors.pokeGreenDark,
              height: 118,
              iconSize: 32,
              onTap: busy ? null : onPokemon,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PokePortraitButton(
              label: 'GIVE UP',
              icon: Icons.flag_rounded,
              topColor: PokeColors.pokeRed,
              bottomColor: PokeColors.pokeRedDark,
              height: 118,
              iconSize: 32,
              onTap: busy ? null : onGiveUp,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared Give Up confirmation dialog for rest-checkpoint gauntlets.
Future<bool> confirmGiveUpGauntletDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: PokeColors.creamSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: PokeColors.pokeRed, width: 1.6),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: PokeColors.pokeRedDark,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(
          color: PokeColors.inkMuted,
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (ModalRoute.of(ctx)?.isCurrent == true) {
              Navigator.pop(ctx, false);
            }
          },
          child: const Text(
            'STAY',
            style: TextStyle(
              color: PokeColors.pokeGreenDark,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (ModalRoute.of(ctx)?.isCurrent == true) {
              Navigator.pop(ctx, true);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: PokeColors.pokeRed,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'GIVE UP',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Opens the checkpoint Bag sheet allowing the player to use medicine, PP,
/// status, and Revive items on their party between battles.
Future<void> showCheckpointBagSheet(
  BuildContext context,
  Trainer trainer, {
  VoidCallback? onUpdated,
}) {
  const medicineItems = [
    'potion',
    'super_potion',
    'hyper_potion',
    'max_potion',
    'full_restore',
    'revive',
    'antidote',
    'paralyze_heal',
    'awakening',
    'burn_heal',
    'ice_heal',
    'full_heal',
    'ether',
    'max_ether',
    'elixir',
    'max_elixir',
    'leppa_berry',
  ];

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PokeColors.creamSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      bool isClosing = false;
      return Consumer<Trainer>(
        builder: (sheetCtx, liveTrainer, _) {
          final available = medicineItems
              .where((id) => liveTrainer.getItemCount(id) > 0)
              .toList();

          return Container(
            height: MediaQuery.of(sheetCtx).size.height * 0.75,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PokeSheetHeader(
                  icon: Icons.backpack_rounded,
                  accentColor: PokeColors.bagOrange,
                  title: 'USE ITEMS ON POKÉMON',
                  onClose: () {
                    if (isClosing) return;
                    if (ModalRoute.of(ctx)?.isCurrent == true) {
                      isClosing = true;
                      Navigator.pop(ctx);
                    }
                  },
                ),
                const SizedBox(height: 10),
                if (available.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        "You don't have any usable medicine items in your Bag!",
                        style: TextStyle(
                          color: PokeColors.inkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: available.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (c, idx) {
                        final itemId = available[idx];
                        final itemDef = ItemDatabase.byId(itemId);
                        final count = liveTrainer.getItemCount(itemId);
                        final itemColor = itemDef?.color ?? PokeColors.pokeGreen;

                        return Container(
                          padding: const EdgeInsets.all(11),
                          decoration: PokeDecorations.card(
                            border: itemColor.withOpacity(0.5),
                            radius: 14,
                            borderWidth: 1.4,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: itemColor.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  itemDef?.icon ?? Icons.medical_services,
                                  color: PokeColors.darken(itemColor, 0.14),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${itemDef?.name ?? itemId} (x$count)',
                                      style: const TextStyle(
                                        color: PokeColors.inkDark,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      itemDef?.description ?? '',
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
                                onPressed: () => _selectPartyTargetAndApply(
                                  context,
                                  liveTrainer,
                                  itemId,
                                  onUpdated,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: PokeColors.bagOrange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'USE',
                                  style: TextStyle(fontWeight: FontWeight.w900),
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
          );
        },
      );
    },
  );
}

void _selectPartyTargetAndApply(
  BuildContext hostContext,
  Trainer trainer,
  String itemId,
  VoidCallback? onUpdated,
) {
  showDialog(
    context: hostContext,
    builder: (ctx) {
      bool isApplying = false;
      return AlertDialog(
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: PokeColors.bagOrange, width: 1.5),
        ),
        title: Text(
          "USE ${ItemDatabase.byId(itemId)?.name.toUpperCase() ?? itemId.replaceAll('_', ' ').toUpperCase()} ON:",
          style: const TextStyle(
            color: PokeColors.inkDark,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: trainer.party.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (c, idx) {
              final mon = trainer.party[idx];
              return ListTile(
                tileColor: PokeColors.cardWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: PokeColors.frameBorderSoft),
                ),
                title: Text(
                  '${mon.nickname} (HP ${mon.currentHp}/${mon.maxHp})',
                  style: TextStyle(
                    color: mon.isFainted
                        ? PokeColors.inkSubtle
                        : PokeColors.inkDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: ItemDatabase.isPpRestoreItem(itemId)
                    ? Text(
                        "Total PP ${mon.moves.fold<int>(0, (s, m) => s + m.currentPp)}/${mon.moves.fold<int>(0, (s, m) => s + m.maxPp)}",
                        style: const TextStyle(
                          color: PokeColors.pokeBlueDark,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : mon.status != StatusCondition.none
                        ? Text(
                            'Status: ${mon.status.name.toUpperCase()}',
                            style: const TextStyle(
                              color: PokeColors.pokeRed,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                onTap: () async {
                  if (isApplying) return;
                  if (!ItemDatabase.canUseMedicineOn(itemId, mon)) {
                    if (hostContext.mounted) {
                      ScaffoldMessenger.of(hostContext).showSnackBar(
                        const SnackBar(
                          content: Text("It won't have any effect!"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                    return;
                  }
                  isApplying = true;
                  try {
                    int? moveIndex;
                    if (ItemDatabase.isSingleMovePpItem(itemId)) {
                      final itemDef = ItemDatabase.byId(itemId);
                      if (itemDef != null) {
                        moveIndex = await showMovePpPickerDialog(
                          ctx,
                          pokemon: mon,
                          item: itemDef,
                        );
                        if (moveIndex == null) return;
                      }
                    }
                    final String msg = ItemDatabase.applyMedicineToPokemon(
                      itemId: itemId,
                      targetMon: mon,
                      moveIndex: moveIndex,
                    );
                    trainer.adjustItemCount(itemId, -1);
                    trainer.saveProgress();
                    onUpdated?.call();
                    if (ctx.mounted && ModalRoute.of(ctx)?.isCurrent == true) {
                      Navigator.pop(ctx);
                    }
                    if (hostContext.mounted) {
                      ScaffoldMessenger.of(hostContext).showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } finally {
                    isApplying = false;
                  }
                },
              );
            },
          ),
        ),
      );
    },
  );
}

/// Opens the checkpoint Party Management sheet allowing players to reorder their
/// party, set Lead, manage held items, and inspect/manage moves & TMs.
Future<void> showCheckpointPartySheet(
  BuildContext context,
  Trainer trainer, {
  VoidCallback? onUpdated,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PokeColors.creamSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      bool isClosing = false;
      return Consumer<Trainer>(
        builder: (sheetCtx, liveTrainer, _) {
          return SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.78,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PokeSheetHeader(
                    icon: Icons.catching_pokemon,
                    accentColor: PokeColors.pokeGreen,
                    title: 'MANAGE PARTY',
                    subtitle:
                        'Reorder squad, manage held items, or inspect moves & TMs',
                    onClose: () {
                      if (isClosing) return;
                      if (ModalRoute.of(ctx)?.isCurrent == true) {
                        isClosing = true;
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: liveTrainer.party.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, idx) {
                        final mon = liveTrainer.party[idx];
                        final isLead = idx == 0;
                        final typeColor = mon.species.types.first.color;

                        return Container(
                          padding: const EdgeInsets.all(11),
                          decoration: PokeDecorations.card(
                            fill: PokeColors.cardWhite,
                            border: isLead
                                ? PokeColors.badgeGold
                                : typeColor.withOpacity(0.55),
                            radius: 15,
                            borderWidth: isLead ? 1.8 : 1.3,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  PokemonSpriteImage.fromInstance(
                                    mon,
                                    width: 48,
                                    height: 48,
                                    fallbackIconSize: 36,
                                    fallbackIconColor: typeColor,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isLead
                                                    ? PokeColors.badgeGold
                                                        .withOpacity(0.22)
                                                    : PokeColors.panelSoft,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isLead ? 'LEAD' : '#${idx + 1}',
                                                style: TextStyle(
                                                  color: isLead
                                                      ? PokeColors.badgeGoldDark
                                                      : PokeColors.inkMuted,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            Flexible(
                                              child: Text(
                                                mon.nickname,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: PokeColors.inkDark,
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Lv.${mon.level}',
                                              style: const TextStyle(
                                                color: PokeColors.badgeGoldDark,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        HpBar(
                                          currentHp: mon.currentHp,
                                          maxHp: mon.maxHp,
                                          textColor: PokeColors.inkMuted,
                                          hpLabelColor:
                                              PokeColors.badgeGoldDark,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          mon.moves
                                              .map((m) => m.name)
                                              .join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: PokeColors.inkMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: PokeDecorations.inset(
                                            radius: 7,
                                            border: mon.hasHeldItem
                                                ? PokeColors.badgeGold
                                                : PokeColors.frameBorderSoft,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                mon.hasHeldItem
                                                    ? Icons.shopping_bag
                                                    : Icons
                                                        .shopping_bag_outlined,
                                                size: 13,
                                                color: mon.hasHeldItem
                                                    ? PokeColors.badgeGoldDark
                                                    : PokeColors.inkSubtle,
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  mon.hasHeldItem
                                                      ? 'Held: ${ItemDatabase.byId(mon.heldItemId!)?.name ?? mon.heldItemId}'
                                                      : 'No held item',
                                                  style: TextStyle(
                                                    color: mon.hasHeldItem
                                                        ? PokeColors
                                                            .badgeGoldDark
                                                        : PokeColors.inkSubtle,
                                                    fontSize: 10,
                                                    fontWeight: mon.hasHeldItem
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                              if (mon.hasHeldItem)
                                                InkWell(
                                                  onTap: () {
                                                    final unequipped =
                                                        mon.unequipHeldItem();
                                                    if (unequipped != null) {
                                                      liveTrainer
                                                          .adjustItemCount(
                                                              unequipped, 1);
                                                      liveTrainer
                                                          .saveProgress();
                                                      onUpdated?.call();
                                                    }
                                                  },
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                    child: Text(
                                                      'TAKE',
                                                      style: TextStyle(
                                                        color:
                                                            PokeColors.pokeRed,
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              else
                                                InkWell(
                                                  onTap: () =>
                                                      _openGiveHeldItemModal(
                                                    context,
                                                    liveTrainer,
                                                    mon,
                                                    onUpdated,
                                                  ),
                                                  child: const Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                    child: Text(
                                                      'GIVE',
                                                      style: TextStyle(
                                                        color:
                                                            PokeColors.pokeBlue,
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (!isLead)
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        liveTrainer.setLeadPokemon(idx);
                                        onUpdated?.call();
                                      },
                                      icon: const Icon(Icons.star, size: 13),
                                      label: const Text(
                                        'MAKE LEAD',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: PokeColors.badgeGold,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 5,
                                        ),
                                        minimumSize: Size.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(9),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: PokeColors.pokeGreen
                                            .withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: PokeColors.pokeGreen
                                              .withOpacity(0.5),
                                        ),
                                      ),
                                      child: const Text(
                                        'Active Lead',
                                        style: TextStyle(
                                          color: PokeColors.pokeGreenDark,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  if (idx > 0)
                                    IconButton(
                                      tooltip: 'Move Up',
                                      icon: const Icon(
                                        Icons.arrow_upward,
                                        color: PokeColors.inkMuted,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        liveTrainer.swapPartySlots(
                                            idx, idx - 1);
                                        onUpdated?.call();
                                      },
                                    ),
                                  if (idx < liveTrainer.party.length - 1)
                                    IconButton(
                                      tooltip: 'Move Down',
                                      icon: const Icon(
                                        Icons.arrow_downward,
                                        color: PokeColors.inkMuted,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        liveTrainer.swapPartySlots(
                                            idx, idx + 1);
                                        onUpdated?.call();
                                      },
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PokemonDetailScreen(
                                                  partyIndex: idx),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.auto_stories_rounded,
                                      size: 13,
                                    ),
                                    label: const Text(
                                      'INFO / MOVES',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: PokeColors.pokeBlue,
                                      side: const BorderSide(
                                        color: PokeColors.pokeBlue,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      minimumSize: Size.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                    ),
                                  ),
                                ],
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
          );
        },
      );
    },
  );
}

void _openGiveHeldItemModal(
  BuildContext hostContext,
  Trainer trainer,
  PokemonInstance mon,
  VoidCallback? onUpdated,
) {
  final eligibleItems = ItemDatabase.allItems.values
      .where((item) =>
          (item.isBerry || item.isHeldItem) &&
          trainer.getItemCount(item.id) > 0)
      .toList();

  showModalBottomSheet(
    context: hostContext,
    backgroundColor: PokeColors.creamSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (dlgCtx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PokeSheetHeader(
              icon: Icons.shopping_bag_rounded,
              accentColor: PokeColors.bagOrange,
              title: 'GIVE ITEM TO ${mon.nickname.toUpperCase()}',
              onClose: () => Navigator.pop(dlgCtx),
            ),
            const SizedBox(height: 10),
            if (eligibleItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: PokeDecorations.inset(radius: 12),
                child: const Center(
                  child: Text(
                    'No Berries or Held Items in your Bag!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PokeColors.inkMuted, fontSize: 12),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(hostContext).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: eligibleItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, idx) {
                    final item = eligibleItems[idx];
                    final count = trainer.getItemCount(item.id);
                    return InkWell(
                      onTap: () {
                        final oldItem = mon.unequipHeldItem();
                        if (oldItem != null) {
                          trainer.adjustItemCount(oldItem, 1);
                        }
                        mon.equipHeldItem(item.id);
                        trainer.adjustItemCount(item.id, -1);
                        trainer.saveProgress();
                        onUpdated?.call();
                        Navigator.pop(dlgCtx);
                        if (hostContext.mounted) {
                          ScaffoldMessenger.of(hostContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${mon.nickname} is now holding ${item.name}!',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: PokeDecorations.card(
                          border: item.color.withOpacity(0.55),
                          radius: 12,
                          borderWidth: 1.4,
                        ),
                        child: Row(
                          children: [
                            Icon(item.icon, color: item.color, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.name} (x$count)',
                                    style: const TextStyle(
                                      color: PokeColors.inkDark,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      color: PokeColors.inkMuted,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}
