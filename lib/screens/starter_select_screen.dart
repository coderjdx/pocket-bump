import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_version.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../models/trainer_avatar.dart';
import '../services/pokedex_database.dart';
import '../services/sound_service.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokemon_sprite_image.dart';
import '../widgets/sound_controls.dart';
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
  final TextEditingController _nameController =
      TextEditingController(text: 'Red');

  int _selectedStarterId = 4; // Default to Charmander
  final List<int> _starters = [1, 4, 7]; // Bulbasaur, Charmander, Squirtle

  @override
  void initState() {
    super.initState();
    SoundService.instance.playBgm(BgmTrack.titleLab);
  }

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

  Widget _buildHeaderPill(String text, Color primary, Color secondary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primary, secondary]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          fontSize: 10.5,
        ),
      ),
    );
  }

  Widget _buildBackButton(VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: PokeColors.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PokeColors.frameBorderSoft, width: 1.4),
      ),
      child: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: PokeColors.inkDark,
          size: 16,
        ),
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(),
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/bg_starter_select.png',
            alignment: Alignment.bottomCenter,
            topOpacity: 0.22,
            midOpacity: 0.44,
            bottomOpacity: 0.86,
          ),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
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
        _buildHeaderPill(
          "WELCOME TO POCKET BUMP",
          _selectedVersion.primaryColor,
          _selectedVersion.secondaryColor,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: PokeDecorations.card(
            fill: PokeColors.creamSurface.withOpacity(0.94),
            border: _selectedVersion.primaryColor.withOpacity(0.45),
            radius: 16,
            borderWidth: 1.5,
          ),
          child: const Column(
            children: [
              Text(
                "Choose Your Game Version",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w900,
                  color: PokeColors.inkDark,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Wild encounters follow your chosen version. Trade with friends on the other version via Fist Bump to catch them all!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
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
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              SoundService.instance.playUiTap();
              setState(() => _step = 1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _selectedVersion.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildBackButton(() => setState(() => _step = 0)),
            _buildHeaderPill(
              "KANTO • ${_selectedVersion.shortLabel}",
              _selectedVersion.primaryColor,
              _selectedVersion.secondaryColor,
            ),
            const SoundToggleButton(
              size: 16,
              iconColor: PokeColors.inkDark,
              bgColor: PokeColors.cardWhite,
              borderColor: PokeColors.frameBorderSoft,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: PokeDecorations.card(
            fill: PokeColors.creamSurface.withOpacity(0.92),
            border: PokeColors.frameBorderSoft,
            radius: 12,
            borderWidth: 1.2,
          ),
          child: const Text(
            "Choose Your Trainer Identity",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w900,
              color: PokeColors.inkDark,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Gender Toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: PokeDecorations.card(
            fill: PokeColors.cardWhite,
            border: PokeColors.frameBorderSoft,
            radius: 14,
            borderWidth: 1.4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _genderTab(
                "MALE",
                Icons.male,
                !_isFemale,
                PokeColors.pokeBlue,
                () => _selectGender(false),
              ),
              const SizedBox(width: 4),
              _genderTab(
                "FEMALE",
                Icons.female,
                _isFemale,
                PokeColors.centerRose,
                () => _selectGender(true),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 3 Trainer Versions for selected gender
        Row(
          children: genderOptions.map((avatar) {
            final isSelected = _selectedAvatar.id == avatar.id;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  SoundService.instance.playUiTap();
                  setState(() => _selectedAvatar = avatar);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFEFEF)
                        : PokeColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? PokeColors.pokeRed
                          : PokeColors.frameBorderSoft,
                      width: isSelected ? 2.2 : 1.3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? PokeColors.pokeRed.withOpacity(0.20)
                            : Colors.black.withOpacity(0.06),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TrainerSpriteWidget(
                        avatar: avatar,
                        isBackView: false,
                        size: 74,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        avatar.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? PokeColors.pokeRedDark
                              : PokeColors.inkDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 10),

        // Selected Preview + Trainer Name Input
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: PokeDecorations.card(
              fill: PokeColors.creamSurface.withOpacity(0.96),
              border: PokeColors.frameBorderSoft,
              radius: 18,
              borderWidth: 1.6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFD8EEFC), Color(0xFFBFE4B6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: PokeColors.frameBorderSoft, width: 1.3),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TrainerSpriteWidget(
                        avatar: _selectedAvatar,
                        isBackView: false,
                        size: 72,
                      ),
                      const SizedBox(width: 14),
                      TrainerSpriteWidget(
                        avatar: _selectedAvatar,
                        isBackView: true,
                        pose: 1,
                        size: 72,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${_selectedAvatar.title} (${_selectedAvatar.isFemale ? 'Female' : 'Male'})",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: PokeColors.pokeRedDark,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  maxLength: 14,
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: "TRAINER NAME",
                    labelStyle: const TextStyle(
                      color: PokeColors.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                    counterText: "",
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: PokeColors.cardWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: PokeColors.frameBorderSoft),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: PokeColors.frameBorderSoft, width: 1.4),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: PokeColors.pokeRed, width: 1.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              SoundService.instance.playUiTap();
              setState(() => _step = 2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokeColors.pokeRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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

  Widget _genderTab(String label, IconData icon, bool active, Color activeColor,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16, color: active ? Colors.white : PokeColors.inkMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : PokeColors.inkMuted,
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
            _buildBackButton(() => setState(() => _step = 1)),
            _buildHeaderPill(
              "PROFESSOR OAK'S LAB",
              PokeColors.pokeGreen,
              PokeColors.pokeGreenDark,
            ),
            const SoundToggleButton(
              size: 16,
              iconColor: PokeColors.inkDark,
              bgColor: PokeColors.cardWhite,
              borderColor: PokeColors.frameBorderSoft,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: PokeDecorations.card(
            fill: PokeColors.creamSurface.withOpacity(0.92),
            border: PokeColors.frameBorderSoft,
            radius: 11,
            borderWidth: 1.2,
          ),
          child: const Text(
            "Choose Your First Partner Pokémon!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: PokeColors.inkDark,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 3 Portrait Starter Cards in a Row
        Row(
          children: _starters.map((id) {
            final mon = PokedexDatabase.species[id]!;
            final c = mon.types.first.color;
            final isSelected = _selectedStarterId == id;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  SoundService.instance.playPokemonCry(id);
                  setState(() => _selectedStarterId = id);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 102,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Color.lerp(PokeColors.cardWhite, c, 0.16)
                        : PokeColors.cardWhite,
                    border: Border.all(
                      color: isSelected ? c : PokeColors.frameBorderSoft,
                      width: isSelected ? 2.4 : 1.4,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? c.withOpacity(0.28)
                            : Colors.black.withOpacity(0.06),
                        blurRadius: isSelected ? 8 : 4,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: PokemonSpriteImage.fromSpecies(
                          mon,
                          fallbackIconSize: 40,
                          fallbackIconColor: c,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        mon.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? PokeColors.darken(c, 0.25)
                              : PokeColors.inkMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 10),

        // Detailed Card for Selected Starter
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: PokeDecorations.card(
              fill: PokeColors.creamSurface.withOpacity(0.96),
              border: typeColor,
              radius: 18,
              borderWidth: 1.8,
            ),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [typeColor.withOpacity(0.26), Colors.transparent],
                    ),
                  ),
                  child: PokemonSpriteImage.fromSpecies(
                    selectedMon.species,
                    height: 76,
                    fallbackIconSize: 66,
                    fallbackIconColor: typeColor,
                  ),
                ),
                Text(
                  "${selectedMon.species.name}  •  Lv.${selectedMon.level}",
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: PokeColors.inkDark,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: selectedMon.species.types
                      .map((t) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: TypeBadge(type: t),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                const Divider(color: PokeColors.frameBorderSoft, height: 1),
                const SizedBox(height: 7),

                // Level 5 Calculated Stats
                _buildStatRow("HP", selectedMon.maxHp),
                _buildStatRow("Attack", selectedMon.atk),
                _buildStatRow("Defense", selectedMon.def),
                _buildStatRow("Sp. Atk", selectedMon.spa),
                _buildStatRow("Speed", selectedMon.spe),

                const Spacer(),

                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 5),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: PokeDecorations.inset(
                    fill: PokeColors.cardWhite,
                    border: selectedMon.isHiddenAbility
                        ? PokeColors.badgeGold
                        : PokeColors.pokeBlue.withOpacity(0.45),
                    radius: 9,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: selectedMon.isHiddenAbility
                            ? PokeColors.badgeGoldDark
                            : PokeColors.pokeBlueDark,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          "Ability: ${selectedMon.abilityDefinition?.name ?? selectedMon.abilityId}${selectedMon.isHiddenAbility ? ' (Hidden)' : ''}",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: selectedMon.isHiddenAbility
                                ? PokeColors.badgeGoldDark
                                : PokeColors.pokeBlueDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: PokeDecorations.inset(
                    fill: PokeColors.cardWhite,
                    border: PokeColors.frameBorderSoft,
                    radius: 9,
                  ),
                  child: Text(
                    "Lv.5 Moves: ${selectedMon.moves.map((m) => m.name).join(', ')}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: PokeColors.inkMuted,
                      fontWeight: FontWeight.w700,
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
          decoration: PokeDecorations.card(
            fill: PokeColors.cardWhite,
            border: PokeColors.badgeGold,
            radius: 10,
            borderWidth: 1.4,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                size: 15,
                color: PokeColors.badgeGoldDark,
              ),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  "WELCOME GIFT: 20 Poké Balls • 10 Potions • 5 Revives",
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: PokeColors.badgeGoldDark,
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
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              SoundService.instance.playUiConfirm();
              SoundService.instance.playPokemonCry(selectedMon.species.id);
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
              backgroundColor: PokeColors.pokeRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: Text(
              "I CHOOSE ${selectedMon.species.name.toUpperCase()}!",
              style: const TextStyle(
                fontSize: 13.5,
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 65,
            child: Text(
              label,
              style: const TextStyle(
                color: PokeColors.inkMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              "$value",
              style: const TextStyle(
                color: PokeColors.inkDark,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value / 25).clamp(0.0, 1.0),
                backgroundColor: PokeColors.panelSoft,
                valueColor: AlwaysStoppedAnimation<Color>(
                  value >= 14
                      ? PokeColors.pokeGreen
                      : (value >= 11
                          ? PokeColors.badgeGold
                          : PokeColors.pokeRed),
                ),
                minHeight: 7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
