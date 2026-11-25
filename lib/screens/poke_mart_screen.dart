import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/trainer.dart';
import '../services/sound_service.dart';
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

    // Only list items currently unlocked for purchase at this badge tier
    final allBuyable = ItemDatabase.getMartItems(badgeCount)
      ..sort((a, b) => a.requiredBadges.compareTo(b.requiredBadges));
    final allLocked = ItemDatabase.getLockedMartItems(badgeCount);

    final ItemCategory? activeCategory =
        (_selectedCategory == ItemCategory.evolutionStone && badgeCount < 8)
            ? null
            : _selectedCategory;

    // Filter by active category tab
    final filtered = activeCategory == null
        ? allBuyable
        : allBuyable.where((i) => i.category == activeCategory).toList();
    final lockedFiltered = activeCategory == null
        ? allLocked
        : allLocked.where((i) => i.category == activeCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0C121E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xCC0A101C),
        elevation: 0,
        title: const Text(
          "POKÉ MART",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Currency balance chip
          Container(
            margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF080C14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFFD54F).withOpacity(0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "₽",
                  style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "${trainer.money}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_poke_mart.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0B1424).withOpacity(0.72),
                  const Color(0xFF0E1628).withOpacity(0.60),
                  const Color(0xFF080D18).withOpacity(0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Welcome & Stock Tier Banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xE8132036), Color(0xE80C1422)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.cyanAccent.withOpacity(0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF09101C),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                                color: Colors.cyanAccent.withOpacity(0.45)),
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: Colors.cyanAccent, size: 22),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "KANTO DEPARTMENT COUNTER",
                                style: TextStyle(
                                  color: Colors.cyanAccent,
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
                                      ? Colors.amberAccent
                                      : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
                        const Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                color: Colors.amberAccent, size: 15),
                            SizedBox(width: 6),
                            Text(
                              "BADGE PROGRESSION UNLOCKS",
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.9,
                              ),
                            ),
                          ],
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
    return Opacity(
      opacity: locked ? 0.58 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              item.color.withOpacity(locked ? 0.06 : 0.14),
              const Color(0xEA141B2D),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: locked ? Colors.white12 : item.color.withOpacity(0.45),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0F1A),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: locked ? Colors.white12 : item.color.withOpacity(0.5),
                ),
              ),
              child: Center(
                child: item.isBall
                    ? PokeBallSpriteWidget(ballType: item.id, size: 28)
                    : Icon(
                        locked ? Icons.lock_rounded : item.icon,
                        color: locked ? Colors.white38 : item.color,
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
                            color: Colors.white,
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
                          decoration: BoxDecoration(
                            color: const Color(0xFF090D16),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            item.isTm ? "BAG ∞" : "BAG x$userCount",
                            style: const TextStyle(
                              color: Colors.cyanAccent,
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
                      color: Colors.white70,
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
                    color: locked ? Colors.white54 : const Color(0xFFFFD54F),
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
                      color: const Color(0xFF0A0E18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.amberAccent.withOpacity(0.45)),
                    ),
                    child: Text(
                      "${item.requiredBadges} BADGE${item.requiredBadges == 1 ? '' : 'S'}",
                      style: const TextStyle(
                        color: Colors.amberAccent,
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
                      color: const Color(0xFF0A0E18),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.cyanAccent.withOpacity(0.45)),
                    ),
                    child: const Text(
                      "OWNED",
                      style: TextStyle(
                        color: Colors.cyanAccent,
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
                      backgroundColor: const Color(0xFF2E9E5B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                        side: BorderSide(color: Colors.white.withOpacity(0.25)),
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
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00B0FF)],
                )
              : null,
          color: isSelected ? null : const Color(0xDD131B2C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white12,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
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
      backgroundColor: const Color(0xFF0F1626),
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
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: item.color.withOpacity(0.55)),
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
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              "Unit Price: ₽$itemPrice",
                              style: const TextStyle(
                                color: Color(0xFFFFD54F),
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white60),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quantity Stepper
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151E32),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "QUANTITY",
                          style: TextStyle(
                            color: Colors.white70,
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
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.white70),
                            ),
                            Text(
                              "$quantity",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            IconButton(
                              onPressed: (quantity < maxAffordable && quantity < 99)
                                  ? () => setModalState(() => quantity++)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.white70),
                            ),
                            if (maxAffordable > 1) ...[
                              TextButton(
                                onPressed: () =>
                                    setModalState(() => quantity = maxAffordable),
                                child: const Text(
                                  "MAX",
                                  style: TextStyle(
                                    color: Colors.cyanAccent,
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

                  // Cost calculation row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "TOTAL COST",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                      Text(
                        "₽$totalCost",
                        style: TextStyle(
                          color: canAfford ? const Color(0xFFFFD54F) : Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Buy Button
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
                        backgroundColor: const Color(0xFF2E9E5B),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white10,
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
