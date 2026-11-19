import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_version.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../models/trainer_avatar.dart';
import '../services/pokedex_database.dart';
import '../widgets/trainer_sprite.dart';
import '../widgets/type_badge.dart';
import '../widgets/version_picker.dart';

class StarterSelectScreen extends StatefulWidget {
  const StarterSelectScreen({super.key});

  @override
  State<StarterSelectScreen> createState() => _StarterSelectScreenState();
}

class _StarterSelectScreenState extends State<StarterSelectScreen> {
  int _step = 0; // 0 = Version, 1 = Trainer Avatar, 2 = Starter Pokémon
  GameVersion _selectedVersion = GameVersion.red;
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
      backgroundColor: const Color(0xFF0C101B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_starter_select.png',
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
                  const Color(0xFF0C1120).withOpacity(0.74),
                  const Color(0xFF0F1322).withOpacity(0.58),
                  const Color(0xFF090B14).withOpacity(0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
              child: _step == 0
                  ? _buildVersionStep()
                  : (_step == 1 ? _buildTrainerStep() : _buildStarterStep()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _selectedVersion.primaryColor,
                _selectedVersion.secondaryColor,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.55)),
          ),
          child: const Text(
            "WELCOME TO POCKET BUMP",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
              fontSize: 10.5,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Choose Your Game Version",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Wild encounters follow your chosen version. Trade with friends on the other version via Fist Bump to catch them all!",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                VersionChoiceCard(
                  version: GameVersion.red,
                  isSelected: _selectedVersion == GameVersion.red,
                  onTap: () =>
                      setState(() => _selectedVersion = GameVersion.red),
                ),
                const SizedBox(height: 12),
                VersionChoiceCard(
                  version: GameVersion.blueGreen,
                  isSelected: _selectedVersion == GameVersion.blueGreen,
                  onTap: () =>
                      setState(() => _selectedVersion = GameVersion.blueGreen),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => setState(() => _step = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedVersion.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              elevation: 4,
            ),
            child: const Text(
              "NEXT: TRAINER IDENTITY →",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainerStep() {
    final genderOptions = TrainerAvatar.byGender(isFemale: _isFemale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _step = 0),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _selectedVersion.primaryColor,
                    _selectedVersion.secondaryColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.55)),
              ),
              child: Text(
                "KANTO • ${_selectedVersion.shortLabel}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                  fontSize: 10.5,
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          "Choose Your Trainer Identity",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),

        // Gender Toggle
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xE8121626),
            borderRadius: BorderRadius.circular(13),
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

        const SizedBox(height: 12),

