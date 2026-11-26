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
import '../widgets/poke_theme.dart';
import '../widgets/pokeball_sprite.dart';
import '../widgets/pokemon_sprite_image.dart';
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
          content:
              Text("${widget.session.partnerName} left the Trade Link room."),
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
    final Color typeAccent =
        mon != null ? mon.species.types.first.color : accentColor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: PokeDecorations.card(
        fill: mon != null
            ? Color.lerp(PokeColors.creamSurface, typeAccent, 0.08)!
            : PokeColors.creamSurface,
        border: isConfirmed
            ? PokeColors.pokeGreen
            : (mon != null ? accentColor : PokeColors.frameBorderSoft),
        radius: 18,
        borderWidth: isConfirmed ? 2.2 : 1.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ownerLabel,
                  style: const TextStyle(
                    color: Colors.white,
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
                      ? PokeColors.pokeGreen.withOpacity(0.16)
                      : PokeColors.cardWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isConfirmed
                        ? PokeColors.pokeGreen
                        : PokeColors.frameBorderSoft,
                    width: 1.3,
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
                          ? PokeColors.pokeGreenDark
                          : PokeColors.inkMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConfirmed
                          ? "LOCKED IN"
                          : (mon != null ? "READY" : "WAITING"),
                      style: TextStyle(
                        color: isConfirmed
                            ? PokeColors.pokeGreenDark
                            : PokeColors.inkMuted,
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
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PokeColors.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
                    color: PokeColors.cardWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: mon.isShiny
                          ? PokeColors.badgeGold
                          : typeAccent.withOpacity(0.65),
                      width: 1.6,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: PokemonSpriteImage.fromInstance(
                          mon,
                          width: 56,
                          height: 56,
                          fallbackIconSize: 36,
                          fallbackIconColor: typeAccent,
                        ),
                      ),
                      if (mon.isShiny)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: PokeColors.badgeGoldDark,
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
                              color: PokeColors.badgeGoldDark,
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
                                color: PokeColors.inkDark,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: PokeColors.badgeGold.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              "Lv.${mon.level}",
                              style: const TextStyle(
                                color: PokeColors.badgeGoldDark,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ...mon.species.types.map((t) => TypeBadge(type: t)),
                          if (heldItem != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: PokeColors.cardWhite,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: PokeColors.frameBorderSoft),
                              ),
                              child: Text(
                                "Held: ${heldItem.name}",
                                style: const TextStyle(
                                  color: PokeColors.inkMuted,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
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
                            color: PokeColors.badgeGold.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: PokeColors.badgeGoldDark),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 11,
                                color: PokeColors.badgeGoldDark,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "TRADE EVOLVES → ${tradeEvoName.toUpperCase()}",
                                style: const TextStyle(
                                  color: PokeColors.badgeGoldDark,
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
        backgroundColor: PokeColors.canvasCream,
        appBar: buildPokeAppBar(
          context: context,
          title: "FIST-BUMP LINK TRADE",
          barColor: PokeColors.linkTeal,
          bottomBorderColor: PokeColors.linkTealDark,
          onBack: _exitTradeRoom,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const PokeBackdrop(
              assetPath: 'assets/images/bg_bump_radar.png',
              topOpacity: 0.30,
              midOpacity: 0.56,
              bottomOpacity: 0.90,
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  children: [
                    // Connection Status Strip
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: PokeDecorations.card(
                        fill: PokeColors.cardWhite,
                        border: session.isPeerLeft
                            ? PokeColors.pokeRed
                            : PokeColors.linkTeal,
                        radius: 12,
                        borderWidth: 1.4,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            session.isPeerLeft
                                ? Icons.link_off_rounded
                                : Icons.link_rounded,
                            size: 16,
                            color: session.isPeerLeft
                                ? PokeColors.pokeRed
                                : PokeColors.linkTealDark,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              session.isPeerLeft
                                  ? "${session.partnerName} disconnected from Trade Room"
                                  : "Linked with ${session.partnerName} • Round #${session.round}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: session.isPeerLeft
                                    ? PokeColors.pokeRed
                                    : PokeColors.linkTealDark,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Partner Offer
                    _buildOfferCard(
                      ownerLabel: "${session.partnerName.toUpperCase()}'S OFFER",
                      accentColor: PokeColors.linkTealDark,
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
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: PokeDecorations.card(
                              fill: PokeColors.cardWhite,
                              border: active
                                  ? PokeColors.pokeGreen
                                  : PokeColors.frameBorderSoft,
                              radius: 20,
                              borderWidth: 1.3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.swap_vert_rounded,
                                  size: 18,
                                  color: active
                                      ? Color.lerp(
                                          PokeColors.linkTeal,
                                          PokeColors.pokeGreen,
                                          (0.5 + 0.5 * (pulse * 2 - 1).abs()),
                                        )
                                      : PokeColors.inkSubtle,
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
                                        ? PokeColors.pokeGreenDark
                                        : PokeColors.inkMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Your Offer
                    _buildOfferCard(
                      ownerLabel: "${trainer.name.toUpperCase()}'S OFFER",
                      accentColor: PokeColors.pokeBlue,
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
                          decoration: PokeDecorations.card(
                            fill: PokeColors.creamSurface,
                            border: PokeColors.pokeGreen,
                            radius: 18,
                            borderWidth: 2.0,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: PokeColors.pokeGreen,
                                size: 42,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "LINK TRADE COMPLETE!",
                                style: TextStyle(
                                  color: PokeColors.pokeGreenDark,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Sent $_lastSentName ↔ Received ${_lastReceivedMon!.species.name}!",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: PokeColors.inkDark,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _exitTradeRoom,
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor: PokeColors.cardWhite,
                                        foregroundColor: PokeColors.inkDark,
                                        side: const BorderSide(
                                          color: PokeColors.frameBorderSoft,
                                          width: 1.5,
                                        ),
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
                                        backgroundColor: PokeColors.linkTeal,
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
                          decoration: PokeDecorations.card(
                            fill: PokeColors.creamSurface.withOpacity(0.96),
                            border: PokeColors.frameBorderSoft,
                            radius: 16,
                            borderWidth: 1.5,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "YOUR POKÉMON PARTY",
                                style: TextStyle(
                                  color: PokeColors.inkMuted,
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
                                              ? const Color(0xFFFFF8E1)
                                              : PokeColors.cardWhite,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selected
                                                ? PokeColors.badgeGoldDark
                                                : (tradeEvo
                                                    ? PokeColors.linkTeal
                                                    : PokeColors
                                                        .frameBorderSoft),
                                            width: selected ? 2.0 : 1.3,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            PokemonSpriteImage.fromInstance(
                                              mon,
                                              width: 36,
                                              height: 36,
                                              fallbackIconSize: 24,
                                              fallbackIconColor:
                                                  PokeColors.inkMuted,
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
                                                          color: PokeColors
                                                              .badgeGoldDark,
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
                                                            color: PokeColors
                                                                .inkDark,
                                                            fontSize: 11.5,
                                                            fontWeight:
                                                                FontWeight.w900,
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
                                                          ? PokeColors
                                                              .linkTealDark
                                                          : PokeColors
                                                              .badgeGoldDark,
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w800,
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
                                      backgroundColor: PokeColors.cardWhite,
                                      foregroundColor: PokeColors.badgeGoldDark,
                                      side: const BorderSide(
                                        color: PokeColors.badgeGoldDark,
                                        width: 1.5,
                                      ),
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
                                  backgroundColor: PokeColors.linkTeal,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: session.myConfirmed
                                      ? PokeColors.pokeGreen.withOpacity(0.18)
                                      : PokeColors.panelSoft,
                                  disabledForegroundColor: session.myConfirmed
                                      ? PokeColors.pokeGreenDark
                                      : PokeColors.inkSubtle,
                                  elevation: 3,
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
                color: Colors.black.withOpacity(0.55),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: PokeDecorations.card(
                      fill: PokeColors.creamSurface,
                      border: PokeColors.linkTeal,
                      radius: 20,
                      borderWidth: 2,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 52,
                          height: 52,
                          child: CircularProgressIndicator(
                            strokeWidth: 4.5,
                            color: PokeColors.linkTeal,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Sending $_lastSentName...",
                          style: const TextStyle(
                            color: PokeColors.inkDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Fist-Bump Link Cable Transfer in progress!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: PokeColors.linkTealDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
