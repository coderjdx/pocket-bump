import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_instance.dart';
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
import 'pokedex_screen.dart';

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
      backgroundColor: const Color(0xFF1E1E24),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            children: [
              // ─── 1. COMPACT TRAINER PROFILE BAR ──────────────────────────
              _buildTrainerHeader(trainer),
              const SizedBox(height: 14),

              // ─── SCROLLABLE MAIN HOME DASHBOARD ──────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── 2. SPOT #1 LEAD POKÉMON SHOWCASE ────────────────
                      if (leadPokemon != null)
                        _buildLeadPokemonCard(trainer, leadPokemon),
                      const SizedBox(height: 14),

                      // ─── 3. POKÉWALKER STEP COUNTER ───────────────────────
                      _buildStepCounterCard(trainer),
                      const SizedBox(height: 14),

                      // ─── 4. PARTY & ITEM MANAGEMENT OPTIONS ──────────────
                      _buildManagementRow(trainer),
                      const SizedBox(height: 12),

                      // ─── 4B. KANTO POKÉDEX CARD ──────────────────────────
                      _buildPokedexCard(trainer),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── 5. CHALLENGE ANOTHER TRAINER (FIST-BUMP BATTLE) ─────────
              _buildChallengeTrainerButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── 1. TRAINER IDENTITY HEADER ───────────────────────────────────────────
  Widget _buildTrainerHeader(Trainer trainer) {
    return GestureDetector(
      onTap: () => _openTrainerIdentityPicker(trainer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: TrainerSpriteWidget(
                  avatar: trainer.avatar,
                  isBackView: false,
                  size: 50,
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
                          trainer.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.edit, size: 13, color: Colors.white38),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "${trainer.avatar.title} • ${trainer.party.length}/6 Pokémon",
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.catching_pokemon, color: Colors.redAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${trainer.pokeBalls + trainer.greatBalls + trainer.ultraBalls}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.medical_services, color: Colors.greenAccent, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${trainer.potions + trainer.revives}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: "Delete Saved Progress",
              child: InkWell(
                onTap: () => _confirmDeleteProgress(trainer),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                  ),
                  child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 18),
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.22),
            const Color(0xFF2A2A35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primaryColor.withOpacity(0.55), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, color: Colors.amberAccent, size: 13),
                    SizedBox(width: 4),
                    Text(
                      "FIRST SPOT • SUMMONED FIRST",
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _openPartyManagerModal(trainer),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_vert, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "Swap Lead",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Sprite + Name/Level/Types/HP/EXP/Stats
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B23),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primaryColor.withOpacity(0.45)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedBuilder(
                    animation: _leadBobController,
                    builder: (context, child) {
                      final dy = -sin(_leadBobController.value * pi) * 3.0;
                      return Transform.translate(offset: Offset(0, dy), child: child);
                    },
                    child: Image.network(
                      lead.species.spriteUrl,
                      width: 74,
                      height: 74,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (c, e, s) => Image.network(
                        lead.species.staticSpriteUrl,
                        width: 74,
                        height: 74,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (c2, e2, s2) =>
                            Icon(Icons.catching_pokemon, color: primaryColor, size: 52),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Lv.${lead.level}",
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: lead.species.types.map((t) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: t.color.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: t.color.withOpacity(0.8)),
                          ),
                          child: Text(
                            t.displayName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    HpBar(currentHp: lead.currentHp, maxHp: lead.maxHp),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lead.level >= 100
                              ? "MAX LEVEL"
                              : "EXP • $expRemaining to Lv.${lead.level + 1}",
                          style: const TextStyle(fontSize: 10, color: Colors.lightBlueAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: expProgress,
                        minHeight: 4,
                        backgroundColor: Colors.black38,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlueAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Stat Strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "ATK ${lead.atk} • DEF ${lead.def} • SPA ${lead.spa} • SPD ${lead.spd} • SPE ${lead.spe}",
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Known Moves Pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: lead.moves.map((m) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: m.type.color.withOpacity(0.55)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: m.type.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${m.currentPp}/${m.maxPp}",
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900.withOpacity(0.55), const Color(0xFF2A2A35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
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
                  Icon(Icons.directions_walk, color: Colors.indigoAccent, size: 19),
                  SizedBox(width: 6),
                  Text(
                    "DAILY STEP COUNTER",
                    style: TextStyle(
                      color: Colors.indigoAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Text(
                "$stepsToday Steps Today",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Walking in the real world has a chance to trigger wild Pokémon encounters!",
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _simulateSteps(trainer, 1),
                  icon: const Icon(Icons.directions_walk, size: 15),
                  label: const Text(
                    "+1 Step",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.indigoAccent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _simulateSteps(trainer, 25),
                  icon: const Icon(Icons.add_circle_outline, size: 15),
                  label: const Text(
                    "+25 Steps",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.indigoAccent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _launchWildEncounter,
                  icon: const Icon(Icons.explore, size: 15, color: Colors.black87),
                  label: const Text(
                    "Tall Grass",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade400,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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

  // ─── 4. PARTY & ITEMS MANAGEMENT CARDS ────────────────────────────────────
  Widget _buildManagementRow(Trainer trainer) {
    final int ballTotal = trainer.pokeBalls + trainer.greatBalls + trainer.ultraBalls;
    final int medTotal = trainer.potions + trainer.revives;

    return Row(
      children: [
        // Manage Party Card
        Expanded(
          child: InkWell(
            onTap: () => _openPartyManagerModal(trainer),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.catching_pokemon, color: Colors.redAccent, size: 20),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Manage Party",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${trainer.party.length}/6 Pokémon • Set Lead",
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 26,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: trainer.party.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 4),
                      itemBuilder: (context, idx) {
                        final mon = trainer.party[idx];
                        return Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E24),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: idx == 0 ? Colors.amberAccent : Colors.white24,
                              width: idx == 0 ? 1.5 : 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              mon.species.staticSpriteUrl,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.none,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.catching_pokemon, size: 14, color: Colors.white54),
                            ),
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

        const SizedBox(width: 12),

        // Manage Items Card
        Expanded(
          child: InkWell(
            onTap: () => _openItemsManagerModal(trainer),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.backpack, color: Colors.amberAccent, size: 20),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Manage Items",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${trainer.totalItems} Items in Bag",
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 26),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$ballTotal Balls",
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$medTotal Meds",
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPokedexCard(Trainer trainer) {
    final int totalSpecies = PokedexDatabase.species.length;
    final int caught = trainer.caughtCount;
    final int seen = trainer.seenCount;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PokedexScreen()),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red.shade900.withOpacity(0.32),
              const Color(0xFF2A2A35),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
              ),
              child: const Center(
                child: PokeBallSymbol(size: 24, isCaught: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pokédex",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "$caught Caught • $seen Encountered / $totalSpecies Kanto",
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PokeBallSymbol(size: 13, isCaught: true),
                  const SizedBox(width: 4),
                  Text(
                    "$caught",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white60, size: 20),
          ],
        ),
      ),
    );
  }

  // ─── 5. PRIMARY FIST-BUMP CHALLENGE CTA ───────────────────────────────────
  Widget _buildChallengeTrainerButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BumpScreen()),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade700, Colors.deepOrange.shade600],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade900.withOpacity(0.45),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Icon(Icons.sports_mma, color: Colors.white, size: 26),
                  SizedBox(width: 14),
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
                            fontSize: 14,
                            letterSpacing: 0.7,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "FIST-BUMP BATTLE • DUEL A RIVAL",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
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
                        Column(
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
                              "Slot #1 Pokémon is summoned first in every battle (${trainer.party.length}/6)",
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
                                    if (trainer.party.length > 1)
                                      IconButton(
                                        tooltip: "Release Pokémon",
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.redAccent, size: 18),
                                        onPressed: () => _confirmReleasePokemon(ctx, trainer, idx, mon),
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
            final itemDefs = [
              _ItemMeta(
                id: 'poke_ball',
                name: 'Poké Ball',
                description: 'Standard capsule for catching wild Pokémon.',
                count: trainer.pokeBalls,
                color: Colors.redAccent,
                icon: Icons.catching_pokemon,
                rarity: 'Common',
              ),
              _ItemMeta(
                id: 'great_ball',
                name: 'Great Ball',
                description: 'High-performance capsule with 1.5x catch rate.',
                count: trainer.greatBalls,
                color: Colors.blueAccent,
                icon: Icons.catching_pokemon,
                rarity: 'Uncommon',
              ),
              _ItemMeta(
                id: 'ultra_ball',
                name: 'Ultra Ball',
                description: 'Ultra-grade capsule with 2.0x catch rate.',
                count: trainer.ultraBalls,
                color: Colors.amberAccent,
                icon: Icons.catching_pokemon,
                rarity: 'Rare',
              ),
              _ItemMeta(
                id: 'potion',
                name: 'Potion',
                description: 'Restores 20 HP for a party Pokémon.',
                count: trainer.potions,
                color: Colors.greenAccent,
                icon: Icons.medical_services,
                isHealing: true,
                rarity: 'Common',
              ),
              _ItemMeta(
                id: 'super_potion',
                name: 'Super Potion',
                description: 'Restores 50 HP for a party Pokémon.',
                count: trainer.superPotions,
                color: Colors.tealAccent,
                icon: Icons.medical_services,
                isHealing: true,
                rarity: 'Uncommon',
              ),
              _ItemMeta(
                id: 'hyper_potion',
                name: 'Hyper Potion',
                description: 'Restores 200 HP for a party Pokémon.',
                count: trainer.hyperPotions,
                color: Colors.pinkAccent,
                icon: Icons.medical_services,
                isHealing: true,
                rarity: 'Rare',
              ),
              _ItemMeta(
                id: 'revive',
                name: 'Revive',
                description: 'Revives fainted Pokémon back to battle condition.',
                count: trainer.revives,
                color: Colors.orangeAccent,
                icon: Icons.favorite,
                isHealing: true,
                rarity: 'Rare',
              ),
            ];

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
                      child: ListView.separated(
                        itemCount: itemDefs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (c, idx) {
                          final item = itemDefs[idx];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E2E3B),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: item.color.withOpacity(0.35)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: item.color.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: item.id.endsWith('_ball')
                                        ? PokeBallSpriteWidget(ballType: item.id, size: 30)
                                        : Icon(item.icon, color: item.color, size: 24),
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: item.color.withOpacity(0.18),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: item.color.withOpacity(0.6),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              item.rarity.toUpperCase(),
                                              style: TextStyle(
                                                color: item.color,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black38,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "x${item.count}",
                                              style: TextStyle(
                                                color: item.count > 0 ? item.color : Colors.white38,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.description,
                                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                                      ),
                                      if (item.isHealing) ...[
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          height: 28,
                                          child: OutlinedButton(
                                            onPressed: item.count > 0
                                                ? () {
                                                    trainer.adjustItemCount(item.id, -1);
                                                    trainer.healAndResetAllParty();
                                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            "Used ${item.name}! Entire party restored to full HP & PP."),
                                                        duration: const Duration(seconds: 2),
                                                      ),
                                                    );
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
                                      onPressed: item.count > 0
                                          ? () => trainer.adjustItemCount(item.id, -1)
                                          : null,
                                      icon: Icon(
                                        Icons.remove_circle_outline,
                                        color: item.count > 0 ? Colors.redAccent : Colors.white24,
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

class _ItemMeta {
  final String id;
  final String name;
  final String description;
  final int count;
  final Color color;
  final IconData icon;
  final bool isHealing;
  final String rarity;

  const _ItemMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.count,
    required this.color,
    required this.icon,
    this.isHealing = false,
    this.rarity = 'Common',
  });
}
