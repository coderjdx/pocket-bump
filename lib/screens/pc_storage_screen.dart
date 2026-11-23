import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_species.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import 'pokemon_detail_screen.dart';

class PcStorageScreen extends StatefulWidget {
  const PcStorageScreen({super.key});

  @override
  State<PcStorageScreen> createState() => _PcStorageScreenState();
}

class _PcStorageScreenState extends State<PcStorageScreen> {
  // Selection state: either a PC slot or a Party slot (or none)
  bool _selectedInParty = false;
  int? _selectedBoxIndex;
  int? _selectedSlotIndex;
  int? _selectedPartyIndex;

  void _selectPcSlot(int boxIndex, int slotIndex) {
    setState(() {
      _selectedInParty = false;
      _selectedBoxIndex = boxIndex;
      _selectedSlotIndex = slotIndex;
      _selectedPartyIndex = null;
    });
  }

  void _selectPartySlot(int partyIndex) {
    setState(() {
      _selectedInParty = true;
      _selectedPartyIndex = partyIndex;
      _selectedBoxIndex = null;
      _selectedSlotIndex = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedInParty = false;
      _selectedBoxIndex = null;
      _selectedSlotIndex = null;
      _selectedPartyIndex = null;
    });
  }

  void _openPcPokemonInfo(int boxIdx, int slotIdx) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PokemonDetailScreen(
          pcBoxIndex: boxIdx,
          pcSlotIndex: slotIdx,
        ),
      ),
    );
  }

  Future<void> _openPartyPokemonInfo(int partyIdx) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => PokemonDetailScreen(partyIndex: partyIdx),
      ),
    );
    if (result == 'promoted_to_lead' && mounted) {
      _selectPartySlot(0);
    }
  }

  void _openSelectedPokemonInfo() {
    if (_selectedInParty) {
      final partyIdx = _selectedPartyIndex;
      if (partyIdx != null) {
        _openPartyPokemonInfo(partyIdx);
      }
      return;
    }
    final boxIdx = _selectedBoxIndex;
    final slotIdx = _selectedSlotIndex;
    if (boxIdx != null && slotIdx != null) {
      _openPcPokemonInfo(boxIdx, slotIdx);
    }
  }

  PokemonInstance? _resolveSelectedPokemon(Trainer trainer) {
    if (_selectedInParty) {
      final idx = _selectedPartyIndex;
      if (idx != null && idx >= 0 && idx < trainer.party.length) {
        return trainer.party[idx];
      }
      return null;
    }
    final bIdx = _selectedBoxIndex;
    final sIdx = _selectedSlotIndex;
    if (bIdx != null &&
        sIdx != null &&
        bIdx == trainer.activePcBoxIndex &&
        bIdx >= 0 &&
        bIdx < Trainer.numPcBoxes &&
        sIdx >= 0 &&
        sIdx < trainer.pcBoxes[bIdx].length) {
      return trainer.pcBoxes[bIdx][sIdx];
    }
    return null;
  }

  void _switchBox(Trainer trainer, int newBoxIndex) {
    final normalized = (newBoxIndex + Trainer.numPcBoxes) % Trainer.numPcBoxes;
    trainer.setActivePcBox(normalized);
    if (!_selectedInParty) {
      setState(() {
        _selectedBoxIndex = null;
        _selectedSlotIndex = null;
      });
    }
  }

  Widget _buildPokemonSprite(
    PokemonSpecies species, {
    double size = 40,
    bool isShiny = false,
  }) {
    final fallbackColor = species.types.first.color;
    return Image.network(
      isShiny ? species.shinySpriteUrl : species.spriteUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, __, ___) => Image.network(
        isShiny ? species.staticShinySpriteUrl : species.staticSpriteUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => Icon(
          Icons.catching_pokemon,
          color: fallbackColor,
          size: size * 0.72,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Trainer>(
      builder: (context, trainer, _) {
        final int boxIdx = trainer.activePcBoxIndex;
        final List<PokemonInstance> currentBox = trainer.pcBoxes[boxIdx];
        final PokemonInstance? selectedMon = _resolveSelectedPokemon(trainer);

        return Scaffold(
          backgroundColor: const Color(0xFF0B0C18),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: const Color(0xCC0D0E1B),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "BILL'S PC STORAGE",
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "${trainer.totalPcPokemon}/${trainer.maxPcCapacity} Stored • 16 Boxes × 20 Slots",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.purpleAccent.shade100,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10, top: 8, bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => _openBoxGridModal(trainer),
                  icon: const Icon(Icons.grid_view_rounded, size: 14),
                  label: const Text(
                    "BOXES",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A0B14),
                    foregroundColor: Colors.purpleAccent.shade100,
                    side: BorderSide(
                      color: Colors.purpleAccent.withOpacity(0.6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/bg_pc_storage.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF0E0C1D).withOpacity(0.74),
                      const Color(0xFF100E22).withOpacity(0.60),
                      const Color(0xFF090814).withOpacity(0.88),
                    ],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  child: Column(
                    children: [
                      // 1. Box Switcher Bar
                      _buildBoxHeaderBar(trainer, boxIdx, currentBox.length),
                      const SizedBox(height: 8),

                      // 2. 5x4 (20-slot) Holographic PC Box Grid
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xE8131426), Color(0xE80C0E1B)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.purpleAccent.withOpacity(0.45),
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            children: List.generate(4, (row) {
                              return Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: row < 3 ? 5 : 0,
                                  ),
                                  child: Row(
                                    children: List.generate(5, (col) {
                                      final slotIdx = row * 5 + col;
                                      final mon = slotIdx < currentBox.length
                                          ? currentBox[slotIdx]
                                          : null;
                                      final isSelected = !_selectedInParty &&
                                          _selectedBoxIndex == boxIdx &&
                                          _selectedSlotIndex == slotIdx;
                                      return Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            right: col < 4 ? 5 : 0,
                                          ),
                                          child: _buildBoxSlotTile(
                                            boxIdx: boxIdx,
                                            slotIdx: slotIdx,
                                            mon: mon,
                                            isSelected: isSelected,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 3. Inspector & Actions Card
                      _buildInspectorCard(
                          trainer, boxIdx, currentBox.length, selectedMon),

                      const SizedBox(height: 8),

                      // 4. Bottom 6-Slot Party Strip
                      _buildPartyStrip(trainer),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoxHeaderBar(Trainer trainer, int boxIdx, int count) {
    final bool isFull = count >= Trainer.maxPokemonPerBox;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.shade900.withOpacity(0.68),
            const Color(0xEA141628),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.55)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _switchBox(trainer, boxIdx - 1),
            icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
            tooltip: "Previous Box",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _openBoxGridModal(trainer),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A0B16),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: Colors.purpleAccent.withOpacity(0.55)),
                    ),
                    child: Text(
                      "BOX ${boxIdx + 1}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$count/${Trainer.maxPokemonPerBox}",
                    style: TextStyle(
                      color: isFull ? Colors.amberAccent : Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: Colors.greenAccent.withOpacity(0.55),
                      ),
                    ),
                    child: const Text(
                      "ACTIVE",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _switchBox(trainer, boxIdx + 1),
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
            tooltip: "Next Box",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxSlotTile({
    required int boxIdx,
    required int slotIdx,
    required PokemonInstance? mon,
    required bool isSelected,
  }) {
    if (mon == null) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B0C16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Center(
          child: Text(
            "${slotIdx + 1}",
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final typeColor = mon.species.types.first.color;
    return InkWell(
      onTap: () => _selectPcSlot(boxIdx, slotIdx),
      onLongPress: () {
        _selectPcSlot(boxIdx, slotIdx);
        _openPcPokemonInfo(boxIdx, slotIdx);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [typeColor.withOpacity(0.32), const Color(0xFF15182B)]
                : [typeColor.withOpacity(0.12), const Color(0xFF141626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.amberAccent
                : typeColor.withOpacity(0.55),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: _buildPokemonSprite(mon.species,
                          size: 36, isShiny: mon.isShiny),
                    ),
                  ),
                ),
                Text(
                  "Lv${mon.level}",
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFFFFD54F),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (mon.isShiny)
              const Positioned(
                top: 2,
                left: 2,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.amberAccent,
                  size: 11,
                ),
              ),
            if (mon.hasHeldItem)
              const Positioned(
                top: 2,
                right: 2,
                child: Icon(
                  Icons.shopping_bag,
                  size: 10,
                  color: Colors.cyanAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectorCard(
    Trainer trainer,
    int boxIdx,
    int currentBoxCount,
    PokemonInstance? selectedMon,
  ) {
    if (selectedMon == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xE816172A), Color(0xE80E101D)],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white12),
        ),
        child: const Row(
          children: [
            Icon(Icons.computer_rounded, color: Colors.purpleAccent, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PC TERMINAL READY",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      letterSpacing: 0.7,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "Tap any Pokémon in the Box above or your Party below to view info, withdraw, deposit, swap, move between boxes, or release.",
                    style: TextStyle(color: Colors.white60, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final Color primaryColor = selectedMon.species.types.first.color;
    final heldName = selectedMon.hasHeldItem
        ? (ItemDatabase.byId(selectedMon.heldItemId!)?.name ??
            selectedMon.heldItemId!)
        : null;

    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.22),
            const Color(0xEA121423),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: primaryColor.withOpacity(0.65), width: 1.2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top info row
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _openSelectedPokemonInfo,
                  borderRadius: BorderRadius.circular(10),
                  child: Row(
                    children: [
                      _buildPokemonSprite(selectedMon.species,
                          size: 46, isShiny: selectedMon.isShiny),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: _selectedInParty
                                        ? Colors.redAccent.withOpacity(0.22)
                                        : Colors.purpleAccent.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    _selectedInParty
                                        ? "POKÉMON #${(_selectedPartyIndex ?? 0) + 1}"
                                        : "BOX ${boxIdx + 1}",
                                    style: TextStyle(
                                      color: _selectedInParty
                                          ? Colors.redAccent.shade100
                                          : Colors.purpleAccent.shade100,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    selectedMon.nickname,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Lv.${selectedMon.level}",
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "HP ${selectedMon.maxHp} • ATK ${selectedMon.atk} • DEF ${selectedMon.def} • SPA ${selectedMon.spa} • SPD ${selectedMon.spd} • SPE ${selectedMon.spe}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              heldName != null
                                  ? "Moves: ${selectedMon.moves.map((m) => m.name).join(', ')} • Held: $heldName"
                                  : "Moves: ${selectedMon.moves.map((m) => m.name).join(', ')}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: _openSelectedPokemonInfo,
                icon: const Icon(Icons.auto_stories_rounded, size: 13),
                label: const Text(
                  "INFO",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.cyanAccent,
                  side: BorderSide(color: Colors.cyanAccent.withOpacity(0.55)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Bottom action buttons row
          if (_selectedInParty)
            _buildPartyActionButtons(
              trainer,
              boxIdx,
              currentBoxCount,
              _selectedPartyIndex!,
              selectedMon,
            )
          else
            _buildPcActionButtons(
              trainer,
              boxIdx,
              _selectedSlotIndex!,
              selectedMon,
            ),
        ],
      ),
    );
  }

  Widget _buildPcActionButtons(
    Trainer trainer,
    int boxIdx,
    int slotIdx,
    PokemonInstance mon,
  ) {
    final canWithdraw = trainer.party.length < 6;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 30,
            child: ElevatedButton.icon(
              onPressed: canWithdraw
                  ? () {
                      final ok = trainer.withdrawPokemonFromPc(boxIdx, slotIdx);
                      if (ok) {
                        _clearSelection();
                        _showToast("${mon.nickname} joined your Party!");
                      }
                    }
                  : null,
              icon: const Icon(Icons.download, size: 14),
              label: Text(
                canWithdraw ? "Withdraw" : "Party Full",
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent.shade400,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: 30,
            child: OutlinedButton.icon(
              onPressed: () => _openSwapModal(trainer, boxIdx, slotIdx, mon),
              icon: const Icon(Icons.swap_horiz, size: 14),
              label: const Text(
                "Swap",
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
                side: BorderSide(color: Colors.cyanAccent.withOpacity(0.55)),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: 30,
            child: OutlinedButton.icon(
              onPressed: () => _openBoxGridModal(
                trainer,
                moveFromBox: boxIdx,
                moveFromSlot: slotIdx,
                movingMon: mon,
              ),
              icon: const Icon(Icons.folder_open, size: 14),
              label: const Text(
                "Move",
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purpleAccent.shade100,
                side: BorderSide(color: Colors.purpleAccent.withOpacity(0.55)),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: 30,
          width: 36,
          child: OutlinedButton(
            onPressed: () => _confirmRelease(
              mon: mon,
              locationLabel: "Box ${boxIdx + 1}",
              onConfirm: () {
                if (trainer.releasePcPokemon(boxIdx, slotIdx)) {
                  _clearSelection();
                  _showToast("${mon.nickname} was released.");
                }
              },
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent.withOpacity(0.55)),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Icon(Icons.delete_outline, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPartyActionButtons(
    Trainer trainer,
    int boxIdx,
    int currentBoxCount,
    int partyIdx,
    PokemonInstance mon,
  ) {
    final bool canDeposit =
        trainer.party.length > 1 && currentBoxCount < Trainer.maxPokemonPerBox;
    final bool isLead = partyIdx == 0;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 30,
            child: ElevatedButton.icon(
              onPressed: canDeposit
                  ? () {
                      final ok = trainer.depositPokemonToPc(
                        partyIdx,
                        targetBoxIndex: boxIdx,
                      );
                      if (ok) {
                        _clearSelection();
                        _showToast(
                            "${mon.nickname} was deposited to Box ${boxIdx + 1}!");
                      }
                    }
                  : null,
              icon: const Icon(Icons.upload, size: 14),
              label: Text(
                trainer.party.length <= 1
                    ? "Last Pokémon"
                    : (currentBoxCount >= Trainer.maxPokemonPerBox
                        ? "Box ${boxIdx + 1} Full"
                        : "Deposit to Box ${boxIdx + 1}"),
                style:
                    const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent.shade200,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white38,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        if (!isLead)
          Expanded(
            child: SizedBox(
              height: 30,
              child: OutlinedButton.icon(
                onPressed: () {
                  trainer.setLeadPokemon(partyIdx);
                  _selectPartySlot(0);
                  _showToast("${mon.nickname} is now Party Lead!");
                },
                icon: const Icon(Icons.star, size: 14),
                label: const Text(
                  "Lead",
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amberAccent,
                  side: BorderSide(color: Colors.amberAccent.withOpacity(0.55)),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        if (!isLead) const SizedBox(width: 6),
        if (trainer.party.length > 1)
          SizedBox(
            height: 30,
            width: 36,
            child: OutlinedButton(
              onPressed: () => _confirmRelease(
                mon: mon,
                locationLabel: "your carried Party",
                onConfirm: () {
                  if (trainer.releasePokemon(partyIdx)) {
                    _clearSelection();
                    _showToast("${mon.nickname} was released.");
                  }
                },
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withOpacity(0.55)),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Icon(Icons.delete_outline, size: 16),
            ),
          ),
      ],
    );
  }

  Widget _buildPartyStrip(Trainer trainer) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: const Color(0xE8131426),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "CARRIED POKÉMON",
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.7,
                ),
              ),
              Text(
                "${trainer.party.length}/6 Pokémon",
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: List.generate(6, (idx) {
              final mon = idx < trainer.party.length ? trainer.party[idx] : null;
              final isSelected = _selectedInParty && _selectedPartyIndex == idx;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: idx < 5 ? 5 : 0),
                  child: _buildPartyStripSlot(idx, mon, isSelected),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyStripSlot(
    int idx,
    PokemonInstance? mon,
    bool isSelected,
  ) {
    if (mon == null) {
      return Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0B15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: Icon(Icons.catching_pokemon, size: 16, color: Colors.white12),
        ),
      );
    }

    final typeColor = mon.species.types.first.color;
    return InkWell(
      onTap: () => _selectPartySlot(idx),
      onLongPress: () {
        _selectPartySlot(idx);
        _openPartyPokemonInfo(idx);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? typeColor.withOpacity(0.24)
              : const Color(0xFF16192C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.amberAccent
                : (idx == 0
                    ? Colors.amberAccent.withOpacity(0.45)
                    : typeColor.withOpacity(0.4)),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: _buildPokemonSprite(mon.species,
                          size: 32, isShiny: mon.isShiny),
                    ),
                  ),
                ),
                Text(
                  "Lv${mon.level}",
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (mon.isShiny)
              const Positioned(
                top: 2,
                right: 2,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.amberAccent,
                  size: 10,
                ),
              ),
            if (idx == 0)
              Positioned(
                top: 2,
                left: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    "L",
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openSwapModal(
    Trainer trainer,
    int boxIdx,
    int slotIdx,
    PokemonInstance pcMon,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121423),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dlgCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "SWAP ${pcMon.nickname.toUpperCase()} WITH POKÉMON",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(dlgCtx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(trainer.party.length, (partyIdx) {
                final partyMon = trainer.party[partyIdx];
                return InkWell(
                  onTap: () {
                    final ok = trainer.swapPartyAndPcPokemon(
                      partyIdx,
                      boxIdx,
                      slotIdx,
                    );
                    Navigator.pop(dlgCtx);
                    if (ok) {
                      _showToast(
                        "Swapped ${pcMon.nickname} with ${partyMon.nickname}!",
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E2E3B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: partyIdx == 0
                            ? Colors.amberAccent.withOpacity(0.45)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildPokemonSprite(partyMon.species,
                            size: 38, isShiny: partyMon.isShiny),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partyMon.nickname,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                "Spot #${partyIdx + 1} • Lv.${partyMon.level}",
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.swap_horiz,
                            color: Colors.cyanAccent, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _openBoxGridModal(
    Trainer trainer, {
    int? moveFromBox,
    int? moveFromSlot,
    PokemonInstance? movingMon,
  }) {
    final bool isMoving =
        moveFromBox != null && moveFromSlot != null && movingMon != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121423),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (dlgCtx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isMoving
                          ? "MOVE ${movingMon.nickname.toUpperCase()} TO BOX"
                          : "ALL 16 PC BOXES (${trainer.totalPcPokemon}/320)",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(dlgCtx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: Trainer.numPcBoxes,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.45,
                ),
                itemBuilder: (_, idx) {
                  final count = trainer.pcBoxes[idx].length;
                  final isFull = count >= Trainer.maxPokemonPerBox;
                  final isCurrent = idx == trainer.activePcBoxIndex;
                  final canTap = !isMoving || (!isFull && idx != moveFromBox);

                  return InkWell(
                    onTap: canTap
                        ? () {
                            Navigator.pop(dlgCtx);
                            if (isMoving) {
                              final ok = trainer.movePcPokemonToBox(
                                moveFromBox,
                                moveFromSlot,
                                idx,
                              );
                              if (ok) {
                                _switchBox(trainer, idx);
                                _showToast(
                                  "Moved ${movingMon.nickname} to Box ${idx + 1}!",
                                );
                              }
                            } else {
                              _switchBox(trainer, idx);
                            }
                          }
                        : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Colors.purpleAccent.withOpacity(0.22)
                            : const Color(0xFF2E2E3B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent
                              ? Colors.purpleAccent
                              : (isFull ? Colors.redAccent.withOpacity(0.4) : Colors.white12),
                          width: isCurrent ? 1.6 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "BOX ${idx + 1}",
                            style: TextStyle(
                              color: canTap ? Colors.white : Colors.white38,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "$count/20",
                            style: TextStyle(
                              color: isFull
                                  ? Colors.redAccent
                                  : (count > 0
                                      ? Colors.greenAccent
                                      : Colors.white54),
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
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

  void _confirmRelease({
    required PokemonInstance mon,
    required String locationLabel,
    required VoidCallback onConfirm,
  }) {
    final heldNote = mon.hasHeldItem
        ? "\nIts held item (${ItemDatabase.byId(mon.heldItemId!)?.name ?? mon.heldItemId}) will return to your Bag."
        : "";
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A35),
        title: Text(
          "Release ${mon.nickname}?",
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Lv.${mon.level} ${mon.species.name} will be permanently released from $locationLabel.$heldNote",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child:
                const Text("Cancel", style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dlgCtx);
              onConfirm();
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

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
