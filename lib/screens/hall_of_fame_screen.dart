import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_region.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
import '../services/sound_service.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokemon_head_portrait.dart';
import '../widgets/trainer_bust_portrait.dart';

class HallOfFameScreen extends StatelessWidget {
  final bool isNewInduction;

  const HallOfFameScreen({
    super.key,
    this.isNewInduction = false,
  });

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'Today';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return 'Recorded';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final entries = trainer.hallOfFameEntries.reversed.toList();
    final latestEntry = entries.isNotEmpty ? entries.first : null;

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: "HALL OF FAME",
        barColor: PokeColors.leagueIndigo,
        bottomBorderColor: PokeColors.leagueIndigoDark,
        actions: [
          PokeCounterPill(
            icon: Icons.emoji_events_rounded,
            iconColor: PokeColors.badgeGoldDark,
            text: "CLEARS ${trainer.championClears}",
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/battle_bg_champion_hall.png',
            topOpacity: 0.25,
            midOpacity: 0.55,
            bottomOpacity: 0.90,
          ),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              children: [
                if (isNewInduction) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: PokeColors.badgeGoldDark,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: PokeColors.badgeGold.withOpacity(0.32),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          size: 40,
                          color: PokeColors.badgeGoldDark,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "CONGRATULATIONS, CHAMPION ${trainer.name.toUpperCase()}!",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: PokeColors.inkDark,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "You defeated the Final Four and ${trainer.activeRegion == GameRegion.johto ? 'Champion Lance' : 'Champion Blue'}! Your winning Pokémon are permanently enshrined in ${trainer.activeRegion.displayName}'s Hall of Fame.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
                ],

                // Current Champion Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: PokeDecorations.card(
                    fill: PokeColors.creamSurface,
                    border: PokeColors.badgeGold,
                    radius: 18,
                    borderWidth: 1.8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: PokeColors.badgeGoldDark,
                            width: 1.8,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: TrainerBustPortrait(
                            avatar: trainer.avatar,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "INDIGO CHAMPION • ${trainer.name.toUpperCase()}",
                              style: const TextStyle(
                                color: PokeColors.inkDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Champion Clears: ${trainer.championClears} • Caught: ${trainer.caughtCount}/${PokedexDatabase.speciesIdsForRegion(trainer.activeRegion).length}",
                              style: const TextStyle(
                                color: PokeColors.inkMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (latestEntry != null)
                              Text(
                                "Latest Induction: ${_formatDate(latestEntry['inductedAt'] as String?)}",
                                style: const TextStyle(
                                  color: PokeColors.badgeGoldDark,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (entries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: PokeDecorations.card(
                      fill: PokeColors.cardWhite,
                      border: PokeColors.frameBorderSoft,
                      radius: 16,
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 40,
                          color: PokeColors.inkSubtle,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "No Hall of Fame Records Yet",
                          style: TextStyle(
                            color: PokeColors.inkDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Conquer Victory Road, defeat the Final Four, and overcome the Champion to enshrine your team here.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: PokeColors.inkMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final entry in entries) ...[
                    _buildInductionRecordCard(trainer, entry),
                    const SizedBox(height: 12),
                  ],

                if (isNewInduction) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        SoundService.instance.playUiTap();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 19),
                      label: const Text(
                        "RETURN TO VICTORY ROAD",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: 0.7,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.leagueIndigo,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInductionRecordCard(
    Trainer trainer,
    Map<String, dynamic> entry,
  ) {
    final int runNum = (entry['runNumber'] as num?)?.toInt() ?? 1;
    final String dateLabel = _formatDate(entry['inductedAt'] as String?);
    final rawParty = entry['party'] as List<dynamic>? ?? const [];

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: PokeDecorations.card(
        fill: PokeColors.cardWhite,
        border: PokeColors.leagueIndigo.withOpacity(0.55),
        radius: 16,
        borderWidth: 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PokeColors.leagueIndigo,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  "INDUCTION #$runNum",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateLabel,
                style: const TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.5,
            ),
            itemCount: rawParty.length,
            itemBuilder: (_, idx) {
              final raw = rawParty[idx];
              if (raw is! Map) return const SizedBox.shrink();
              final int speciesId =
                  (raw['speciesId'] as num?)?.toInt() ?? 1;
              final spec = PokedexDatabase.species[speciesId] ??
                  PokedexDatabase.species[1]!;
              final String nickname =
                  (raw['nickname'] as String?)?.trim().isNotEmpty == true
                      ? (raw['nickname'] as String).trim()
                      : spec.name;
              final int level = (raw['level'] as num?)?.toInt() ?? 50;
              final bool isShiny = raw['isShiny'] == true;
              final String ot =
                  (raw['originalTrainerName'] as String?)?.trim().isNotEmpty ==
                          true
                      ? (raw['originalTrainerName'] as String).trim()
                      : trainer.name;
              final previewMon = PokemonInstance(
                species: spec,
                nickname: nickname,
                level: level,
                isShiny: isShiny,
                originalTrainerName: ot,
              );
              final typeColor = spec.types.first.color;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: PokeDecorations.inset(
                  fill: PokeColors.creamSurface,
                  border: typeColor.withOpacity(0.55),
                  radius: 11,
                ),
                child: Row(
                  children: [
                    PokemonHeadPortrait(
                      pokemon: previewMon,
                      size: 36,
                      borderRadius: 9,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PokeColors.inkDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            "Lv.$level • OT: $ot",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PokeColors.inkMuted,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
