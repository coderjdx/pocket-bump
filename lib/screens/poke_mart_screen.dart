import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/trainer.dart';
import '../services/sound_service.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokeball_sprite.dart';

class PokeMartScreen extends StatefulWidget {
  const PokeMartScreen({super.key});

  @override
  State<PokeMartScreen> createState() => _PokeMartScreenState();
}

class _PokeMartScreenState extends State<PokeMartScreen> {
  ItemCategory? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final int badgeCount = trainer.clearedGymIds.length;

    final allBuyable = ItemDatabase.getMartItems(badgeCount)
      ..sort((a, b) => a.requiredBadges.compareTo(b.requiredBadges));
    final allLocked = ItemDatabase.getLockedMartItems(badgeCount);

    final ItemCategory? activeCategory =
        (_selectedCategory == ItemCategory.evolutionStone && badgeCount < 8)
            ? null
            : _selectedCategory;

    final filtered = activeCategory == null
        ? allBuyable
        : allBuyable.where((i) => i.category == activeCategory).toList();
    final lockedFiltered = activeCategory == null
        ? allLocked
        : allLocked.where((i) => i.category == activeCategory).toList();

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: "POKÉ MART",
        barColor: PokeColors.pokeBlue,
        bottomBorderColor: PokeColors.pokeBlueDark,
        actions: [
          PokeCurrencyPill(trainer.money),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/bg_poke_mart.png',
            topOpacity: 0.18,
            midOpacity: 0.44,
            bottomOpacity: 0.86,
          ),
          SafeArea(
            top: false,
            child: Column(
              children: [
                // Welcome & Stock Tier Banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: PokeDecorations.card(
                      fill: PokeColors.creamSurface,
                      border: PokeColors.pokeBlue,
                      radius: 16,
                      borderWidth: 1.6,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: PokeColors.pokeBlue.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: PokeColors.pokeBlue.withOpacity(0.55),
                            ),
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: PokeColors.pokeBlueDark, size: 22),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "KANTO DEPARTMENT COUNTER",
                                style: TextStyle(
                                  color: PokeColors.pokeBlueDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
                                  letterSpacing: 0.9,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                badgeCount >= 8
                                    ? "Earth Badge rank: Full Poké Mart & Evolution Stones stocked!"
                                    : "$badgeCount Badges: Higher-tier goods unlock as you earn more Badges.",
                                style: TextStyle(
                                  color: badgeCount >= 8
                                      ? PokeColors.badgeGoldDark
                                      : PokeColors.inkMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Category Filter Tabs
                Container(
                  height: 44,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildFilterChip("All Goods", null, activeCategory),
                      const SizedBox(width: 7),
                      _buildFilterChip(
                          "Poké Balls", ItemCategory.pokeball, activeCategory),
                      const SizedBox(width: 7),
                      _buildFilterChip(
                          "Medicine", ItemCategory.medicine, activeCategory),
                      if (badgeCount >= 8) ...[
                        const SizedBox(width: 7),
                        _buildFilterChip("Evolution Stones",
                            ItemCategory.evolutionStone, activeCategory),
                      ],
                    ],
                  ),
                ),

                // Unlocked Item Catalog + Upcoming Badge Unlocks
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
                    children: [
                      for (int idx = 0; idx < filtered.length; idx++) ...[
                        if (idx > 0) const SizedBox(height: 9),
                        _buildMartItemCard(
                          context: context,
                          trainer: trainer,
                          item: filtered[idx],
                          locked: false,
                        ),
                      ],
                      if (lockedFiltered.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: PokeDecorations.card(
                            fill: PokeColors.creamSurface,
                            border: PokeColors.badgeGold,
                            radius: 10,
                            borderWidth: 1.2,
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  color: PokeColors.badgeGoldDark, size: 15),
                              SizedBox(width: 6),
                              Text(
                                "BADGE PROGRESSION UNLOCKS",
                                style: TextStyle(
                                  color: PokeColors.badgeGoldDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (int idx = 0;
                            idx < lockedFiltered.length;
                            idx++) ...[
                          if (idx > 0) const SizedBox(height: 9),
                          _buildMartItemCard(
                            context: context,
                            trainer: trainer,
                            item: lockedFiltered[idx],
                            locked: true,
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMartItemCard({
    required BuildContext context,
    required Trainer trainer,
    required Item item,
    required bool locked,
  }) {
    final int userCount = trainer.getItemCount(item.id);
    final bool tmAlreadyOwned = item.isTm && trainer.hasTm(item.id);
    final Color itemDark = PokeColors.darken(item.color, 0.14);

    return Opacity(
      opacity: locked ? 0.72 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: PokeDecorations.card(
          fill: locked ? PokeColors.creamSurface : PokeColors.cardWhite,
          border: locked ? PokeColors.frameBorderSoft : item.color,
          radius: 15,
          borderWidth: 1.4,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: locked
                    ? PokeColors.panelSoft
                    : item.color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: locked
                      ? PokeColors.frameBorderSoft
                      : item.color.withOpacity(0.6),
                ),
              ),
              child: Center(
                child: item.isBall
                    ? PokeBallSpriteWidget(ballType: item.id, size: 28)
                    : Icon(
                        locked ? Icons.lock_rounded : item.icon,
                        color: locked ? PokeColors.inkSubtle : itemDark,
                        size: 23,
                      ),
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
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: PokeColors.inkDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (!locked && userCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: PokeDecorations.inset(radius: 6),
                          child: Text(
                            item.isTm ? "BAG ∞" : "BAG x$userCount",
                            style: const TextStyle(
                              color: PokeColors.pokeBlueDark,
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
                    item.description,
                    style: const TextStyle(
                      color: PokeColors.inkMuted,
                      fontSize: 10.8,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₽${item.price}",
                  style: TextStyle(
                    color:
                        locked ? PokeColors.inkSubtle : PokeColors.badgeGoldDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 6),
                if (locked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: PokeColors.panelSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: PokeColors.badgeGold),
                    ),
                    child: Text(
                      "${item.requiredBadges} BADGE${item.requiredBadges == 1 ? '' : 'S'}",
                      style: const TextStyle(
                        color: PokeColors.badgeGoldDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 9.5,
                      ),
                    ),
                  )
                else if (tmAlreadyOwned)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: PokeColors.pokeBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: PokeColors.pokeBlue),
                    ),
                    child: const Text(
                      "OWNED",
                      style: TextStyle(
                        color: PokeColors.pokeBlueDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.6,
                      ),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: () => _openBuyDialog(context, trainer, item),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PokeColors.pokeGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text(
                      "BUY",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      String label, ItemCategory? category, ItemCategory? activeCategory) {
    final isSelected = activeCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? PokeColors.pokeBlue : PokeColors.cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? PokeColors.pokeBlueDark
                : PokeColors.frameBorderSoft,
            width: 1.4,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : PokeColors.inkDark,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }

  // === BUY QUANTITY MODAL ===
  void _openBuyDialog(BuildContext context, Trainer trainer, Item item) {
    if (item.isTm && trainer.hasTm(item.id)) return;
    int quantity = 1;
    final int itemPrice = item.price ?? 0;
    final int maxAllowed = item.isTm ? 1 : 99;
    final int maxAffordable = itemPrice > 0
        ? (trainer.money ~/ itemPrice).clamp(0, maxAllowed)
        : maxAllowed;

    showModalBottomSheet(
      context: context,
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final int totalCost = quantity * itemPrice;
            final bool canAfford = trainer.money >= totalCost && quantity > 0;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(11),
                          border:
                              Border.all(color: item.color.withOpacity(0.55)),
                        ),
                        child: Center(
                          child: item.isBall
                              ? PokeBallSpriteWidget(ballType: item.id, size: 28)
                              : Icon(item.icon, color: item.color, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "PURCHASE ${item.name.toUpperCase()}",
                              style: const TextStyle(
                                color: PokeColors.inkDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              "Unit Price: ₽$itemPrice",
                              style: const TextStyle(
                                color: PokeColors.badgeGoldDark,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: PokeColors.inkMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: PokeDecorations.card(
                      fill: PokeColors.cardWhite,
                      border: PokeColors.frameBorderSoft,
                      radius: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "QUANTITY",
                          style: TextStyle(
                            color: PokeColors.inkMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: quantity > 1
                                  ? () => setModalState(() => quantity--)
                                  : null,
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: quantity > 1
                                    ? PokeColors.pokeBlue
                                    : PokeColors.inkSubtle,
                              ),
                            ),
                            Text(
                              "$quantity",
                              style: const TextStyle(
                                color: PokeColors.inkDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  (quantity < maxAffordable && quantity < 99)
                                      ? () => setModalState(() => quantity++)
                                      : null,
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: (quantity < maxAffordable &&
                                        quantity < 99)
                                    ? PokeColors.pokeBlue
                                    : PokeColors.inkSubtle,
                              ),
                            ),
                            if (maxAffordable > 1) ...[
                              TextButton(
                                onPressed: () =>
                                    setModalState(() => quantity = maxAffordable),
                                child: const Text(
                                  "MAX",
                                  style: TextStyle(
                                    color: PokeColors.pokeBlueDark,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "TOTAL COST",
                        style: TextStyle(
                          color: PokeColors.inkMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                      Text(
                        "₽$totalCost",
                        style: TextStyle(
                          color: canAfford
                              ? PokeColors.badgeGoldDark
                              : PokeColors.pokeRed,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: canAfford
                          ? () {
                              if (trainer.spendMoney(totalCost)) {
                                trainer.adjustItemCount(item.id, quantity);
                                trainer.saveProgress();
                                HapticFeedback.mediumImpact();
                                SoundService.instance.playUiBuy();
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        "Purchased $quantity x ${item.name} for ₽$totalCost!"),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.pokeGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: PokeColors.panelSoft,
                        disabledForegroundColor: PokeColors.inkSubtle,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13)),
                      ),
                      child: Text(
                        canAfford
                            ? "CONFIRM PURCHASE (₽$totalCost)"
                            : "INSUFFICIENT FUNDS",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.7,
                        ),
                      ),
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
}