        // 3 Trainer Versions for selected gender
        Row(
          children: genderOptions.map((avatar) {
            final isSelected = _selectedAvatar.id == avatar.id;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedAvatar = avatar),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [
                              Colors.red.shade900.withOpacity(0.55),
                              const Color(0xEA16192B),
                            ]
                          : [
                              const Color(0xE0161A2A),
                              const Color(0xE0101320),
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.redAccent : Colors.white12,
                      width: isSelected ? 2.0 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.28),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      TrainerSpriteWidget(
                        avatar: avatar,
                        isBackView: false,
                        size: 78,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        avatar.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
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

        const SizedBox(height: 12),

        // Selected Preview + Trainer Name Input
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xE8171C2E), Color(0xEE101320)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white12, width: 1.2),
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
                      size: 76,
                    ),
                    const SizedBox(width: 14),
                    TrainerSpriteWidget(
                      avatar: _selectedAvatar,
                      isBackView: true,
                      pose: 1,
                      size: 76,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "${_selectedAvatar.title} (${_selectedAvatar.isFemale ? 'Female' : 'Male'})",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD54F),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  maxLength: 14,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: "TRAINER NAME",
                    labelStyle: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.7,
                    ),
                    counterText: "",
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    filled: true,
                    fillColor: const Color(0xFF0A0D16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => setState(() => _step = 2),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              elevation: 4,
            ),
            child: const Text(
              "NEXT: CHOOSE PARTNER →",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
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
          gradient: active
              ? LinearGradient(colors: [Colors.red.shade600, Colors.red.shade800])
              : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
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
    final Color typeColor = selectedMon.species.types.first.color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _step = 1),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade900],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.55)),
              ),
              child: const Text(
                "PROFESSOR OAK'S LAB",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 10.5,
                ),
              ),
            ),
            const SizedBox(width: 24),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          "Choose Your First Partner Pokémon!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),

        // Starter Poké Ball Switcher Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _starters.map((id) {
            final mon = PokedexDatabase.species[id]!;
            final c = mon.types.first.color;
            final isSelected = _selectedStarterId == id;
            return GestureDetector(
              onTap: () => setState(() => _selectedStarterId = id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [c.withOpacity(0.32), const Color(0xFF14182B)]
                        : [const Color(0xE0161A2B), const Color(0xE0101320)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(
                    color: isSelected ? c : Colors.white12,
                    width: isSelected ? 2.0 : 1,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: isSelected
                      ? [BoxShadow(color: c.withOpacity(0.35), blurRadius: 10)]
                      : null,
                ),
                child: Image.network(
                  mon.spriteUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (ctx, err, stack) => Image.network(
                    mon.staticSpriteUrl,
                    width: 50,
                    height: 50,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (c2, e2, s2) =>
                        const Icon(Icons.catching_pokemon, color: Colors.white, size: 40),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 12),

        // Detailed Card for Selected Starter
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  typeColor.withOpacity(0.18),
                  const Color(0xEA141828),
                  const Color(0xEE0F121E),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: typeColor.withOpacity(0.6), width: 1.3),
            ),
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [typeColor.withOpacity(0.28), Colors.transparent],
                    ),
                  ),
                  child: Image.network(
                    selectedMon.species.spriteUrl,
                    height: 80,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (ctx, err, stack) => Image.network(
                      selectedMon.species.staticSpriteUrl,
                      height: 80,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (c2, e2, s2) =>
                          const Icon(Icons.catching_pokemon, color: Colors.white, size: 70),
                    ),
                  ),
                ),
                Text(
                  "${selectedMon.species.name}  •  Lv.${selectedMon.level}",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: selectedMon.species.types
                      .map((t) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: TypeBadge(type: t),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 9),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 8),

                // Level 5 Calculated Stats
                _buildStatRow("HP", selectedMon.maxHp),
                _buildStatRow("Attack", selectedMon.atk),
                _buildStatRow("Defense", selectedMon.def),
                _buildStatRow("Sp. Atk", selectedMon.spa),
                _buildStatRow("Speed", selectedMon.spe),

                const Spacer(),

                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0D16),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: selectedMon.isHiddenAbility
                          ? const Color(0xFFFFD54F).withOpacity(0.6)
                          : Colors.cyanAccent.withOpacity(0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 13,
                        color: selectedMon.isHiddenAbility
                            ? const Color(0xFFFFD54F)
                            : Colors.cyanAccent,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "Ability: ${selectedMon.abilityDefinition?.name ?? selectedMon.abilityId}${selectedMon.isHiddenAbility ? ' (Hidden)' : ''}",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: selectedMon.isHiddenAbility
                                ? const Color(0xFFFFE082)
                                : Colors.cyanAccent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0D16),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    "Lv.5 Moves: ${selectedMon.moves.map((m) => m.name).join(', ')}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFD54F).withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFFFD54F).withOpacity(0.35),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.card_giftcard_rounded,
                size: 14,
                color: Color(0xFFFFD54F),
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  "WELCOME GIFT: 20 Poké Balls • 10 Potions • 5 Revives",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFFFE082),
                    letterSpacing: 0.25,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              final trainer = Provider.of<Trainer>(context, listen: false);
              trainer.setGameVersion(_selectedVersion);
              trainer.setIdentity(
                newName: _nameController.text,
                newAvatar: _selectedAvatar,
              );
              trainer.grantWelcomeGift();
              trainer.addPokemon(selectedMon);
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              elevation: 4,
            ),
            child: Text(
              "I CHOOSE ${selectedMon.species.name.toUpperCase()}!",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.9,
              ),
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
