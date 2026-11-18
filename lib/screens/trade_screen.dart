import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/move.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/pokedex_database.dart';
import '../services/pvp_link_service.dart';
import '../widgets/move_learn_dialog.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/type_badge.dart';
import 'evolution_screen.dart';

class TradeScreen extends StatefulWidget {
  final PvpTradeSession session;

  const TradeScreen({
    super.key,
    required this.session,
  });

  @override
  State<TradeScreen> createState() => _TradeScreenState();
}

class _TradeScreenState extends State<TradeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _beamController;
  bool _isAnimatingTrade = false;
  bool _tradeCompletedBanner = false;
  String? _lastSentName;
  PokemonInstance? _lastReceivedMon;
  bool _leftSent = false;

  @override
  void initState() {
    super.initState();
    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    widget.session.onStateChanged = () {
      if (!mounted) return;
      setState(() {});
    };

    widget.session.onPeerLeft = () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${widget.session.partnerName} left the Trade Link room."),
          duration: const Duration(seconds: 2),
        ),
      );
      if (!_isAnimatingTrade) {
        setState(() {});
      }
    };

    widget.session.onTradeExecute = (partyIndex, receivedMon) {
      _executeTradeTransfer(partyIndex, receivedMon);
    };

    widget.session.startListening();
  }

  @override
  void dispose() {
    if (!_leftSent) {
      _leftSent = true;
      widget.session.sendLeave();
    }
    widget.session.dispose();
    _beamController.dispose();
    super.dispose();
  }

  Future<void> _executeTradeTransfer(
    int partyIndex,
    PokemonInstance receivedMon,
  ) async {
    if (!mounted || _isAnimatingTrade) return;
    final trainer = Provider.of<Trainer>(context, listen: false);
    final sentMon = (partyIndex >= 0 && partyIndex < trainer.party.length)
        ? trainer.party[partyIndex]
        : null;

    setState(() {
      _isAnimatingTrade = true;
      _tradeCompletedBanner = false;
      _lastSentName = sentMon?.nickname ?? 'Pokémon';
    });

    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 1450));
    if (!mounted) return;

    final transferredCopy = PokemonInstance.fromJson(receivedMon.toJson());
    trainer.completeTradeSwap(partyIndex, transferredCopy);
    await trainer.saveProgress();

    // Check Gen 1 Link Trade Evolution (Kadabra -> Alakazam, Machoke -> Machamp, Graveler -> Golem, Haunter -> Gengar)
    final int? tradeEvoId =
        PokedexDatabase.getTradeEvolutionTarget(transferredCopy.species.id);
    if (tradeEvoId != null) {
      final nextSpecies = PokedexDatabase.species[tradeEvoId];
      if (nextSpecies != null) {
        final fromSpecies = transferredCopy.species;
        final oldNickname = transferredCopy.nickname;
        final List<Move> pendingEvoMoves = [];
        final learnedMoves = transferredCopy.evolve(
          nextSpecies,
          PokedexDatabase.movesUnlockedAtExactLevel(
            nextSpecies,
            transferredCopy.level,
          ),
          pendingMovesOut: pendingEvoMoves,
        );
        trainer.markPokemonCaught(
          nextSpecies.id,
          isShiny: transferredCopy.isShiny,
        );
        await trainer.saveProgress();
        if (!mounted) return;

        await EvolutionScreen.show(
          context,
          fromSpecies: fromSpecies,
          toSpecies: nextSpecies,
          oldNickname: oldNickname,
          learnedMoves: learnedMoves,
          isShiny: transferredCopy.isShiny,
        );
        if (!mounted) return;

        for (final newMove in pendingEvoMoves) {
          final outcome = await showMoveLearnDialog(
            context,
            pokemon: transferredCopy,
            newMove: newMove,
            recordOnSkip: true,
          );
          if (outcome.learned) {
            await trainer.saveProgress();
          }
          if (!mounted) return;
        }
        await trainer.saveProgress();
      }
    }

    if (!mounted) return;
    setState(() {
      _isAnimatingTrade = false;
      _tradeCompletedBanner = true;
      _lastReceivedMon = transferredCopy;
    });
  }

  void _exitTradeRoom() {
    if (!_leftSent) {
      _leftSent = true;
      widget.session.sendLeave();
    }
    Navigator.pop(context);
  }

  Widget _buildOfferCard({
    required String ownerLabel,
    required Color accentColor,
    required PokemonInstance? mon,
    required bool isConfirmed,
    required String emptyText,
  }) {
    final heldItem =
        mon?.heldItemId != null ? ItemDatabase.byId(mon!.heldItemId!) : null;
    final int? tradeEvoTargetId = mon != null
        ? PokedexDatabase.getTradeEvolutionTarget(mon.species.id)
        : null;
    final String? tradeEvoName = tradeEvoTargetId != null
        ? PokedexDatabase.species[tradeEvoTargetId]?.name
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (mon != null ? mon.species.types.first.color : accentColor)
                .withOpacity(mon != null ? 0.18 : 0.08),
            const Color(0xFF131827),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConfirmed
              ? const Color(0xFF34EB8C)
              : (mon != null
                  ? accentColor.withOpacity(0.55)
                  : Colors.white12),
          width: isConfirmed ? 1.8 : 1.2,
        ),
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
                  color: accentColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withOpacity(0.5)),
                ),
                child: Text(
                  ownerLabel,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isConfirmed
                      ? const Color(0xFF34EB8C).withOpacity(0.2)
                      : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isConfirmed
                        ? const Color(0xFF34EB8C)
                        : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConfirmed
                          ? Icons.lock_rounded
                          : (mon != null
                              ? Icons.hourglass_bottom_rounded
                              : Icons.radio_button_unchecked_rounded),
                      size: 11,
                      color: isConfirmed
                          ? const Color(0xFF34EB8C)
                          : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConfirmed
                          ? "LOCKED IN"
                          : (mon != null ? "READY" : "WAITING"),
                      style: TextStyle(
                        color: isConfirmed
                            ? const Color(0xFF34EB8C)
                            : Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (mon == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  emptyText,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0D18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: mon.isShiny
                          ? Colors.amberAccent.withOpacity(0.8)
                          : mon.species.types.first.color.withOpacity(0.5),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Image.network(
                          mon.spriteUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (_, __, ___) => Image.network(
                            mon.staticSpriteUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.none,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.catching_pokemon,
                              color: mon.species.types.first.color,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                      if (mon.isShiny)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.amberAccent,
                            size: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PokeBallSpriteWidget(
                              ballType: mon.caughtBall, size: 14),
                          const SizedBox(width: 5),
                          if (mon.isShiny) ...[
                            const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.amberAccent,
                              size: 13,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Expanded(
                            child: Text(
                              mon.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            "Lv.${mon.level}",
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...mon.species.types.map((t) => TypeBadge(type: t)),
                          if (heldItem != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Held: ${heldItem.name}",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (tradeEvoName != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: Colors.amberAccent.withOpacity(0.7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 11,
                                color: Colors.amberAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "TRADE EVOLVES → ${tradeEvoName.toUpperCase()}",
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final session = widget.session;
    final myOffer = session.myOffer;
    final peerOffer = session.peerOffer;
    final bool canConfirm =
        myOffer != null && peerOffer != null && !_isAnimatingTrade;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_leftSent) {
          _leftSent = true;
          widget.session.sendLeave();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0D18),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/bg_bump_radar.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.none,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0D18).withOpacity(0.84),
                    const Color(0xFF0C1222).withOpacity(0.78),
                    const Color(0xFF080A14).withOpacity(0.94),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        Material(
                          color: const Color(0xFF171E2E),
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: _exitTradeRoom,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.14),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 15,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "FIST-BUMP LINK TRADE",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                session.isPeerLeft
                                    ? "${session.partnerName} disconnected"
                                    : "Linked with ${session.partnerName} • Round #${session.round}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: session.isPeerLeft
                                      ? Colors.redAccent
                                      : Colors.cyanAccent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Partner Offer
                    _buildOfferCard(
                      ownerLabel: "${session.partnerName.toUpperCase()}'S OFFER",
                      accentColor: Colors.cyanAccent,
                      mon: peerOffer,
                      isConfirmed: session.peerConfirmed,
                      emptyText: session.isPeerLeft
                          ? "${session.partnerName} exited the trade room."
                          : "Waiting for ${session.partnerName} to choose a Pokémon...",
                    ),

                    // Link Transfer Beam Indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: AnimatedBuilder(
                        animation: _beamController,
                        builder: (context, _) {
                          final pulse = _beamController.value;
                          final active = myOffer != null && peerOffer != null;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.swap_vert_rounded,
                                size: 22,
                                color: active
                                    ? Color.lerp(
                                        Colors.cyanAccent,
                                        const Color(0xFF34EB8C),
                                        (0.5 + 0.5 * (pulse * 2 - 1).abs()),
                                      )
                                    : Colors.white24,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isAnimatingTrade
                                    ? "TRANSFERRING POKÉMON DATA..."
                                    : (session.myConfirmed &&
                                            session.peerConfirmed
                                        ? "BOTH LOCKED • EXECUTING TRADE!"
                                        : (active
                                            ? "LOCK BOTH OFFERS TO TRADE"
                                            : "SELECT POKÉMON BELOW TO OFFER")),
                                style: TextStyle(
                                  color: active
                                      ? Colors.amberAccent
                                      : Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Your Offer
                    _buildOfferCard(
                      ownerLabel: "${trainer.name.toUpperCase()}'S OFFER",
                      accentColor: Colors.amberAccent,
                      mon: myOffer,
                      isConfirmed: session.myConfirmed,
                      emptyText: "Tap a Pokémon from your party below to offer.",
                    ),

                    const SizedBox(height: 8),

                    // Trade Complete Banner OR Party Picker
                    if (_tradeCompletedBanner && _lastReceivedMon != null) ...[
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131B2E),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFF34EB8C).withOpacity(0.65),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF34EB8C),
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "LINK TRADE COMPLETE!",
                                style: TextStyle(
                                  color: Color(0xFF34EB8C),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Sent $_lastSentName ↔ Received ${_lastReceivedMon!.species.name}!",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _exitTradeRoom,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(
                                            color: Colors.white24),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        "EXIT",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton.icon(
                                      onPressed: session.isPeerLeft
                                          ? null
                                          : () {
                                              setState(() {
                                                _tradeCompletedBanner = false;
                                              });
                                              session.startNextTradeRound();
                                            },
                                      icon: const Icon(
                                          Icons.swap_horiz_rounded,
                                          size: 18),
                                      label: const Text(
                                        "TRADE ANOTHER",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF00ACC1),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xCC111626),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "YOUR POKÉMON PARTY",
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                    childAspectRatio: 2.35,
                                  ),
                                  itemCount: trainer.party.length,
                                  itemBuilder: (ctx, idx) {
                                    final mon = trainer.party[idx];
                                    final selected =
                                        session.myPartyIndex == idx &&
                                            myOffer != null;
                                    final tradeEvo = PokedexDatabase
                                            .getTradeEvolutionTarget(
                                                mon.species.id) !=
                                        null;
                                    return InkWell(
                                      onTap: (_isAnimatingTrade ||
                                              session.isPeerLeft)
                                          ? null
                                          : () => session.selectOffer(idx, mon),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? Colors.amberAccent
                                                  .withOpacity(0.16)
                                              : const Color(0xFF1A2135),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selected
                                                ? Colors.amberAccent
                                                : (tradeEvo
                                                    ? Colors.cyanAccent
                                                        .withOpacity(0.55)
                                                    : Colors.white12),
                                            width: selected ? 1.6 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Image.network(
                                              mon.spriteUrl,
                                              width: 36,
                                              height: 36,
                                              fit: BoxFit.contain,
                                              filterQuality: FilterQuality.none,
                                              errorBuilder: (_, __, ___) =>
                                                  Image.network(
                                                mon.staticSpriteUrl,
                                                width: 36,
                                                height: 36,
                                                filterQuality:
                                                    FilterQuality.none,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                  Icons.catching_pokemon,
                                                  color: Colors.white54,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      if (mon.isShiny) ...[
                                                        const Icon(
                                                          Icons
                                                              .auto_awesome_rounded,
                                                          color:
                                                              Colors.amberAccent,
                                                          size: 11,
                                                        ),
                                                        const SizedBox(width: 2),
                                                      ],
                                                      Expanded(
                                                        child: Text(
                                                          mon.nickname,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 11.5,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    tradeEvo
                                                        ? "Lv.${mon.level} • Evolves!"
                                                        : "Lv.${mon.level}",
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: tradeEvo
                                                          ? Colors.cyanAccent
                                                          : Colors.amberAccent,
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (session.myConfirmed && !_isAnimatingTrade)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton(
                                    onPressed: session.unlockConfirmation,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.amberAccent,
                                      side: const BorderSide(
                                          color: Colors.amberAccent),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      "UNLOCK",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: (canConfirm &&
                                        !session.myConfirmed &&
                                        !session.isPeerLeft)
                                    ? session.lockConfirmation
                                    : null,
                                icon: Icon(
                                  _isAnimatingTrade
                                      ? Icons.sync_rounded
                                      : (session.myConfirmed
                                          ? Icons.lock_rounded
                                          : Icons.swap_horiz_rounded),
                                  size: 19,
                                ),
                                label: Text(
                                  _isAnimatingTrade
                                      ? "TRADING..."
                                      : (session.myConfirmed
                                          ? "LOCKED • WAITING PARTNER"
                                          : "LOCK & CONFIRM TRADE"),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00BFA5),
                                  foregroundColor: Colors.black87,
                                  disabledBackgroundColor: session.myConfirmed
                                      ? const Color(0xFF34EB8C)
                                          .withOpacity(0.25)
                                      : Colors.white12,
                                  disabledForegroundColor: session.myConfirmed
                                      ? const Color(0xFF34EB8C)
                                      : Colors.white38,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isAnimatingTrade)
              Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 54,
                        height: 54,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          color: Colors.cyanAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Sending $_lastSentName...",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Fist-Bump Link Cable Transfer in progress!",
                        style: TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
