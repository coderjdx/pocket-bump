import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
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
    final List<int> allIds = PokedexDatabase.species.keys.toList()..sort();
    final int total = allIds.length;
    final int caughtTotal = trainer.caughtCount;
    final int seenTotal = trainer.seenCount;
    final int unseenTotal = allIds.where((id) => !trainer.isSpeciesSeen(id)).length;

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
      backgroundColor: const Color(0xFF100E16),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xCC160B10),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.cyanAccent,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.cyanAccent, blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "KANTO POKÉDEX",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/bg_pokedex.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1C0C12).withOpacity(0.76),
                  const Color(0xFF140E18).withOpacity(0.60),
                  const Color(0xFF0C0A12).withOpacity(0.88),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                children: [
                  // ─── DEXTER SCANNER SUMMARY BANNER ───────────────────────
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.shade900.withOpacity(0.55),
                          const Color(0xEA161322),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.redAccent.withOpacity(0.55),
                        width: 1.3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                                  "$caughtTotal Caught",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.visibility_rounded,
                                    color: Colors.amberAccent, size: 16),
                                const SizedBox(width: 5),
                                Text(
                                  "$seenTotal Seen",
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A0910),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Text(
                                "$total TOTAL",
                                style: const TextStyle(
                                  color: Colors.white70,
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
                            height: 8,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: const Color(0xFF09080E)),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: total > 0
                                      ? (seenTotal / total).clamp(0.0, 1.0)
                                      : 0.0,
                                  child: Container(
                                      color: Colors.amberAccent.withOpacity(0.55)),
                                ),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: total > 0
                                      ? (caughtTotal / total).clamp(0.0, 1.0)
                                      : 0.0,
                                  child: Container(color: Colors.redAccent),
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
                                      color: Colors.white60, fontSize: 10),
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
                                      color: Colors.white60, fontSize: 10),
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
                          onTap: () => setState(() => _filter = _PokedexFilter.all),
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
                            child: Text(
                              "No Pokémon in this filter yet.\nWalk or battle to discover more!",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 13),
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
                              return _buildDexCard(spec,
                                  isSeen: isSeen, isCaught: isCaught);
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
          gradient: selected
              ? LinearGradient(
                  colors: [Colors.red.shade600, Colors.red.shade800],
                )
              : null,
          color: selected ? null : const Color(0xDD171320),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.redAccent : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
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
        _openEntryDetail(spec, isCaught: isCaught);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCaught
                ? [primaryColor.withOpacity(0.24), const Color(0xEA141624)]
                : (isSeen
                    ? [const Color(0xEA1D1D2B), const Color(0xEA13131E)]
                    : [const Color(0xDD13121A), const Color(0xDD0D0C12)]),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCaught
                ? primaryColor.withOpacity(0.7)
                : (isSeen
                    ? Colors.amberAccent.withOpacity(0.38)
                    : Colors.white10),
            width: isCaught ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            // Top Row: #ID and Caught / Encountered / Unseen indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dexNum,
                  style: TextStyle(
                    color: isSeen ? Colors.white70 : Colors.white30,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                  ),
                ),
                if (isCaught)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0810),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: Colors.redAccent.withOpacity(0.7)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PokeBallSymbol(size: 12, isCaught: true),
                        SizedBox(width: 4),
                        Text(
                          "CAUGHT",
                          style: TextStyle(
                            color: Colors.white,
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
                      color: const Color(0xFF0A0810),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.amberAccent.withOpacity(0.55)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PokeBallSymbol(size: 11, isCaught: false),
                        SizedBox(width: 4),
                        Text(
                          "SEEN",
                          style: TextStyle(
                            color: Colors.amberAccent,
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
                      color: Colors.white24,
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
                      ? [primaryColor.withOpacity(0.26), Colors.transparent]
                      : [Colors.white.withOpacity(0.05), Colors.transparent],
                ),
              ),
              child: ColorFiltered(
                colorFilter: !isSeen
                    ? const ColorFilter.mode(Colors.black, BlendMode.srcIn)
                    : (isCaught
                        ? const ColorFilter.mode(
                            Colors.transparent, BlendMode.dst)
                        : ColorFilter.mode(
                            Colors.grey.shade800.withOpacity(0.35),
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
                      color: isSeen ? primaryColor : Colors.black,
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
                color: isSeen ? Colors.white : Colors.white38,
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
                      color: t.color.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: t.color.withOpacity(0.8)),
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
                  color: spec.rarity.color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: spec.rarity.color.withOpacity(0.65)),
                ),
                child: Text(
                  spec.rarity.displayName.toUpperCase(),
                  style: TextStyle(
                    color: spec.rarity.color,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "???",
                  style: TextStyle(
                      color: Colors.white24,
                      fontSize: 8,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openEntryDetail(PokemonSpecies spec, {required bool isCaught}) {
    final primaryColor = spec.types.first.color;
    final dexNum = "#${spec.id.toString().padLeft(3, '0')}";
    final PokemonSpecies? evoTarget = spec.evolutionSpeciesId != null
        ? PokedexDatabase.species[spec.evolutionSpeciesId!]
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.78,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          "$dexNum  ${spec.name}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                // Status badge (Caught vs Encountered Only)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isCaught
                        ? Colors.greenAccent.withOpacity(0.14)
                        : Colors.amberAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isCaught
                          ? Colors.greenAccent.withOpacity(0.5)
                          : Colors.amberAccent.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isCaught)
                        const PokeBallSymbol(size: 16, isCaught: true)
                      else
                        const Icon(Icons.visibility, color: Colors.amberAccent, size: 16),
                      const SizedBox(width: 7),
                      Text(
                        isCaught
                            ? "CAUGHT & REGISTERED"
                            : "ENCOUNTERED ONLY (NOT YET CAUGHT)",
                        style: TextStyle(
                          color: isCaught ? Colors.greenAccent : Colors.amberAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Hero Sprite + Types + Height
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0B14),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: primaryColor.withOpacity(0.5)),
                        ),
                        child: Center(
                          child: Image.network(
                            spec.spriteUrl,
                            width: 102,
                            height: 102,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => Image.network(
                              spec.staticSpriteUrl,
                              width: 102,
                              height: 102,
                              filterQuality: FilterQuality.none,
                              errorBuilder: (_, __, ___) =>
                                  Icon(Icons.catching_pokemon, size: 64, color: primaryColor),
                            ),
                          ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "${spec.heightMeters} m",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: spec.rarity.color.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: spec.rarity.color.withOpacity(0.65)),
                            ),
                            child: Text(
                              spec.rarity == PokemonRarity.special
                                  ? "SPECIAL • EVENT ONLY"
                                  : "${spec.rarity.displayName.toUpperCase()} • ${(spec.rarity.encounterProbability * 100).round()}%",
                              style: TextStyle(
                                color: spec.rarity.color,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
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

                // Base Stats
                const Text(
                  "BASE STATS",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBaseStatRow("HP", spec.baseHp, Colors.greenAccent),
                _buildBaseStatRow("ATK", spec.baseAtk, Colors.redAccent),
                _buildBaseStatRow("DEF", spec.baseDef, Colors.orangeAccent),
                _buildBaseStatRow("SPA", spec.baseSpA, Colors.lightBlueAccent),
                _buildBaseStatRow("SPD", spec.baseSpD, Colors.tealAccent),
                _buildBaseStatRow("SPE", spec.baseSpe, Colors.amberAccent),

                if (evoTarget != null && spec.evolutionLevel != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 17),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Evolves into ${evoTarget.name} at Level ${spec.evolutionLevel}",
                            style: const TextStyle(
                              color: Colors.white,
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
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: move.type.color.withOpacity(0.5)),
                      ),
                      child: Text(
                        "Lv.${lm.level}  ${move.name}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
              style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              "$val",
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (val / 160.0).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: Colors.black38,
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
      // Muted outlined radar ring for Encountered-only Pokémon
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.amberAccent.withOpacity(0.75),
      );
      canvas.drawCircle(
        center,
        radius * 0.34,
        Paint()..color = Colors.amberAccent.withOpacity(0.75),
      );
      return;
    }

    // Authentic red top / white bottom Poké Ball for Caught Pokémon
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
