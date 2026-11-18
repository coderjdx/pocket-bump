import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/trainer.dart';
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

    // Get all buyable items in the game
    final allBuyable = ItemDatabase.allItems.values.where((i) => i.isBuyable).toList()
      ..sort((a, b) => a.requiredBadges.compareTo(b.requiredBadges));

    // Filter by selected category tab
    final filtered = _selectedCategory == null
        ? allBuyable
        : allBuyable.where((i) => i.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF16161E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2C),
        elevation: 0,
        title: const Text(
          "POKÉ MART",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Currency balance chip
          Container(
            margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD54F).withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "₽",
                  style: TextStyle(
                    color: Color(0xFFFFD54F),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "${trainer.money}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Welcome & Badge Status Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF222232),
              child: Row(
                children: [
                  const Icon(Icons.storefront, color: Colors.cyanAccent, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Welcome to the Poké Mart!",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          badgeCount >= 8
                              ? "Earth Badge unlocked: All Evolution Stones now available!"
                              : "$badgeCount Badges: Unlock higher tier items by defeating Gyms.",
                          style: TextStyle(
                            color: badgeCount >= 8 ? Colors.amberAccent : Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Category Filter Tabs
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip("All Items", null),
                  const SizedBox(width: 6),
                  _buildFilterChip("Poké Balls", ItemCategory.pokeball),
                  const SizedBox(width: 6),
                  _buildFilterChip("Medicine", ItemCategory.medicine),
                  const SizedBox(width: 6),
                  _buildFilterChip("Evolution Stones", ItemCategory.evolutionStone),
                ],
              ),
            ),

            // Item List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, idx) {
                  final item = filtered[idx];
                  final bool isUnlocked = badgeCount >= item.requiredBadges;
                  final int userCount = trainer.getItemCount(item.id);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? const Color(0xFF232332)
                          : const Color(0xFF1A1A24),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isUnlocked
                            ? item.color.withOpacity(0.35)
                            : Colors.white.withOpacity(0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Item Icon / Sprite
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isUnlocked
                                ? item.color.withOpacity(0.18)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: item.isBall
                                ? PokeBallSpriteWidget(ballType: item.id, size: 28)
                                : Icon(
                                    item.icon,
                                    color: isUnlocked ? item.color : Colors.white24,
                                    size: 22,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Item Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      color: isUnlocked ? Colors.white : Colors.white38,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (userCount > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: Colors.black38,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "Owned: $userCount",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.description,
                                style: TextStyle(
                                  color: isUnlocked ? Colors.white60 : Colors.white24,
                                  fontSize: 11,
                                ),
                              ),
                              if (!isUnlocked) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.lock, color: Colors.amberAccent, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Requires ${item.requiredBadges} Gym Badges to purchase",
                                      style: const TextStyle(
                                        color: Colors.amberAccent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Price & Buy Button
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "₽${item.price}",
                              style: TextStyle(
                                color: isUnlocked ? const Color(0xFFFFD54F) : Colors.white24,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton(
                              onPressed: isUnlocked
                                  ? () => _openBuyDialog(context, trainer, item)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.white.withOpacity(0.06),
                                disabledForegroundColor: Colors.white24,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                "BUY",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
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
  }

  Widget _buildFilterChip(String label, ItemCategory? category) {
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedCategory = category),
      selectedColor: Colors.cyanAccent,
      backgroundColor: const Color(0xFF222230),
      visualDensity: VisualDensity.compact,
    );
  }

  // === BUY QUANTITY MODAL ===
  void _openBuyDialog(BuildContext context, Trainer trainer, Item item) {
    int quantity = 1;
    final int itemPrice = item.price ?? 0;
    final int maxAffordable = itemPrice > 0 ? (trainer.money ~/ itemPrice).clamp(0, 99) : 99;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
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
                              "Purchase ${item.name}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              "Price: ₽$itemPrice each",
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quantity Stepper
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF272738),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Quantity",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: quantity > 1
                                  ? () => setModalState(() => quantity--)
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
                            ),
                            Text(
                              "$quantity",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: (quantity < maxAffordable && quantity < 99)
                                  ? () => setModalState(() => quantity++)
                                  : null,
                              icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
                            ),
                            if (maxAffordable > 1) ...[
                              TextButton(
                                onPressed: () => setModalState(() => quantity = maxAffordable),
                                child: const Text("MAX", style: TextStyle(color: Colors.cyanAccent)),
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
                        "Total Cost:",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        "₽$totalCost",
                        style: TextStyle(
                          color: canAfford ? const Color(0xFFFFD54F) : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Buy Button
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: canAfford
                          ? () {
                              if (trainer.spendMoney(totalCost)) {
                                trainer.adjustItemCount(item.id, quantity);
                                trainer.saveProgress();
                                HapticFeedback.mediumImpact();
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Purchased $quantity x ${item.name} for ₽$totalCost!"),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        canAfford ? "CONFIRM PURCHASE (₽$totalCost)" : "INSUFFICIENT FUNDS",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
