import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/trainer.dart';
import '../models/trainer_avatar.dart';
import '../services/pokedex_database.dart';
import '../widgets/trainer_sprite.dart';
import '../widgets/type_badge.dart';
import 'home_screen.dart';

class StarterSelectScreen extends StatefulWidget {
  const StarterSelectScreen({super.key});

  @override
  State<StarterSelectScreen> createState() => _StarterSelectScreenState();
}

class _StarterSelectScreenState extends State<StarterSelectScreen> {
  int _step = 0; // 0 = Trainer Avatar, 1 = Starter Pokémon
  bool _isFemale = false;
  TrainerAvatar _selectedAvatar = TrainerAvatar.presets.first;
  final TextEditingController _nameController = TextEditingController(text: 'Red');

  int _selectedStarterId = 4; // Default to Charmander
  final List<int> _starters = [1, 4, 7]; // Bulbasaur, Charmander, Squirtle

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _selectGender(bool female) {
    final options = TrainerAvatar.byGender(isFemale: female);
    setState(() {
      _isFemale = female;
      _selectedAvatar = options.first;
      if (_nameController.text == 'Red' || _nameController.text == 'Leaf') {
        _nameController.text = female ? 'Leaf' : 'Red';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E24),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _step == 0 ? _buildTrainerStep() : _buildStarterStep(),
        ),
      ),
    );
  }

  Widget _buildTrainerStep() {
    final genderOptions = TrainerAvatar.byGender(isFemale: _isFemale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.red.shade700,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            "WELCOME TO KANTO",
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
          "Choose Your Trainer Avatar",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 14),

        // Gender Toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _genderTab("MALE", Icons.male, !_isFemale, () => _selectGender(false)),
              _genderTab("FEMALE", Icons.female, _isFemale, () => _selectGender(true)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3 Trainer Versions for selected gender
        Row(
          children: genderOptions.map((avatar) {
            final isSelected = _selectedAvatar.id == avatar.id;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedAvatar = avatar),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.red.shade900.withOpacity(0.35)
                        : const Color(0xFF2A2A35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected ? Colors.redAccent : Colors.white12,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      TrainerSpriteWidget(
                        avatar: avatar,
                        isBackView: false,
                        size: 108,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        avatar.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        // Selected Preview + Trainer Name Input
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A35),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TrainerSpriteWidget(
                      avatar: _selectedAvatar,
                      isBackView: false,
                      size: 102,
                    ),
                    const SizedBox(width: 14),
                    TrainerSpriteWidget(
                      avatar: _selectedAvatar,
                      isBackView: true,
                      pose: 1,
                      size: 102,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "${_selectedAvatar.title} (${_selectedAvatar.isFemale ? 'Female' : 'Male'})",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amberAccent,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  maxLength: 14,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Trainer Name",
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
                    counterText: "",
                    filled: true,
                    fillColor: const Color(0xFF1E1E24),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: const Text(
              "NEXT: CHOOSE PARTNER →",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _genderTab(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.red.shade700 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarterStep() {
    final selectedMon = PokedexDatabase.createStarter(_selectedStarterId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white70),
              onPressed: () => setState(() => _step = 0),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          "Choose Your First Partner Pokémon!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 16),

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
                  color: isSelected
                      ? Colors.red.shade900.withOpacity(0.4)
                      : const Color(0xFF2A2A35),
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
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (ctx, err, stack) => Image.network(
                    mon.staticSpriteUrl,
                    width: 60,
                    height: 60,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (c2, e2, s2) =>
                        const Icon(Icons.catching_pokemon, color: Colors.white, size: 50),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        // Detailed Card for Selected Starter (showing true Lv.5 calculated stats & Lv.5 moves)
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A35),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Image.network(
                  selectedMon.species.spriteUrl,
                  height: 110,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (ctx, err, stack) => Image.network(
                    selectedMon.species.staticSpriteUrl,
                    height: 110,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (c2, e2, s2) =>
                        const Icon(Icons.catching_pokemon, color: Colors.white, size: 95),
                  ),
                ),
                Text(
                  "${selectedMon.species.name}  •  Lv.${selectedMon.level}",
                  style: const TextStyle(
                    fontSize: 20,
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
                const SizedBox(height: 12),
                const Divider(color: Colors.white12),
                const SizedBox(height: 6),

                // Level 5 Calculated Stats
                _buildStatRow("HP", selectedMon.maxHp),
                _buildStatRow("Attack", selectedMon.atk),
                _buildStatRow("Defense", selectedMon.def),
                _buildStatRow("Sp. Atk", selectedMon.spa),
                _buildStatRow("Speed", selectedMon.spe),

                const Spacer(),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Lv.5 Moves (${selectedMon.moves.length}): ${selectedMon.moves.map((m) => m.name).join(', ')}",
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              final trainer = Provider.of<Trainer>(context, listen: false);
              trainer.setIdentity(
                newName: _nameController.text,
                newAvatar: _selectedAvatar,
              );
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
    );
  }

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 65,
            child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ),
          SizedBox(
            width: 28,
            child: Text(
              "$value",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (value / 25).clamp(0.0, 1.0),
                backgroundColor: Colors.black26,
                valueColor: AlwaysStoppedAnimation<Color>(
                  value >= 14
                      ? Colors.greenAccent
                      : (value >= 11 ? Colors.amberAccent : Colors.redAccent),
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
