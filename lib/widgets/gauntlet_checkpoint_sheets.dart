import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../screens/pokemon_detail_screen.dart';
import 'hp_bar.dart';
import 'move_pp_picker_dialog.dart';

/// Shared 2x2 command grid for multi-stage gauntlets with rest checkpoints:
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: busy ? null : onNextBattle,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    nextBattleLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: nextBattleColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onBag,
                icon: const Icon(Icons.backpack_rounded, size: 16),
                label: const Text(
                  'BAG',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 0.4,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF121828),
                  foregroundColor: Colors.tealAccent,
                  side: const BorderSide(color: Colors.tealAccent),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onPokemon,
                icon: const Icon(Icons.catching_pokemon, size: 16),
                label: const Text(
                  'POKÉMON',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 0.4,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF121828),
                  foregroundColor: Colors.cyanAccent,
                  side: const BorderSide(color: Colors.cyanAccent),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : onGiveUp,
                icon: const Icon(Icons.flag_rounded, size: 16),
                label: const Text(
                  'GIVE UP',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11.5,
                    letterSpacing: 0.4,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1219),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
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
      backgroundColor: const Color(0xFF1E1E28),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
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
            style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold),
          ),
        ),
        TextButton(
          onPressed: () {
            if (ModalRoute.of(ctx)?.isCurrent == true) {
              Navigator.pop(ctx, true);
            }
          },
          child: const Text(
            'GIVE UP',
            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
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
    backgroundColor: const Color(0xFF1E1E28),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'USE ITEMS ON POKÉMON',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () {
                        if (isClosing) return;
                        if (ModalRoute.of(ctx)?.isCurrent == true) {
                          isClosing = true;
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (available.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        "You don't have any usable medicine items in your Bag!",
                        style: TextStyle(color: Colors.white38, fontSize: 13),
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

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF282836),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                itemDef?.icon ?? Icons.medical_services,
                                color: itemDef?.color ?? Colors.tealAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${itemDef?.name ?? itemId} (x$count)',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      itemDef?.description ?? '',
                                      style: const TextStyle(
                                        color: Colors.white54,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _selectPartyTargetAndApply(
                                  context,
                                  liveTrainer,
                                  itemId,
                                  onUpdated,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.tealAccent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                ),
                                child: const Text(
                                  'USE',
                                  style: TextStyle(fontWeight: FontWeight.bold),
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
        backgroundColor: const Color(0xFF1E1E28),
        title: Text(
          "USE ${ItemDatabase.byId(itemId)?.name.toUpperCase() ?? itemId.replaceAll('_', ' ').toUpperCase()} ON:",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
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
                tileColor: const Color(0xFF282836),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                title: Text(
                  '${mon.nickname} (HP ${mon.currentHp}/${mon.maxHp})',
                  style: TextStyle(
                    color: mon.isFainted ? Colors.white38 : Colors.white,
                    fontSize: 12,
                  ),
                ),
                subtitle: ItemDatabase.isPpRestoreItem(itemId)
                    ? Text(
                        "Total PP ${mon.moves.fold<int>(0, (s, m) => s + m.currentPp)}/${mon.moves.fold<int>(0, (s, m) => s + m.maxPp)}",
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 10,
                        ),
                      )
                    : mon.status != StatusCondition.none
                        ? Text(
                            'Status: ${mon.status.name.toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
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
    backgroundColor: const Color(0xFF121624),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MANAGE PARTY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            'Reorder squad, manage held items, or inspect moves & TMs',
                            style: TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () {
                          if (isClosing) return;
                          if (ModalRoute.of(ctx)?.isCurrent == true) {
                            isClosing = true;
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ],
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
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A2033),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isLead
                                  ? Colors.amberAccent.withOpacity(0.6)
                                  : typeColor.withOpacity(0.35),
                              width: isLead ? 1.4 : 1.0,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Image.network(
                                    mon.spriteUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.none,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.catching_pokemon,
                                      color: typeColor,
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isLead
                                                    ? Colors.amberAccent.withOpacity(0.2)
                                                    : Colors.white10,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isLead ? 'LEAD' : '#${idx + 1}',
                                                style: TextStyle(
                                                  color: isLead
                                                      ? Colors.amberAccent
                                                      : Colors.white60,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 7),
                                            Flexible(
                                              child: Text(
                                                mon.nickname,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Lv.${mon.level}',
                                              style: const TextStyle(
                                                color: Colors.amberAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        HpBar(currentHp: mon.currentHp, maxHp: mon.maxHp),
                                        const SizedBox(height: 4),
                                        Text(
                                          mon.moves.map((m) => m.name).join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: mon.hasHeldItem
                                                  ? Colors.amberAccent.withOpacity(0.4)
                                                  : Colors.white12,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                mon.hasHeldItem
                                                    ? Icons.shopping_bag
                                                    : Icons.shopping_bag_outlined,
                                                size: 13,
                                                color: mon.hasHeldItem
                                                    ? Colors.amberAccent
                                                    : Colors.white38,
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  mon.hasHeldItem
                                                      ? 'Held: ${ItemDatabase.byId(mon.heldItemId!)?.name ?? mon.heldItemId}'
                                                      : 'No held item',
                                                  style: TextStyle(
                                                    color: mon.hasHeldItem
                                                        ? Colors.amberAccent
                                                        : Colors.white38,
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
                                                      liveTrainer.adjustItemCount(
                                                          unequipped, 1);
                                                      liveTrainer.saveProgress();
                                                      onUpdated?.call();
                                                    }
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                    child: Text(
                                                      'TAKE',
                                                      style: TextStyle(
                                                        color: Colors.redAccent,
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              else
                                                InkWell(
                                                  onTap: () => _openGiveHeldItemModal(
                                                    context,
                                                    liveTrainer,
                                                    mon,
                                                    onUpdated,
                                                  ),
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                    child: Text(
                                                      'GIVE',
                                                      style: TextStyle(
                                                        color: Colors.cyanAccent,
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.bold,
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
                                        backgroundColor: Colors.amber.shade700,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 5,
                                        ),
                                        minimumSize: Size.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(9),
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
                                        color: Colors.greenAccent.withOpacity(0.14),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: Colors.greenAccent.withOpacity(0.4),
                                        ),
                                      ),
                                      child: const Text(
                                        'Active Lead',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
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
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        liveTrainer.swapPartySlots(idx, idx - 1);
                                        onUpdated?.call();
                                      },
                                    ),
                                  if (idx < liveTrainer.party.length - 1)
                                    IconButton(
                                      tooltip: 'Move Down',
                                      icon: const Icon(
                                        Icons.arrow_downward,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        liveTrainer.swapPartySlots(idx, idx + 1);
                                        onUpdated?.call();
                                      },
                                    ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PokemonDetailScreen(partyIndex: idx),
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
                                      foregroundColor: Colors.cyanAccent,
                                      side: BorderSide(
                                        color: Colors.cyanAccent.withOpacity(0.55),
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
    backgroundColor: const Color(0xFF121624),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GIVE ITEM TO ${mon.nickname.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.pop(dlgCtx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (eligibleItems.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No Berries or Held Items in your Bag!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
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
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2033),
                          borderRadius: BorderRadius.circular(12),
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
                                  Text(
                                    '${item.name} (x$count)',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      color: Colors.white54,
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
