import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ability.dart';
import '../models/game_version.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
import '../services/sound_service.dart';
import '../widgets/poke_theme.dart';
import '../widgets/type_badge.dart';

enum _PokedexFilter {
  all,
  caught,
  encountered,
  unseen,
}

class PokedexScreen extends StatefulWidget {
  const PokedexScreen({super.key});

  @override
  State<PokedexScreen> createState() => _PokedexScreenState();
}

class _PokedexScreenState extends State<PokedexScreen> {
  _PokedexFilter _filter = _PokedexFilter.all;

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final List<int> allIds = PokedexDatabase.gen1SpeciesIds;
    final int total = PokedexDatabase.gen1TotalSpecies;
    final int caughtTotal = trainer.caughtCount;
    final int seenTotal = trainer.seenCount;
    final int unseenTotal =
        allIds.where((id) => !trainer.isSpeciesSeen(id)).length;

    final List<int> filteredIds = allIds.where((id) {
      switch (_filter) {
        case _PokedexFilter.all:
          return true;
        case _PokedexFilter.caught:
          return trainer.isSpeciesCaught(id);
        case _PokedexFilter.encountered:
          return trainer.isSpeciesSeen(id);
        case _PokedexFilter.unseen:
          return !trainer.isSpeciesSeen(id);
      }
    }).toList();

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: "POKÉDEX",
        barColor: PokeColors.pokeRed,
        bottomBorderColor: PokeColors.pokeRedDark,
        titleLeading: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.cyanAccent,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.cyanAccent, blurRadius: 8),
            ],
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PokeBackdrop(
            assetPath: 'assets/images/bg_pokedex.png',
            topOpacity: 0.24,
            midOpacity: 0.48,
            bottomOpacity: 0.88,
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                children: [
                  // ─── DEXTER SCANNER SUMMARY BANNER ───────────────────────
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: PokeDecorations.card(
                      fill: PokeColors.creamSurface,
                      border: PokeColors.pokeRed,
                      radius: 18,
                      borderWidth: 1.8,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const PokeBallSymbol(size: 18, isCaught: true),
                                const SizedBox(width: 6),
                                Text(
                                  "$caughtTotal/$total Caught",
                                  style: const TextStyle(
                                    color: PokeColors.inkDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.visibility_rounded,
                                    color: PokeColors.badgeGoldDark, size: 16),
                                const SizedBox(width: 5),
                                Text(
                                  "$seenTotal Seen",
                                  style: const TextStyle(
                                    color: PokeColors.badgeGoldDark,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: PokeDecorations.inset(radius: 8),
                              child: Text(
                                "$total TOTAL",
                                style: const TextStyle(
                                  color: PokeColors.inkDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: PokeColors.panelSoft),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: total > 0
                                      ? (seenTotal / total).clamp(0.0, 1.0)
                                      : 0.0,
                                  child:
                                      Container(color: PokeColors.badgeGold),
                                ),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: total > 0
                                      ? (caughtTotal / total).clamp(0.0, 1.0)
                                      : 0.0,
                                  child: Container(color: PokeColors.pokeRed),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                PokeBallSymbol(size: 12, isCaught: true),
                                SizedBox(width: 4),
                                Text(
                                  "= Caught Pokémon",
                                  style: TextStyle(
                                      color: PokeColors.inkMuted, fontSize: 10),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                PokeBallSymbol(size: 12, isCaught: false),
                                SizedBox(width: 4),
                                Text(
                                  "= Encountered Only",
                                  style: TextStyle(
                                      color: PokeColors.inkMuted, fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ─── FILTER CHIPS ────────────────────────────────────────
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildFilterChip(
                          label: "All ($total)",
                          selected: _filter == _PokedexFilter.all,
                          onTap: () =>
                              setState(() => _filter = _PokedexFilter.all),
                        ),
                        const SizedBox(width: 7),
                        _buildFilterChip(
                          label: "Caught ($caughtTotal)",
                          selected: _filter == _PokedexFilter.caught,
                          onTap: () =>
                              setState(() => _filter = _PokedexFilter.caught),
                        ),
                        const SizedBox(width: 7),
                        _buildFilterChip(
                          label: "Encountered ($seenTotal)",
                          selected: _filter == _PokedexFilter.encountered,
                          onTap: () => setState(
                              () => _filter = _PokedexFilter.encountered),
                        ),
                        const SizedBox(width: 7),
                        _buildFilterChip(
                          label: "Unseen ($unseenTotal)",
                          selected: _filter == _PokedexFilter.unseen,
                          onTap: () =>
                              setState(() => _filter = _PokedexFilter.unseen),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ─── POKÉDEX GRID ────────────────────────────────────────
                  Expanded(
                    child: filteredIds.isEmpty
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: PokeDecorations.card(
                                fill: PokeColors.creamSurface,
                                border: PokeColors.frameBorderSoft,
                                radius: 16,
                              ),
                              child: const Text(
                                "No Pokémon in this filter yet.\nWalk or battle to discover more!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: PokeColors.inkMuted, fontSize: 13),
                              ),
                            ),
                          )
                        : GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.84,
                              crossAxisSpacing: 9,
                              mainAxisSpacing: 9,
                            ),
                            itemCount: filteredIds.length,
                            itemBuilder: (context, idx) {
                              final id = filteredIds[idx];
                              final spec = PokedexDatabase.species[id]!;
                              final bool isCaught = trainer.isSpeciesCaught(id);
                              final bool isSeen = trainer.isSpeciesSeen(id);
                              final bool isShinyCaught =
                                  trainer.isSpeciesShinyCaught(id);
                              return _buildDexCard(
                                spec,
                                isSeen: isSeen,
                                isCaught: isCaught,
                                isShinyCaught: isShinyCaught,
                              );
                            },
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

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? PokeColors.pokeRed : PokeColors.cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? PokeColors.pokeRedDark
                : PokeColors.frameBorderSoft,
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : PokeColors.inkDark,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildDexCard(
    PokemonSpecies spec, {
    required bool isSeen,
    required bool isCaught,
    bool isShinyCaught = false,
  }) {
    final Color primaryColor = spec.types.first.color;
    final String dexNum = "#${spec.id.toString().padLeft(3, '0')}";

    return InkWell(
      onTap: () {
        if (!isSeen) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Pokemon $dexNum hasn't been encountered yet!"),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        _openEntryDetail(spec,
            isCaught: isCaught, isShinyCaught: isShinyCaught);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: PokeDecorations.card(
          fill: isSeen ? PokeColors.cardWhite : PokeColors.creamSurface,
          border: isCaught
              ? primaryColor
              : (isSeen
                  ? PokeColors.badgeGold
                  : PokeColors.frameBorderSoft),
          radius: 16,
          borderWidth: isCaught ? 1.8 : 1.2,
        ),
        child: Column(
          children: [
            // Top Row: #ID and Caught / Encountered / Unseen indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dexNum,
                      style: TextStyle(
                        color: isSeen
                            ? PokeColors.inkMuted
                            : PokeColors.inkSubtle,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                      ),
                    ),
                    if (isShinyCaught) ...[
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: PokeColors.badgeGoldDark,
                        size: 11,
                      ),
                    ],
                  ],
                ),
                if (isCaught)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: PokeColors.pokeRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: PokeColors.pokeRed),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PokeBallSymbol(size: 12, isCaught: true),
                        SizedBox(width: 4),
                        Text(
                          "CAUGHT",
                          style: TextStyle(
                            color: PokeColors.pokeRedDark,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isSeen)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: PokeColors.badgeGold.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: PokeColors.badgeGoldDark),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PokeBallSymbol(size: 11, isCaught: false),
                        SizedBox(width: 4),
                        Text(
                          "SEEN",
                          style: TextStyle(
                            color: PokeColors.badgeGoldDark,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Text(
                    "UNSEEN",
                    style: TextStyle(
                      color: PokeColors.inkSubtle,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),

            const Spacer(),

            // Specimen Scanner Chamber
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isCaught
                      ? [primaryColor.withOpacity(0.22), Colors.transparent]
                      : [PokeColors.panelSoft, Colors.transparent],
                ),
              ),
              child: ColorFiltered(
                colorFilter: !isSeen
                    ? const ColorFilter.mode(
                        PokeColors.inkSubtle, BlendMode.srcIn)
                    : (isCaught
                        ? const ColorFilter.mode(
                            Colors.transparent, BlendMode.dst)
                        : ColorFilter.mode(
                            Colors.grey.shade600.withOpacity(0.35),
                            BlendMode.srcATop)),
                child: Opacity(
                  opacity: isSeen ? (isCaught ? 1.0 : 0.85) : 0.45,
                  child: Image.network(
                    spec.staticSpriteUrl,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.catching_pokemon,
                      size: 44,
                      color: isSeen ? primaryColor : PokeColors.inkSubtle,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Species Name
            Text(
              isSeen ? spec.name : "???",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSeen ? PokeColors.inkDark : PokeColors.inkSubtle,
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
              ),
            ),

            const SizedBox(height: 5),

            // Type Badges & Rarity Pill (if Seen or Caught)
            if (isSeen) ...[
              Wrap(
                spacing: 4,
                runSpacing: 2,
                alignment: WrapAlignment.center,
                children: spec.types.map((t) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t.displayName.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: spec.rarity.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: PokeColors.darken(spec.rarity.color, 0.14)),
                ),
                child: Text(
                  spec.rarity.displayName.toUpperCase(),
                  style: TextStyle(
                    color: PokeColors.darken(spec.rarity.color, 0.16),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: PokeDecorations.inset(radius: 6),
                child: const Text(
                  "???",
                  style: TextStyle(
                      color: PokeColors.inkSubtle,
                      fontSize: 8,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openEntryDetail(
    PokemonSpecies spec, {
    required bool isCaught,
    bool isShinyCaught = false,
  }) {
    final primaryColor = spec.types.first.color;
    final primaryDark = PokeColors.darken(primaryColor, 0.16);
    final dexNum = "#${spec.id.toString().padLeft(3, '0')}";
    bool showShiny = isShinyCaught;
    SoundService.instance.playPokemonCry(spec.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PokeColors.creamSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.78,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "$dexNum  ${spec.name}",
                          style: const TextStyle(
                            color: PokeColors.inkDark,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: "Play Cry",
                              icon: const Icon(Icons.volume_up_rounded,
                                  color: PokeColors.pokeBlue, size: 21),
                              onPressed: () =>
                                  SoundService.instance.playPokemonCry(spec.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: PokeColors.inkMuted),
                              onPressed: () {
                                SoundService.instance.playUiCancel();
                                Navigator.pop(ctx);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isCaught
                                ? PokeColors.pokeGreen.withOpacity(0.14)
                                : PokeColors.badgeGold.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isCaught
                                  ? PokeColors.pokeGreen
                                  : PokeColors.badgeGoldDark,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCaught)
                                const PokeBallSymbol(size: 16, isCaught: true)
                              else
                                const Icon(Icons.visibility,
                                    color: PokeColors.badgeGoldDark, size: 16),
                              const SizedBox(width: 7),
                              Text(
                                isCaught
                                    ? "CAUGHT & REGISTERED"
                                    : "ENCOUNTERED ONLY (NOT YET CAUGHT)",
                                style: TextStyle(
                                  color: isCaught
                                      ? PokeColors.pokeGreenDark
                                      : PokeColors.badgeGoldDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isShinyCaught)
                          InkWell(
                            onTap: () =>
                                setModalState(() => showShiny = !showShiny),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: showShiny
                                    ? PokeColors.badgeGold.withOpacity(0.22)
                                    : PokeColors.panelSoft,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: showShiny
                                      ? PokeColors.badgeGoldDark
                                      : PokeColors.frameBorderSoft,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 14,
                                    color: showShiny
                                        ? PokeColors.badgeGoldDark
                                        : PokeColors.inkMuted,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    showShiny ? "SHINY FORM" : "NORMAL FORM",
                                    style: TextStyle(
                                      color: showShiny
                                          ? PokeColors.badgeGoldDark
                                          : PokeColors.inkDark,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Hero Sprite + Types + Height
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 156,
                            height: 132,
                            decoration: PokeDecorations.card(
                              fill: PokeColors.cardWhite,
                              border: showShiny
                                  ? PokeColors.badgeGold
                                  : primaryDark,
                              radius: 22,
                              borderWidth: 2.0,
                            ),
                            child: Center(
                              child: Builder(builder: (_) {
                                final double showcaseSize =
                                    spec.scaledUiSize(112, minSize: 48);
                                return Image.network(
                                  showShiny
                                      ? spec.shinySpriteUrl
                                      : spec.spriteUrl,
                                  width: showcaseSize * 1.35,
                                  height: showcaseSize,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                  filterQuality: FilterQuality.none,
                                  errorBuilder: (_, __, ___) => Image.network(
                                    showShiny
                                        ? spec.staticShinySpriteUrl
                                        : spec.staticSpriteUrl,
                                    width: showcaseSize * 1.35,
                                    height: showcaseSize,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.bottomCenter,
                                    filterQuality: FilterQuality.none,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.catching_pokemon,
                                      size: (showcaseSize * 0.65)
                                          .clamp(28.0, 68.0),
                                      color: primaryColor,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ...spec.types.map((t) => TypeBadge(type: t)),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: PokeDecorations.inset(radius: 8),
                                child: Text(
                                  "${spec.heightMeters} m",
                                  style: const TextStyle(
                                    color: PokeColors.inkDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: PokeDecorations.inset(radius: 8),
                                child: Text(
                                  "${spec.weightKg} kg",
                                  style: const TextStyle(
                                    color: PokeColors.inkDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: spec.rarity.color.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: PokeColors.darken(
                                          spec.rarity.color, 0.14)),
                                ),
                                child: Text(
                                  spec.rarity == PokemonRarity.special
                                      ? "SPECIAL • EVENT ONLY"
                                      : "${spec.rarity.displayName.toUpperCase()} • ${(spec.rarity.encounterProbability * 100).round()}%",
                                  style: TextStyle(
                                    color: PokeColors.darken(
                                        spec.rarity.color, 0.16),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              if (spec.exclusiveVersion != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: spec.exclusiveVersion!.primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${spec.exclusiveVersion!.shortLabel} EXCLUSIVE",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Abilities
                    const Text(
                      "ABILITIES",
                      style: TextStyle(
                        color: PokeColors.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...spec.standardAbilityIds.map((abId) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: PokeDecorations.card(
                                fill: PokeColors.cardWhite,
                                border: PokeColors.pokeBlue,
                                radius: 8,
                                borderWidth: 1.2,
                              ),
                              child: Text(
                                AbilityDatabase.nameOf(abId),
                                style: const TextStyle(
                                  color: PokeColors.pokeBlueDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )),
                        if (spec.hiddenAbilityId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: PokeDecorations.card(
                              fill: PokeColors.cardWhite,
                              border: PokeColors.badgeGoldDark,
                              radius: 8,
                              borderWidth: 1.3,
                            ),
                            child: Text(
                              "${AbilityDatabase.nameOf(spec.hiddenAbilityId)} (Hidden)",
                              style: const TextStyle(
                                color: PokeColors.badgeGoldDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Base Stats
                    const Text(
                      "BASE STATS",
                      style: TextStyle(
                        color: PokeColors.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildBaseStatRow(
                        "HP", spec.baseHp, PokeColors.pokeGreen),
                    _buildBaseStatRow("ATK", spec.baseAtk, PokeColors.pokeRed),
                    _buildBaseStatRow(
                        "DEF", spec.baseDef, PokeColors.bagOrange),
                    _buildBaseStatRow(
                        "SPA", spec.baseSpA, PokeColors.pokeBlue),
                    _buildBaseStatRow(
                        "SPD", spec.baseSpD, PokeColors.linkTeal),
                    _buildBaseStatRow(
                        "SPE", spec.baseSpe, PokeColors.badgeGoldDark),

                    if (PokedexDatabase.evolutionRequirementLabel(spec) !=
                        null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: PokeDecorations.card(
                          fill: PokeColors.cardWhite,
                          border: PokeColors.badgeGold,
                          radius: 12,
                          borderWidth: 1.3,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                color: PokeColors.badgeGoldDark, size: 17),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                PokedexDatabase.evolutionRequirementLabel(
                                    spec)!,
                                style: const TextStyle(
                                  color: PokeColors.inkDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Level-Up Learnset
                    const Text(
                      "LEVEL-UP LEARNSET",
                      style: TextStyle(
                        color: PokeColors.inkMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: spec.learnset.map((lm) {
                        final move = PokedexDatabase.moves[lm.moveId];
                        if (move == null) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: PokeDecorations.card(
                            fill: PokeColors.cardWhite,
                            border: move.type.color,
                            radius: 10,
                            borderWidth: 1.2,
                          ),
                          child: Text(
                            "Lv.${lm.level}  ${move.name}",
                            style: const TextStyle(
                              color: PokeColors.inkDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
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

  Widget _buildBaseStatRow(String label, int val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              label,
              style: const TextStyle(
                  color: PokeColors.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              "$val",
              style: const TextStyle(
                  color: PokeColors.inkDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (val / 160.0).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: PokeColors.panelSoft,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom-painted classic red/white Poké Ball symbol (filled when caught, faint outline when seen-only).
class PokeBallSymbol extends StatelessWidget {
  final double size;
  final bool isCaught;

  const PokeBallSymbol({
    super.key,
    this.size = 18,
    this.isCaught = true,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _PokeBallSymbolPainter(isCaught: isCaught),
    );
  }
}

class _PokeBallSymbolPainter extends CustomPainter {
  final bool isCaught;

  _PokeBallSymbolPainter({required this.isCaught});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (!isCaught) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = PokeColors.badgeGoldDark,
      );
      canvas.drawCircle(
        center,
        radius * 0.34,
        Paint()..color = PokeColors.badgeGoldDark,
      );
      return;
    }

    canvas.drawArc(
      rect,
      3.14159265,
      3.14159265,
      true,
      Paint()..color = const Color(0xFFE53935),
    );
    canvas.drawArc(
      rect,
      0,
      3.14159265,
      true,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.width * 0.08).clamp(1.2, 2.2)
        ..color = Colors.black,
    );
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      Paint()
        ..strokeWidth = (size.width * 0.1).clamp(1.4, 2.5)
        ..color = Colors.black,
    );
    canvas.drawCircle(
      center,
      radius * 0.36,
      Paint()..color = Colors.black,
    );
    canvas.drawCircle(
      center,
      radius * 0.22,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PokeBallSymbolPainter oldDelegate) =>
      oldDelegate.isCaught != isCaught;
}
