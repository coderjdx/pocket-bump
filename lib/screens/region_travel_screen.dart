import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_region.dart';
import '../models/game_version.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
import '../services/sound_service.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokemon_sprite_image.dart';
import '../widgets/type_badge.dart';
import '../widgets/version_picker.dart';

class RegionTravelScreen extends StatefulWidget {
  const RegionTravelScreen({super.key});

  @override
  State<RegionTravelScreen> createState() => _RegionTravelScreenState();
}

class _RegionTravelScreenState extends State<RegionTravelScreen> {
  Future<void> _startJohtoJourney(Trainer trainer) async {
    GameVersion chosenVersion = GameVersion.gold;
    int chosenStarterId = 152;
    int step = 0;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) {
          final isVersionStep = step == 0;
          return AlertDialog(
            backgroundColor: PokeColors.creamSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isVersionStep
                    ? chosenVersion.primaryColor
                    : PokeColors.badgeGoldDark,
                width: 1.8,
              ),
            ),
            titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            contentPadding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
            actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            title: Row(
              children: [
                Icon(
                  isVersionStep
                      ? Icons.public_rounded
                      : Icons.catching_pokemon,
                  color: isVersionStep
                      ? chosenVersion.primaryColor
                      : PokeColors.badgeGoldDark,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isVersionStep
                        ? "Choose Johto Version"
                        : "Professor Elm's Starter Gift",
                    style: const TextStyle(
                      color: PokeColors.inkDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: isVersionStep
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Your Johto save progresses independently with new Badges, Bag items, and Pokémon. Pick your Johto edition:",
                          style: TextStyle(
                            color: PokeColors.inkMuted,
                            fontSize: 12,
                            height: 1.38,
                          ),
                        ),
                        const SizedBox(height: 12),
                        VersionChoiceCard(
                          version: GameVersion.gold,
                          isSelected: chosenVersion == GameVersion.gold,
                          compact: true,
                          onTap: () => setDlgState(
                              () => chosenVersion = GameVersion.gold),
                        ),
                        const SizedBox(height: 10),
                        VersionChoiceCard(
                          version: GameVersion.silver,
                          isSelected: chosenVersion == GameVersion.silver,
                          compact: true,
                          onTap: () => setDlgState(
                              () => chosenVersion = GameVersion.silver),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "Welcome to New Bark Town! Choose your Lv. 5 Johto partner Pokémon:",
                          style: TextStyle(
                            color: PokeColors.inkMuted,
                            fontSize: 12,
                            height: 1.38,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final sid in GameRegion.johto.starterIds) ...[
                          Builder(builder: (_) {
                            final spec = PokedexDatabase.species[sid]!;
                            final selected = chosenStarterId == sid;
                            final typeColor = spec.types.first.color;
                            return GestureDetector(
                              onTap: () {
                                SoundService.instance.playPokemonCry(sid);
                                setDlgState(() => chosenStarterId = sid);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: PokeDecorations.card(
                                  fill: selected
                                      ? PokeColors.cardWhite
                                      : PokeColors.panelSoft,
                                  border: selected
                                      ? typeColor
                                      : PokeColors.frameBorderSoft,
                                  radius: 14,
                                  borderWidth: selected ? 2.0 : 1.2,
                                ),
                                child: Row(
                                  children: [
                                    PokemonSpriteImage.fromSpecies(
                                      spec,
                                      width: 50,
                                      height: 50,
                                      fallbackIconSize: 30,
                                      fallbackIconColor: typeColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            spec.name,
                                            style: const TextStyle(
                                              color: PokeColors.inkDark,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: spec.types
                                                .map((t) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              right: 4),
                                                      child: TypeBadge(type: t),
                                                    ))
                                                .toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      selected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_unchecked_rounded,
                                      color: selected
                                          ? typeColor
                                          : PokeColors.inkSubtle,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
            ),
            actions: [
              Row(
                children: [
                  if (!isVersionStep)
                    TextButton(
                      onPressed: () => setDlgState(() => step = 0),
                      child: const Text("BACK"),
                    )
                  else
                    TextButton(
                      onPressed: () => Navigator.pop(dlgCtx, false),
                      child: const Text("CANCEL"),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (isVersionStep) {
                        setDlgState(() => step = 1);
                      } else {
                        Navigator.pop(dlgCtx, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isVersionStep
                          ? chosenVersion.primaryColor
                          : PokedexDatabase
                              .species[chosenStarterId]!.types.first.color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isVersionStep ? "NEXT" : "START IN JOHTO",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || !mounted) return;
    final starter = PokedexDatabase.createStarter(
      chosenStarterId,
      originRegion: GameRegion.johto.storageKey,
    );
    trainer.startNewRegionAdventure(
      region: GameRegion.johto,
      version: chosenVersion,
      starter: starter,
    );
    await trainer.saveProgress();
    if (!mounted) return;
    SoundService.instance.playPokemonCry(chosenStarterId);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final int natCaught = trainer.nationalCaughtCount;
    final int natTotal = PokedexDatabase.nationalTotalSpecies;

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: "REGION TRAVEL",
        barColor: PokeColors.pokeBlue,
        bottomBorderColor: PokeColors.pokeBlueDark,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/bg_home.png',
            topOpacity: 0.20,
            midOpacity: 0.45,
            bottomOpacity: 0.88,
          ),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: PokeDecorations.card(
                    fill: PokeColors.creamSurface,
                    border: PokeColors.pokeBlue,
                    radius: 16,
                    borderWidth: 1.6,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: PokeColors.pokeBlue.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.public_rounded,
                          color: PokeColors.pokeBlueDark,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "INDEPENDENT REGION PROGRESS",
                              style: TextStyle(
                                color: PokeColors.pokeBlueDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "National Pokédex: $natCaught / $natTotal Caught • Region teams, badges, and bags remain independent per region.",
                              style: const TextStyle(
                                color: PokeColors.inkMuted,
                                fontSize: 10.8,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final region in GameRegion.values) ...[
                  _buildRegionCard(trainer, region),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionCard(Trainer trainer, GameRegion region) {
    final bool unlocked = trainer.isRegionUnlocked(region);
    final bool isActive = trainer.activeRegion == region;
    final save = trainer.saveForRegion(region);
    final bool started = save.party.isNotEmpty;
    final int dexTotal = PokedexDatabase.speciesIdsForRegion(region).length;
    final int dexCaught = save.caughtSpeciesIds
        .union(save.party.map((m) => m.species.id).toSet())
        .union(save.pcBoxes.expand((b) => b.map((m) => m.species.id)).toSet())
        .where((id) => PokedexDatabase.isSpeciesInRegion(id, region))
        .length;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: PokeDecorations.card(
        fill: unlocked ? PokeColors.cardWhite : PokeColors.panelSoft,
        border: isActive
            ? region.accentColor
            : (unlocked
                ? region.accentColor.withOpacity(0.55)
                : PokeColors.frameBorderSoft),
        radius: 18,
        borderWidth: isActive ? 2.2 : 1.4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: region.accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  region.displayName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (save.gameVersion != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: save.gameVersion!.primaryColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: save.gameVersion!.primaryColor.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    save.gameVersion!.shortLabel,
                    style: TextStyle(
                      color: save.gameVersion!.primaryColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              const Spacer(),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: PokeColors.pokeGreen.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "CURRENT",
                    style: TextStyle(
                      color: PokeColors.pokeGreenDark,
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                    ),
                  ),
                )
              else if (!unlocked)
                const Row(
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 14, color: PokeColors.inkSubtle),
                    SizedBox(width: 4),
                    Text(
                      "LOCKED",
                      style: TextStyle(
                        color: PokeColors.inkSubtle,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!unlocked)
            const Text(
              "Defeat the Kanto League (Hall of Fame Champion) to unlock travel to Johto!",
              style: TextStyle(
                color: PokeColors.inkMuted,
                fontSize: 11.5,
                height: 1.35,
              ),
            )
          else if (!started)
            const Text(
              "Johto is unlocked! Pick Gold or Silver Version and claim your Lv. 5 Johto starter from Professor Elm.",
              style: TextStyle(
                color: PokeColors.inkMuted,
                fontSize: 11.5,
                height: 1.35,
              ),
            )
          else ...[
            Row(
              children: [
                Text(
                  "Badges: ${save.badges}/8",
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  "Dex: $dexCaught/$dexTotal",
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  "₽${save.money}",
                  style: const TextStyle(
                    color: PokeColors.badgeGoldDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: save.party.take(6).map((mon) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: PokeDecorations.inset(radius: 10),
                    child: Center(
                      child: PokemonSpriteImage.fromInstance(
                        mon,
                        width: 34,
                        height: 34,
                        fallbackIconSize: 20,
                        fallbackIconColor: region.accentColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (unlocked && !isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: started
                    ? () async {
                        SoundService.instance.playUiTap();
                        trainer.travelToRegion(region);
                        await trainer.saveProgress();
                        if (!mounted) return;
                        Navigator.pop(context, true);
                      }
                    : () => _startJohtoJourney(trainer),
                icon: Icon(
                  started ? Icons.flight_takeoff_rounded : Icons.explore_rounded,
                  size: 18,
                ),
                label: Text(
                  started
                      ? "TRAVEL TO ${region.displayName.toUpperCase()}"
                      : "BEGIN JOHTO JOURNEY",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: region.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
