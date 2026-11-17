import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trainer.dart';
import '../models/trainer_avatar.dart';
import '../services/pokedex_database.dart';
import '../services/step_counter_service.dart';
import '../widgets/hp_bar.dart';
import '../widgets/trainer_sprite.dart';
import 'battle_screen.dart';
import 'bump_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _steps = 0;

  @override
  void initState() {
    super.initState();
    // Initialize the hardware step counter background listener!
    StepCounterService.initialize(
      onEncounter: () {
        if (!mounted) return;
        _launchWildEncounter();
      },
    );
  }

  void _launchWildEncounter() {
    final trainer = Provider.of<Trainer>(context, listen: false);
    final playerLevel = trainer.leadPokemon?.level ?? 5;
    final wildMon = PokedexDatabase.generateWildEncounter(playerLevel: playerLevel);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BattleScreen(opponentPokemon: wildMon, isWild: true),
      ),
    );
  }

  void _openAvatarPicker(Trainer trainer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "SELECT TRAINER AVATAR",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
                  final selected = av.id == trainer.avatar.id;
                  return GestureDetector(
                    onTap: () {
                      trainer.setIdentity(newName: trainer.name, newAvatar: av);
                      Navigator.pop(ctx);
                    },
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
                            size: 62,
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
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── TRAINER PROFILE HEADER ────────────────────────────────
              GestureDetector(
                onTap: () => _openAvatarPicker(trainer),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A35),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Center(
                          child: TrainerSpriteWidget(
                            avatar: trainer.avatar,
                            isBackView: false,
                            size: 52,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  trainer.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit, size: 13, color: Colors.white38),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${trainer.avatar.title} • ${trainer.party.length}/6 Pokémon",
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      // Item badges
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.catching_pokemon, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 4),
                              Text("${trainer.pokeBalls}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.medical_services, color: Colors.greenAccent, size: 16),
                              const SizedBox(width: 4),
                              Text("${trainer.potions}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ─── STEP COUNTER / POKÉWALKER CARD ────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade900.withOpacity(0.5), const Color(0xFF2A2A35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.directions_walk, color: Colors.indigoAccent, size: 20),
                            SizedBox(width: 6),
                            Text(
                              "POKÉWALKER ROUTE",
                              style: TextStyle(
                                color: Colors.indigoAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            setState(() => _steps += 400);
                            _launchWildEncounter();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.indigoAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "+400 Steps (Test)",
                              style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "$_steps Steps Walked",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Walking in the real world automatically triggers wild encounter vibrations!",
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ─── PARTY POKÉMON HEADER ──────────────────────────────────
              const Text(
                "CARRIED PARTY",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white60,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),

              // Party List
              Expanded(
                child: ListView.separated(
                  itemCount: trainer.party.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final mon = trainer.party[idx];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Image.network(
                            mon.species.spriteUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (c, e, s) => Image.network(
                              mon.species.staticSpriteUrl,
                              width: 52,
                              height: 52,
                              filterQuality: FilterQuality.none,
                              errorBuilder: (c2, e2, s2) =>
                                  const Icon(Icons.catching_pokemon, color: Colors.white, size: 40),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      mon.nickname,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      "Lv.${mon.level}",
                                      style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                HpBar(currentHp: mon.currentHp, maxHp: mon.maxHp),
                                const SizedBox(height: 4),
                                Text(
                                  "ATK ${mon.atk} • DEF ${mon.def} • SPD ${mon.spe}  |  ${mon.moves.map((m) => m.name).join(', ')}",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, color: Colors.white54),
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

              const SizedBox(height: 12),

              // ─── BOTTOM DUAL ACTION BUTTONS ────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const BumpScreen()),
                          );
                        },
                        icon: const Icon(Icons.sports_mma, size: 22),
                        label: const Text(
                          "FIST-BUMP BATTLE",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _launchWildEncounter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2A2A35),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: Colors.white12),
                      ),
                      child: const Icon(Icons.explore, color: Colors.greenAccent),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
