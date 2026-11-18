import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
import '../widgets/hp_bar.dart';
import 'poke_mart_screen.dart';

class PokemonCenterScreen extends StatefulWidget {
  const PokemonCenterScreen({super.key});

  @override
  State<PokemonCenterScreen> createState() => _PokemonCenterScreenState();
}

class _PokemonCenterScreenState extends State<PokemonCenterScreen> {
  void _healParty(Trainer trainer) {
    trainer.healAndResetAllParty();
    trainer.saveProgress();
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Your entire party was restored to perfect condition! Full HP, PP, and status cured.",
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Color _statusColor(StatusCondition status) {
    switch (status) {
      case StatusCondition.burn:
        return Colors.deepOrange;
      case StatusCondition.poison:
        return Colors.purple;
      case StatusCondition.paralysis:
        return Colors.amber.shade700;
      case StatusCondition.sleep:
        return Colors.blueGrey;
      case StatusCondition.freeze:
        return Colors.cyan;
      case StatusCondition.none:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final int fossils = trainer.getItemCount('unknown_fossil');
    final int vouchers = trainer.getItemCount('fossil_restoration_voucher');
    final bool needsHeal = trainer.party.any(
      (mon) =>
          mon.currentHp < mon.maxHp ||
          mon.status != StatusCondition.none ||
          mon.moves.any((m) => m.currentPp < m.maxPp),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF16121A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.45),
        elevation: 0,
        title: const Text(
          "POKÉMON CENTER",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.9,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  "${trainer.money}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
            'assets/images/bg_pokemon_center.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF181018).withOpacity(0.72),
                  const Color(0xFF16121C).withOpacity(0.58),
                  const Color(0xFF121018).withOpacity(0.84),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome & Recovery Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xD8281D26),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.pinkAccent.withOpacity(0.45),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.local_hospital,
                            color: Colors.pinkAccent,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Welcome to the Pokémon Center!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Restore your party's HP, PP & status, shop at the Poké Mart, or restore fossils at the Pokémon Lab.",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Party Health Overview
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xD61F1E2A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "PARTY CONDITION",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (needsHeal
                                          ? Colors.amberAccent
                                          : Colors.greenAccent)
                                      .withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  needsHeal ? "NEEDS CARE" : "FULL HEALTH",
                                  style: TextStyle(
                                    color: needsHeal
                                        ? Colors.amberAccent
                                        : Colors.greenAccent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.separated(
                              itemCount: trainer.party.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (_, idx) {
                                final mon = trainer.party[idx];
                                final curPp = mon.moves
                                    .fold<int>(0, (s, m) => s + m.currentPp);
                                final maxPp = mon.moves
                                    .fold<int>(0, (s, m) => s + m.maxPp);

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF282736),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: mon.isFainted
                                          ? Colors.redAccent.withOpacity(0.4)
                                          : Colors.white10,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Opacity(
                                        opacity: mon.isFainted ? 0.45 : 1.0,
                                        child: Image.network(
                                          mon.species.spriteUrl,
                                          width: 38,
                                          height: 38,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.none,
                                          errorBuilder: (_, __, ___) =>
                                              Image.network(
                                            mon.species.staticSpriteUrl,
                                            width: 38,
                                            height: 38,
                                            fit: BoxFit.contain,
                                            filterQuality: FilterQuality.none,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.catching_pokemon,
                                              color: Colors.white54,
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
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
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "Lv.${mon.level}",
                                                  style: const TextStyle(
                                                    color: Colors.amberAccent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10.5,
                                                  ),
                                                ),
                                                if (mon.isFainted) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 5,
                                                        vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.redAccent
                                                          .withOpacity(0.22),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: const Text(
                                                      "FAINTED",
                                                      style: TextStyle(
                                                        color: Colors.redAccent,
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ] else if (mon.status !=
                                                    StatusCondition.none) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 5,
                                                        vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: _statusColor(
                                                          mon.status),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: Text(
                                                      mon.status.shortLabel,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: HpBar(
                                                    currentHp: mon.currentHp,
                                                    maxHp: mon.maxHp,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "${mon.currentHp}/${mon.maxHp} • PP $curPp/$maxPp",
                                                  style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
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

                  const SizedBox(height: 10),

                  // 1. Heal Pokemon Button
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _healParty(trainer),
                      icon: const Icon(Icons.favorite, size: 20),
                      label: const Text(
                        "HEAL POKÉMON",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.7,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 2 & 3. Poke Mart and Pokemon Lab Options
                  Row(
                    children: [
                      Expanded(
                        child: _buildFacilityTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PokeMartScreen(),
                              ),
                            );
                          },
                          icon: Icons.storefront,
                          accentColor: Colors.cyanAccent,
                          title: "Poké Mart",
                          subtitle: "Items & Medicine",
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFacilityTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PokemonLabScreen(),
                              ),
                            );
                          },
                          icon: Icons.science,
                          accentColor: const Color(0xFF4DD0E1),
                          title: "Pokémon Lab",
                          subtitle: "$fossils Fossil • $vouchers Voucher",
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

  Widget _buildFacilityTile({
    required VoidCallback onTap,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xD8222332),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.55)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
          ],
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

    final fossilPool = PokedexDatabase.firstStageFossilSpeciesIds;
    final chosenId = fossilPool[Random().nextInt(fossilPool.length)];
    final restoredMon = PokedexDatabase.createPokemon(
      chosenId,
      level: 10,
      respectMinEncounterLevel: false,
    );
    final boxNum = trainer.addPokemon(restoredMon);
    trainer.saveProgress();
    HapticFeedback.heavyImpact();

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1F222D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.science, color: Color(0xFF4DD0E1), size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "FOSSIL RESTORATION COMPLETE!",
                style: TextStyle(
                  color: Color(0xFF4DD0E1),
                  fontWeight: FontWeight.bold,
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
                restoredMon.species.spriteUrl,
                width: 90,
                height: 90,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, __, ___) => Image.network(
                  restoredMon.species.staticSpriteUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.catching_pokemon,
                    color: Colors.white54,
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
                color: Colors.white,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              boxNum == null
                  ? "${restoredMon.species.name} joined your Party!"
                  : "${restoredMon.species.name} was transferred to PC Box #$boxNum!",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.amberAccent,
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
              backgroundColor: const Color(0xFF4DD0E1),
              foregroundColor: Colors.black,
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
      backgroundColor: const Color(0xFF10161E),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.45),
        elevation: 0,
        title: const Text(
          "POKÉMON LAB",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.9,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_pokemon_lab.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0E161E).withOpacity(0.68),
                  const Color(0xFF0F1822).withOpacity(0.56),
                  const Color(0xFF0B1218).withOpacity(0.84),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xD81B232E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4DD0E1).withOpacity(0.45),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.science,
                          color: Color(0xFF4DD0E1),
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ancient Fossil Restoration Chamber",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                "Combine 1 Unknown Fossil and 1 Fossil Restoration Voucher to revive a random Lv. 10 first-stage Fossil Pokémon!",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Counts of Unknown Fossil and Fossil Restoration Voucher
                  Row(
                    children: [
                      Expanded(
                        child: _buildCountCard(
                          icon: Icons.album,
                          color: const Color(0xFFD7CCC8),
                          title: "Unknown Fossils",
                          count: fossils,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildCountCard(
                          icon: Icons.science,
                          color: const Color(0xFF4DD0E1),
                          title: "Restoration Vouchers",
                          count: vouchers,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Possible Revived Fossil Species Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xD61A202B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "PREHISTORIC POKÉMON REVIVAL POOL (Lv. 10)",
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: PokedexDatabase.firstStageFossilSpeciesIds
                                .map((id) {
                              final spec = PokedexDatabase.species[id]!;
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      color: Colors.black38,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFF4DD0E1)
                                            .withOpacity(0.35),
                                      ),
                                    ),
                                    child: Center(
                                      child: Image.network(
                                        spec.spriteUrl,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.none,
                                        errorBuilder: (_, __, ___) =>
                                            Image.network(
                                          spec.staticSpriteUrl,
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.none,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.catching_pokemon,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    spec.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Text(
                                    "Lv. 10",
                                    style: TextStyle(
                                      color: Color(0xFF4DD0E1),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Unknown Fossils and Fossil Restoration Vouchers drop as rare rewards when re-challenging Kanto Gym Leaders.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: canRestore ? () => _restoreFossil(trainer) : null,
                      icon: const Icon(Icons.biotech, size: 20),
                      label: Text(
                        canRestore
                            ? "RESTORE FOSSIL (1 FOSSIL + 1 VOUCHER)"
                            : (trainer.isStorageFull
                                ? "STORAGE FULL (320/320)"
                                : "NEED 1 FOSSIL & 1 VOUCHER"),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4DD0E1),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.white12,
                        disabledForegroundColor: Colors.white38,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xD81D2430),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: count > 0 ? color.withOpacity(0.65) : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            "x$count",
            style: TextStyle(
              color: count > 0 ? color : Colors.white38,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
