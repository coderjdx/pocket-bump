import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_instance.dart';
import '../services/pokedex_database.dart';
import '../models/trainer.dart';
import '../widgets/type_badge.dart';
import 'home_screen.dart';

class StarterSelectScreen extends StatefulWidget {
  const StarterSelectScreen({super.key});

  @override
  State<StarterSelectScreen> createState() => _StarterSelectScreenState();
}

class _StarterSelectScreenState extends State<StarterSelectScreen> {
  int _selectedStarterId = 4; // Default to Charmander

  final List<int> _starters = [1, 4, 7]; // Bulbasaur, Charmander, Squirtle

  @override
  Widget build(BuildContext context) {
    final selectedMon = PokedexDatabase.createStarter(_selectedStarterId);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "PROFESSOR OAK'S LAB",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Choose Your First Partner Pokémon!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Starter Switcher Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _starters.map((id) {
                  final mon = PokedexDatabase.species[id]!;
                  final isSelected = _selectedStarterId == id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStarterId = id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.red.shade900.withOpacity(0.4) : const Color(0xFF2A2A35),
                        border: Border.all(
                          color: isSelected ? Colors.redAccent : Colors.white12,
                          width: isSelected ? 2.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Image.network(
                        mon.spriteUrl,
                        width: 60,
                        height: 60,
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.catching_pokemon, color: Colors.white, size: 50),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Detailed Card for Selected Starter
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A35),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Image.network(
                        selectedMon.species.spriteUrl,
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.catching_pokemon, color: Colors.white, size: 100),
                      ),
                      Text(
                        selectedMon.species.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: selectedMon.species.types
                            .map((t) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: TypeBadge(type: t),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 8),

                      // Base Stats Preview
                      _buildStatRow("HP", selectedMon.species.baseHp),
                      _buildStatRow("Attack", selectedMon.species.baseAtk),
                      _buildStatRow("Defense", selectedMon.species.baseDef),
                      _buildStatRow("Speed", selectedMon.species.baseSpe),

                      const Spacer(),

                      // Starting Moves
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Starting Moves: ${selectedMon.moves.map((m) => m.name).join(', ')}",
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    final trainer = Provider.of<Trainer>(context, listen: false);
                    trainer.addPokemon(selectedMon);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomeScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: Text(
                    "I CHOOSE ${selectedMon.species.name.toUpperCase()}!",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
          Text(
            "$value",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (value / 120).clamp(0.0, 1.0),
                backgroundColor: Colors.black26,
                valueColor: AlwaysStoppedAnimation<Color>(
                  value > 60 ? Colors.greenAccent : (value > 45 ? Colors.amberAccent : Colors.redAccent),
                ),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
