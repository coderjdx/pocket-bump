import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../models/trainer_avatar.dart';
import '../services/pokedex_database.dart';
import '../services/step_counter_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/trainer_sprite.dart';
import 'battle_screen.dart';
import 'bump_screen.dart';
import 'pc_storage_screen.dart';
import 'pokedex_screen.dart';
import 'pokemon_league_screen.dart';
import 'poke_mart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _leadBobController;

  @override
  void initState() {
    super.initState();
    _leadBobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    StepCounterService.initialize(
      onStepDelta: (diff) {
        if (!mounted) return;
        final trainer = Provider.of<Trainer>(context, listen: false);
        final triggered = trainer.recordStepsAndCheckEncounter(diff);
        if (triggered) {
          StepCounterService.triggerEncounterAlert();
          _launchWildEncounter();
        }
      },
    );
  }

  @override
  void dispose() {
    _leadBobController.dispose();
    super.dispose();
  }

  void _launchWildEncounter() {
    final trainer = Provider.of<Trainer>(context, listen: false);
    trainer.resetEncounterSteps();
    final playerLevel = trainer.leadPokemon?.level ?? 5;
    final wildMon = PokedexDatabase.generateWildEncounter(playerLevel: playerLevel);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BattleScreen(opponentPokemon: wildMon, isWild: true),
      ),
    );
  }

  void _simulateSteps(Trainer trainer, int delta) {
    final triggered = trainer.recordStepsAndCheckEncounter(delta);
    if (triggered) {
      _launchWildEncounter();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final PokemonInstance? leadPokemon =
        trainer.party.isNotEmpty ? trainer.party.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFF14141C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/home_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0E111B).withOpacity(0.55),
                  const Color(0xFF14141C).withOpacity(0.42),
                  const Color(0xFF10121A).withOpacity(0.68),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  // ─── 1. COMPACT TRAINER PROFILE BAR ──────────────────────
                  _buildTrainerHeader(trainer),
                  const SizedBox(height: 10),

                  // ─── MAIN HOME DASHBOARD (NO SCROLLING ON STANDARD PHONES)
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ─── 2. SPOT #1 LEAD POKÉMON SHOWCASE ────────────
                          if (leadPokemon != null)
                            _buildLeadPokemonCard(trainer, leadPokemon),
                          const SizedBox(height: 10),

                          // ─── 3. POKÉWALKER STEP COUNTER ───────────────────
                          _buildStepCounterCard(trainer),
                          const SizedBox(height: 10),

                          // ─── 4. HUB OPTIONS (PARTY, BAG, POKÉDEX) ─────────
                          _buildHubRow(trainer),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ─── 5. CHALLENGE ANOTHER TRAINER (FIST-BUMP BATTLE) ─────
                  _buildChallengeTrainerButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. TRAINER IDENTITY HEADER ───────────────────────────────────────────
  Widget _buildTrainerHeader(Trainer trainer) {
    return GestureDetector(
      onTap: () => _openTrainerIdentityPicker(trainer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xD8242430),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: TrainerSpriteWidget(
                  avatar: trainer.avatar,
                  isBackView: false,
                  size: 42,
                ),
              ),
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
                          trainer.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 12, color: Colors.white38),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${trainer.avatar.title} • ${trainer.party.length}/6 Pokémon",
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars, color: Color(0xFFFFD54F), size: 12),
                      const SizedBox(width: 3),
                      Text(
                        "${trainer.clearedGymIds.length}/8",
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "₽",
                        style: TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "${trainer.money}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: "Delete Saved Progress",
              child: InkWell(
                onTap: () => _confirmDeleteProgress(trainer),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                  ),
                  child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 2. SPOT #1 LEAD POKÉMON CARD ─────────────────────────────────────────
  Widget _buildLeadPokemonCard(Trainer trainer, PokemonInstance lead) {
    final Color primaryColor = lead.species.types.first.color;
    final int prevLvlExp = (lead.level - 1) * (lead.level - 1) * (lead.level - 1);
    final int nextLvlExp = lead.expForNextLevel;
    final double expProgress = nextLvlExp > prevLvlExp
        ? ((lead.currentExp - prevLvlExp) / (nextLvlExp - prevLvlExp)).clamp(0.0, 1.0)
        : 0.0;
    final int expRemaining = max(0, nextLvlExp - lead.currentExp);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.24),
            const Color(0xD822222E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryColor.withOpacity(0.55), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top header badge + Swap Lead CTA
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: Colors.amberAccent, size: 12),
                    SizedBox(width: 3),
                    Text(
                      "LEAD POKÉMON • SPOT #1",
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _openPartyManagerModal(trainer),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_vert, color: Colors.white, size: 13),
                      SizedBox(width: 3),
                      Text(
                        "Swap Lead",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Sprite + Name/Level/Types/HP/EXP
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B23),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaryColor.withOpacity(0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _leadBobController,
                    builder: (context, child) {
                      final dy = -sin(_leadBobController.value * pi) * 2.5;
                      return Transform.translate(offset: Offset(0, dy), child: child);
                    },
                    child: Image.network(
                      lead.species.spriteUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (c, e, s) => Image.network(
                        lead.species.staticSpriteUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (c2, e2, s2) =>
                            Icon(Icons.catching_pokemon, color: primaryColor, size: 42),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            lead.nickname,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Lv.${lead.level}",
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: lead.species.types.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: t.color.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: t.color.withOpacity(0.8)),
                          ),
                          child: Text(
                            t.displayName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 5),
                    HpBar(currentHp: lead.currentHp, maxHp: lead.maxHp),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lead.level >= 100
                              ? "MAX LEVEL"
                              : "EXP • $expRemaining to Lv.${lead.level + 1}",
                          style: const TextStyle(fontSize: 9.5, color: Colors.lightBlueAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: expProgress,
                        minHeight: 3,
                        backgroundColor: Colors.black38,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Stat Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "ATK ${lead.atk} • DEF ${lead.def} • SPA ${lead.spa} • SPD ${lead.spd} • SPE ${lead.spe}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Known Moves Pills
          Wrap(
            spacing: 5,
            runSpacing: 4,
            children: lead.moves.map((m) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: m.type.color.withOpacity(0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: m.type.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      m.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${m.currentPp}/${m.maxPp}",
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── 3. DAILY STEP COUNTER CARD ───────────────────────────────────────────
  Widget _buildStepCounterCard(Trainer trainer) {
    final int stepsToday = trainer.todaySteps;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900.withOpacity(0.65), const Color(0xD822222E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.indigoAccent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.directions_walk, color: Colors.indigoAccent, size: 17),
                  SizedBox(width: 5),
                  Text(
                    "DAILY STEP COUNTER",
                    style: TextStyle(
                      color: Colors.indigoAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                "$stepsToday Steps Today",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _simulateSteps(trainer, 1),
                  icon: const Icon(Icons.directions_walk, size: 13),
                  label: const Text(
                    "+1 Step",
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.indigoAccent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _simulateSteps(trainer, 25),
                  icon: const Icon(Icons.add_circle_outline, size: 13),
                  label: const Text(
                    "+25 Steps",
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.indigoAccent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _launchWildEncounter,
                  icon: const Icon(Icons.explore, size: 13, color: Colors.black87),
                  label: const Text(
                    "Tall Grass",
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade400,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── 4. HUB OPTIONS (PARTY, BAG, POKÉDEX, GYMS, MART, PC BOXES) ──────────
  Widget _buildHubTile({
    required VoidCallback onTap,
    required Color accentColor,
    required Widget iconWidget,
    required String title,
    required String subtitle,
    Color subtitleColor = Colors.white60,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xD8242430),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: iconWidget,
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
                ],
              ),
              const SizedBox(height: 5),
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
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 10,
                  fontWeight: subtitleColor == Colors.white60
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHubRow(Trainer trainer) {
    final int totalSpecies = PokedexDatabase.species.length;
    final int caught = trainer.caughtCount;
    final int badges = trainer.clearedGymIds.length;

    return Column(
      children: [
        // Row 1: Party, Bag, Pokédex
        Row(
          children: [
            _buildHubTile(
              onTap: () => _openPartyManagerModal(trainer),
              accentColor: Colors.redAccent,
              iconWidget: const Icon(Icons.catching_pokemon,
                  color: Colors.redAccent, size: 16),
              title: "Party",
              subtitle: "${trainer.party.length}/6 Pokémon",
            ),
            const SizedBox(width: 8),
            _buildHubTile(
              onTap: () => _openItemsManagerModal(trainer),
              accentColor: Colors.amberAccent,
              iconWidget: const Icon(Icons.backpack,
                  color: Colors.amberAccent, size: 16),
              title: "Bag",
              subtitle: "${trainer.totalItems} Items",
            ),
            const SizedBox(width: 8),
            _buildHubTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PokedexScreen()),
                );
              },
              accentColor: Colors.redAccent,
              iconWidget: const PokeBallSymbol(size: 16, isCaught: true),
              title: "Pokédex",
              subtitle: "$caught/$totalSpecies",
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 2: Gyms & League, Poké Mart, PC Boxes
        Row(
          children: [
            _buildHubTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PokemonLeagueScreen()),
                );
              },
              accentColor: Colors.amberAccent,
              iconWidget: const Icon(Icons.military_tech,
                  color: Colors.amberAccent, size: 16),
              title: "Gyms",
              subtitle: "$badges/8 Badges",
              subtitleColor: Colors.amberAccent,
            ),
            const SizedBox(width: 8),
            _buildHubTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PokeMartScreen()),
                );
              },
              accentColor: Colors.cyanAccent,
              iconWidget: const Icon(Icons.storefront,
                  color: Colors.cyanAccent, size: 16),
              title: "Poké Mart",
              subtitle: "₽${trainer.money}",
              subtitleColor: const Color(0xFFFFD54F),
            ),
            const SizedBox(width: 8),
            _buildHubTile(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PcStorageScreen()),
                );
              },
              accentColor: Colors.purpleAccent,
              iconWidget: const Icon(Icons.computer,
                  color: Colors.purpleAccent, size: 16),
              title: "PC Boxes",
              subtitle: "${trainer.totalPcPokemon}/${trainer.maxPcCapacity}",
              subtitleColor: Colors.purpleAccent.shade100,
            ),
          ],
        ),
      ],
    );
  }

  // ─── 5. PRIMARY FIST-BUMP CHALLENGE CTA ───────────────────────────────────
  Widget _buildChallengeTrainerButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BumpScreen()),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade700, Colors.deepOrange.shade600],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade900.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.sports_mma, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CHALLENGE ANOTHER TRAINER",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          "FIST-BUMP BATTLE • DUEL A RIVAL",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── TRAINER AVATAR & NAME PICKER MODAL ───────────────────────────────────
  void _openTrainerIdentityPicker(Trainer trainer) {
    final nameController = TextEditingController(text: trainer.name);
    TrainerAvatar chosenAvatar = trainer.avatar;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TRAINER PROFILE & SETTINGS",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    maxLength: 14,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: "Trainer Name",
                      labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                      counterText: "",
                      filled: true,
                      fillColor: const Color(0xFF1E1E24),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: TrainerAvatar.presets.length,
                    itemBuilder: (c, idx) {
                      final av = TrainerAvatar.presets[idx];
                      final selected = av.id == chosenAvatar.id;
                      return GestureDetector(
                        onTap: () => setModalState(() => chosenAvatar = av),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.red.shade900.withOpacity(0.45)
                                : const Color(0xFF1E1E24),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? Colors.redAccent : Colors.white12,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TrainerSpriteWidget(
                                avatar: av,
                                isBackView: false,
                                size: 60,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                av.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        trainer.setIdentity(
                          newName: nameController.text,
                          newAvatar: chosenAvatar,
                        );
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        "SAVE PROFILE",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.save, size: 15, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Local Save Active (Retained Across Updates)",
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDeleteProgress(trainer, modalContext: ctx),
                      icon: const Icon(Icons.delete_forever, size: 18, color: Colors.redAccent),
                      label: const Text(
                        "DELETE SAVED PROGRESS",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(nameController.dispose);
  }

  void _confirmDeleteProgress(
    Trainer trainer, {
    BuildContext? modalContext,
  }) {
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              "Delete Saved Progress?",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "This will permanently erase your local save for ${trainer.name} "
          "(${trainer.party.length} Pokémon, ${trainer.totalSteps} steps, and ${trainer.totalItems} items) "
          "and return to the start screen.",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dlgCtx);
              if (modalContext != null && modalContext.mounted) {
                Navigator.pop(modalContext);
              }
              await trainer.deleteSaveAndReset();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text("Saved progress deleted. Starting a new adventure!"),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text("Delete Progress", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── PARTY MANAGER MODAL ──────────────────────────────────────────────────
  void _openPartyManagerModal(Trainer rootTrainer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF23232E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<Trainer>(
          builder: (context, trainer, _) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "MANAGE PARTY",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                "Slot #1 Pokémon is summoned first (${trainer.party.length}/6)",
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              this.context,
                              MaterialPageRoute(
                                  builder: (context) => const PcStorageScreen()),
                            );
                          },
                          icon: const Icon(Icons.computer, size: 14),
                          label: const Text(
                            "OPEN PC",
                            style: TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purpleAccent.shade100,
                            side: BorderSide(
                                color: Colors.purpleAccent.withOpacity(0.55)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.separated(
                        itemCount: trainer.party.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (c, idx) {
                          final mon = trainer.party[idx];
                          final isLead = idx == 0;
                          final typeColor = mon.species.types.first.color;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E2E3B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isLead ? Colors.amberAccent : Colors.white12,
                                width: isLead ? 1.8 : 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Image.network(
                                      mon.species.spriteUrl,
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.none,
                                      errorBuilder: (_, __, ___) => Image.network(
                                        mon.species.staticSpriteUrl,
                                        width: 54,
                                        height: 54,
                                        filterQuality: FilterQuality.none,
                                        errorBuilder: (_, __, ___) => Icon(
                                          Icons.catching_pokemon,
                                          color: typeColor,
                                          size: 40,
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
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isLead
                                                      ? Colors.amberAccent.withOpacity(0.2)
                                                      : Colors.white10,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isLead ? "SPOT #1 • LEAD" : "SPOT #${idx + 1}",
                                                  style: TextStyle(
                                                    color: isLead
                                                        ? Colors.amberAccent
                                                        : Colors.white60,
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  mon.nickname,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                "Lv.${mon.level}",
                                                style: const TextStyle(
                                                  color: Colors.amberAccent,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          HpBar(currentHp: mon.currentHp, maxHp: mon.maxHp),
                                          const SizedBox(height: 4),
                                          Text(
                                            mon.moves.map((m) => m.name).join(' • '),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.white60, fontSize: 10),
                                          ),
                                          const SizedBox(height: 5),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                                                  mon.hasHeldItem ? Icons.shopping_bag : Icons.shopping_bag_outlined,
                                                  size: 13,
                                                  color: mon.hasHeldItem ? Colors.amberAccent : Colors.white38,
                                                ),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(
                                                    mon.hasHeldItem
                                                        ? "Held: ${ItemDatabase.byId(mon.heldItemId!)?.name ?? mon.heldItemId}"
                                                        : "No held item",
                                                    style: TextStyle(
                                                      color: mon.hasHeldItem ? Colors.amberAccent : Colors.white38,
                                                      fontSize: 10,
                                                      fontWeight: mon.hasHeldItem ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                                if (mon.hasHeldItem)
                                                  InkWell(
                                                    onTap: () {
                                                      final unequipped = mon.unequipHeldItem();
                                                      if (unequipped != null) {
                                                        trainer.adjustItemCount(unequipped, 1);
                                                        trainer.saveProgress();
                                                      }
                                                    },
                                                    child: const Padding(
                                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      child: Text(
                                                        "TAKE",
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
                                                    onTap: () => _openGiveHeldItemModal(ctx, trainer, mon),
                                                    child: const Padding(
                                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      child: Text(
                                                        "GIVE",
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
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!isLead)
                                      ElevatedButton.icon(
                                        onPressed: () => trainer.setLeadPokemon(idx),
                                        icon: const Icon(Icons.star, size: 14),
                                        label: const Text(
                                          "Put in 1st Spot",
                                          style: TextStyle(
                                              fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber.shade700,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          minimumSize: Size.zero,
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10)),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.greenAccent.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                              color: Colors.greenAccent.withOpacity(0.4)),
                                        ),
                                        child: const Text(
                                          "Active Lead",
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    const Spacer(),
                                    if (idx > 0)
                                      IconButton(
                                        tooltip: "Move Up",
                                        icon: const Icon(Icons.arrow_upward,
                                            color: Colors.white70, size: 18),
                                        onPressed: () => trainer.swapPartySlots(idx, idx - 1),
                                      ),
                                    if (idx < trainer.party.length - 1)
                                      IconButton(
                                        tooltip: "Move Down",
                                        icon: const Icon(Icons.arrow_downward,
                                            color: Colors.white70, size: 18),
                                        onPressed: () => trainer.swapPartySlots(idx, idx + 1),
                                      ),
                                    if (trainer.party.length > 1) ...[
                                      IconButton(
                                        tooltip: "Deposit to PC Box",
                                        icon: Icon(Icons.inventory_2_outlined,
                                            color: Colors.purpleAccent.shade100,
                                            size: 18),
                                        onPressed: () {
                                          final ok = trainer.depositPokemonToPc(idx);
                                          ScaffoldMessenger.of(this.context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(ok
                                                  ? "${mon.nickname} was deposited into Box ${trainer.activePcBoxIndex + 1}!"
                                                  : "All 16 PC Boxes are full (320/320)!"),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        tooltip: "Release Pokémon",
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.redAccent, size: 18),
                                        onPressed: () => _confirmReleasePokemon(ctx, trainer, idx, mon),
                                      ),
                                    ],
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

  void _confirmReleasePokemon(
    BuildContext modalContext,
    Trainer trainer,
    int index,
    PokemonInstance mon,
  ) {
    showDialog(
      context: modalContext,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A35),
        title: Text(
          "Release ${mon.nickname}?",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Lv.${mon.level} ${mon.species.name} will be released from your carried party.",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              trainer.releasePokemon(index);
              Navigator.pop(dlgCtx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text("Release"),
          ),
        ],
      ),
    );
  }

  void _openGiveHeldItemModal(
    BuildContext parentContext,
    Trainer trainer,
    PokemonInstance mon,
  ) {
    final eligibleItems = ItemDatabase.allItems.values
        .where((item) =>
            (item.isBerry || item.isHeldItem) &&
            trainer.getItemCount(item.id) > 0)
        .toList();

    showModalBottomSheet(
      context: parentContext,
      backgroundColor: const Color(0xFF23232E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "GIVE ITEM TO ${mon.nickname.toUpperCase()}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            mon.hasHeldItem
                                ? "Current item: ${ItemDatabase.allItems[mon.heldItemId]?.name ?? mon.heldItemId} (will return to bag)"
                                : "No item currently held",
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(dlgCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (eligibleItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          "No Berries or Held Items in your Bag!\nFind berries on wild Pokémon or earn rare held items by re-challenging Gym Leaders.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: eligibleItems.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
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
                              Navigator.pop(dlgCtx);
                              ScaffoldMessenger.of(parentContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "${mon.nickname} is now holding ${item.name}!",
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E2E3B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: item.color.withOpacity(0.35)),
                              ),
                              child: Row(
                                children: [
                                  Icon(item.icon, color: item.color, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              item.name,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: item.color
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.isBerry
                                                    ? "BERRY"
                                                    : "HELD ITEM",
                                                style: TextStyle(
                                                  color: item.color,
                                                  fontSize: 8.5,
                                                  fontWeight:
                                                      FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          item.description,
                                          style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 10.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "x$count",
                                    style: TextStyle(
                                      color: item.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
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
      },
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
              "No Pokémon in your party can evolve using ${stoneItem.name}."),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: parentContext,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23232E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(stoneItem.icon, color: stoneItem.color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Use ${stoneItem.name}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select a party Pokémon to evolve:",
                style: TextStyle(color: Colors.white70, fontSize: 12),
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
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2E3B),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: stoneItem.color.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: Image.network(
                            mon.species.spriteUrl,
                            width: 42,
                            height: 42,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => Image.network(
                              mon.species.staticSpriteUrl,
                              width: 42,
                              height: 42,
                              filterQuality: FilterQuality.none,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.catching_pokemon,
                                color: Colors.white54,
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
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              Text(
                                "Lv. ${mon.level}",
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward,
                            color: Colors.white38, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          targetSpecies?.name ?? "???",
                          style: TextStyle(
                            color: stoneItem.color,
                            fontWeight: FontWeight.bold,
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
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
          ],
        );
      },
    );
  }

  void _executeStoneEvolution(
    BuildContext parentContext,
    Trainer trainer,
    PokemonInstance mon,
    Item stoneItem,
    PokemonSpecies nextSpecies,
  ) {
    if (trainer.getItemCount(stoneItem.id) <= 0) return;
    trainer.adjustItemCount(stoneItem.id, -1);
    final oldName = mon.nickname;
    final evoMoves = mon.evolve(
      nextSpecies,
      PokedexDatabase.movesUnlockedAtExactLevel(nextSpecies, mon.level),
    );
    trainer.markPokemonCaught(nextSpecies.id);
    trainer.saveProgress();
    HapticFeedback.heavyImpact();

    showDialog(
      context: parentContext,
      builder: (evoCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF23232E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              SizedBox(
                width: 90,
                height: 90,
                child: Image.network(
                  nextSpecies.spriteUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, __, ___) => Image.network(
                    nextSpecies.staticSpriteUrl,
                    width: 90,
                    height: 90,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.catching_pokemon,
                      color: Colors.white54,
                      size: 60,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                "CONGRATULATIONS!",
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Your $oldName evolved into ${nextSpecies.name}!",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              if (evoMoves.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  "Learned: ${evoMoves.join(', ')}!",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(evoCtx);
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amberAccent,
                foregroundColor: Colors.black,
              ),
              child: const Text("Awesome!",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ─── ITEMS MANAGER MODAL ──────────────────────────────────────────────────
  void _openItemsManagerModal(Trainer rootTrainer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF23232E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Consumer<Trainer>(
          builder: (context, trainer, _) {
            // Only display items the player actually possesses (count > 0)
            final availableItems = ItemDatabase.allItems.values
                .where((item) => trainer.getItemCount(item.id) > 0)
                .toList();

            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "MANAGE ITEMS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              "${trainer.totalItems} total items in Trainer Bag",
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          trainer.claimSupplyDrop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Claimed Supply Drop: +5 Poké Balls, +2 Great Balls, +1 Ultra Ball, +3 Potions, +1 Revive!",
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.card_giftcard, size: 18),
                        label: const Text(
                          "CLAIM POKÉ MART SUPPLY DROP (+ITEMS)",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: availableItems.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.inventory_2_outlined,
                                      size: 48, color: Colors.white24),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "Your Bag is empty!",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "Claim a Poké Mart supply drop above, visit the Poké Mart, or explore to get item drops from wild Pokémon encounters.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: availableItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (c, idx) {
                                final item = availableItems[idx];
                                final count = trainer.getItemCount(item.id);
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E2E3B),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: item.color.withOpacity(0.35)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: item.color.withOpacity(0.18),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Center(
                                          child: item.isBall
                                              ? PokeBallSpriteWidget(
                                                  ballType: item.id, size: 30)
                                              : Icon(item.icon,
                                                  color: item.color, size: 24),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    item.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13.5,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: item.color
                                                        .withOpacity(0.18),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: item.color
                                                          .withOpacity(0.6),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    item.rarity.name.toUpperCase(),
                                                    style: TextStyle(
                                                      color: item.color,
                                                      fontSize: 7.5,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.4,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black38,
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    "x$count",
                                                    style: TextStyle(
                                                      color: count > 0
                                                          ? item.color
                                                          : Colors.white38,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              item.description,
                                              style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 11),
                                            ),
                                            if (item.isMedicine) ...[
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                height: 28,
                                                child: OutlinedButton(
                                                  onPressed: count > 0
                                                      ? () {
                                                          trainer.adjustItemCount(
                                                              item.id, -1);
                                                          if (item.id ==
                                                              'antidote') {
                                                            trainer.curePartyStatus(
                                                                StatusCondition
                                                                    .poison);
                                                            ScaffoldMessenger.of(
                                                                    this.context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                    "Used ${item.name}! Poison cured for party Pokémon."),
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            2),
                                                              ),
                                                            );
                                                          } else if (item.id ==
                                                              'paralyze_heal') {
                                                            trainer.curePartyStatus(
                                                                StatusCondition
                                                                    .paralysis);
                                                            ScaffoldMessenger.of(
                                                                    this.context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                    "Used ${item.name}! Paralysis cured for party Pokémon."),
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            2),
                                                              ),
                                                            );
                                                          } else if (item.id ==
                                                              'awakening') {
                                                            trainer.curePartyStatus(
                                                                StatusCondition
                                                                    .sleep);
                                                            ScaffoldMessenger.of(
                                                                    this.context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                    "Used ${item.name}! Sleeping party Pokémon awakened."),
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            2),
                                                              ),
                                                            );
                                                          } else if (item.id ==
                                                              'burn_heal') {
                                                            trainer.curePartyStatus(
                                                                StatusCondition
                                                                    .burn);
                                                            ScaffoldMessenger.of(
                                                                    this.context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                    "Used ${item.name}! Burns healed for party Pokémon."),
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            2),
                                                              ),
                                                            );
                                                          } else if (item.id ==
                                                              'ice_heal') {
                                                            trainer.curePartyStatus(
                                                                StatusCondition
                                                                    .freeze);
                                                            ScaffoldMessenger.of(
                                                                    this.context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                    "Used ${item.name}! Frozen party Pokémon thawed."),
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            2),
                                                              ),
                                                            );
                                                          } else if (item.id ==
                                                              'full_heal') {
                                                            trainer
                                                                .cureAllPartyStatus();
                                                            ScaffoldMessenger.of(
                                                                    this.context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                    "Used ${item.name}! All status ailments cured for party Pokémon."),
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            2),
                                                              ),
                                                            );
                                                          } else if (item.id ==
                                                              'full_restore') {
                                                            trainer
                                                                .fullRestoreParty();
                                                            ScaffoldMessenger.of(
                                                                    this.context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                    "Used ${item.name}! Entire party restored to full HP and cured of all status ailments."),
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            2),
                                                              ),
                                                            );
                                                          } else {
                                                            trainer
                                                                .healAndResetAllParty();
                                                            ScaffoldMessenger.of(
                                                                    this.context)
                                                                .showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                    "Used ${item.name}! Entire party restored to full HP & PP."),
                                                                duration:
                                                                    const Duration(
                                                                        seconds:
                                                                            2),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      : null,
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: item.color,
                                                    side: BorderSide(color: item.color.withOpacity(0.6)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                  child: const Text(
                                                    "Use on Party",
                                                    style: TextStyle(
                                                        fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                            ] else if (item.isEvolutionStone) ...[
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                height: 28,
                                                child: ElevatedButton.icon(
                                                  onPressed: count > 0
                                                      ? () => _useEvolutionStone(ctx, trainer, item)
                                                      : null,
                                                  icon: const Icon(Icons.auto_awesome, size: 14),
                                                  label: const Text(
                                                    "Evolve Pokémon",
                                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: item.color.withOpacity(0.25),
                                                    foregroundColor: item.color,
                                                    side: BorderSide(color: item.color.withOpacity(0.7)),
                                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                            ] else if (item.isHeldItem || item.isBerry) ...[
                                              const SizedBox(height: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.06),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  item.isBerry
                                                      ? "Held item: auto-consumed in battle or equip via Party"
                                                      : "Held item: equip via Party to boost battle power",
                                                  style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        children: [
                                          IconButton(
                                            tooltip: "Add 1",
                                            onPressed: () => trainer.adjustItemCount(item.id, 1),
                                            icon: const Icon(Icons.add_circle_outline,
                                                color: Colors.white70, size: 20),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
                                          ),
                                          IconButton(
                                            tooltip: "Discard 1",
                                            onPressed: count > 0
                                                ? () => trainer.adjustItemCount(item.id, -1)
                                                : null,
                                            icon: Icon(
                                              Icons.remove_circle_outline,
                                              color: count > 0 ? Colors.redAccent : Colors.white24,
                                              size: 20,
                                            ),
                                            constraints: const BoxConstraints(),
                                            padding: const EdgeInsets.all(4),
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
}
