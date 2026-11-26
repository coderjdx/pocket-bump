import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/pokemon_type.dart';
import '../models/trainer.dart';
import '../services/mystery_gift_service.dart';
import '../services/sound_service.dart';
import '../widgets/poke_theme.dart';
import '../widgets/pokemon_sprite_image.dart';
import '../widgets/type_badge.dart';

class MysteryGiftScreen extends StatefulWidget {
  const MysteryGiftScreen({super.key});

  @override
  State<MysteryGiftScreen> createState() => _MysteryGiftScreenState();
}

class _MysteryGiftScreenState extends State<MysteryGiftScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isCheckingEvents = false;
  bool _hasCheckedEvents = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkEventGifts(Trainer trainer) async {
    if (_isCheckingEvents) return;
    SoundService.instance.playBumpChime();
    setState(() => _isCheckingEvents = true);
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _isCheckingEvents = false;
      _hasCheckedEvents = true;
    });
    final pending = MysteryGiftService.unclaimedEvents(trainer);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pending.isEmpty
              ? "All currently available Event Gifts have already been claimed!"
              : "Found ${pending.length} active Event Gift${pending.length == 1 ? '' : 's'} ready to claim!",
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _redeemEnteredCode(Trainer trainer) {
    final result =
        MysteryGiftService.redeemCode(trainer, _codeController.text);
    _presentResult(result);
    if (result.success) {
      _codeController.clear();
    }
  }

  void _presentResult(GiftRedemptionResult result) {
    if (!result.success) {
      SoundService.instance.playUiError();
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: PokeColors.creamSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: PokeColors.pokeRed, width: 1.6),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: PokeColors.pokeRed),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.title,
                  style: const TextStyle(
                    color: PokeColors.inkDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            result.message,
            style: const TextStyle(color: PokeColors.inkMuted, fontSize: 13),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                SoundService.instance.playUiTap();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PokeColors.pokeRed,
                foregroundColor: Colors.white,
              ),
              child: const Text("OK",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final PokemonInstance? mon = result.grantedPokemon;
    if (mon != null) {
      SoundService.instance.playPokemonCry(mon.species.id);
    }
    SoundService.instance.playLevelUpSfx();
    HapticFeedback.heavyImpact();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PokeColors.creamSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: PokeColors.badgeGold, width: 1.8),
        ),
        title: Row(
          children: [
            const Icon(Icons.card_giftcard_rounded,
                color: PokeColors.badgeGoldDark, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.title,
                style: const TextStyle(
                  color: PokeColors.inkDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mon != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: PokeDecorations.card(
                  fill: PokeColors.cardWhite,
                  border: mon.species.types.first.color,
                  radius: 16,
                  borderWidth: 1.6,
                ),
                child: Column(
                  children: [
                    PokemonSpriteImage.fromInstance(
                      mon,
                      width: 96,
                      height: 96,
                      fallbackIconSize: 64,
                      fallbackIconColor: mon.species.types.first.color,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (mon.isShiny) ...[
                          const Icon(Icons.auto_awesome_rounded,
                              color: PokeColors.badgeGoldDark, size: 16),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          "${mon.species.name} • Lv.${mon.level}",
                          style: const TextStyle(
                            color: PokeColors.inkDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: mon.species.types
                          .map((t) => TypeBadge(type: t))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Ability: ${mon.abilityDefinition?.name ?? mon.abilityId}${mon.isHiddenAbility ? ' (Hidden Ability!)' : ''}",
                      style: TextStyle(
                        color: mon.isHiddenAbility
                            ? PokeColors.badgeGoldDark
                            : PokeColors.pokeBlueDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (result.grantedItems.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: PokeDecorations.card(
                  fill: PokeColors.cardWhite,
                  border: PokeColors.pokeBlue,
                  radius: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: result.grantedItems.entries.map((e) {
                    final item = ItemDatabase.byId(e.key);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Icon(item?.icon ?? Icons.inventory_2_rounded,
                              size: 16,
                              color: item?.color ?? PokeColors.pokeBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item?.name ?? e.key,
                              style: const TextStyle(
                                color: PokeColors.inkDark,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            "×${e.value}",
                            style: const TextStyle(
                              color: PokeColors.badgeGoldDark,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: PokeColors.inkMuted, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              SoundService.instance.playUiConfirm();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PokeColors.badgeGold,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("AWESOME!",
                style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainer = Provider.of<Trainer>(context);
    final int charCount =
        MysteryGiftService.normalizeCode(_codeController.text).length;
    final bool codeReady = charCount == 16;

    return Scaffold(
      backgroundColor: PokeColors.canvasCream,
      appBar: buildPokeAppBar(
        context: context,
        title: "MYSTERY GIFT",
        barColor: PokeColors.giftCrimson,
        bottomBorderColor: PokeColors.giftCrimsonDark,
        titleLeading: const Icon(Icons.card_giftcard_rounded,
            color: Color(0xFFFFE082), size: 20),
        onBack: () {
          SoundService.instance.playUiCancel();
          Navigator.pop(context);
        },
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Check for Event Items / Distributions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: PokeDecorations.card(
                fill: PokeColors.cardWhite,
                border: PokeColors.pokeBlue,
                radius: 18,
                borderWidth: 1.6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.wifi_tethering_rounded,
                          color: PokeColors.pokeBlue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "EVENT DISTRIBUTIONS",
                          style: TextStyle(
                            color: PokeColors.inkDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Scan for official Pocket Bump event items and seasonal distributions.",
                    style: TextStyle(color: PokeColors.inkMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isCheckingEvents
                          ? null
                          : () => _checkEventGifts(trainer),
                      icon: _isCheckingEvents
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search_rounded, size: 18),
                      label: Text(
                        _isCheckingEvents
                            ? "CHECKING FOR GIFTS..."
                            : "CHECK FOR EVENT GIFTS",
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.pokeBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (_hasCheckedEvents) ...[
                    const SizedBox(height: 14),
                    ...MysteryGiftService.activeEventDistributions.map((event) {
                      final bool claimed =
                          trainer.hasClaimedEventGift(event.id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: PokeDecorations.card(
                          fill: PokeColors.creamSurface,
                          border: claimed
                              ? PokeColors.frameBorderSoft
                              : PokeColors.badgeGold,
                          radius: 14,
                          borderWidth: 1.4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.badgeLabel,
                                    style: TextStyle(
                                      color: claimed
                                          ? PokeColors.inkSubtle
                                          : PokeColors.badgeGoldDark,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event.title,
                                    style: TextStyle(
                                      color: claimed
                                          ? PokeColors.inkMuted
                                          : PokeColors.inkDark,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event.subtitle,
                                    style: const TextStyle(
                                      color: PokeColors.inkMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: claimed
                                  ? null
                                  : () {
                                      final res =
                                          MysteryGiftService.claimEventGift(
                                              trainer, event);
                                      _presentResult(res);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PokeColors.badgeGold,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: PokeColors.panelSoft,
                                disabledForegroundColor: PokeColors.inkSubtle,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                              child: Text(
                                claimed ? "CLAIMED" : "RECEIVE",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Receive via 16-Character Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: PokeDecorations.card(
                fill: PokeColors.cardWhite,
                border: PokeColors.giftCrimson,
                radius: 18,
                borderWidth: 1.6,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.confirmation_number_rounded,
                          color: PokeColors.giftCrimson, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "GET WITH CODE / PASSWORD",
                        style: TextStyle(
                          color: PokeColors.inkDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Enter a 16-character alphanumeric event code (letters A–Z and numbers 0–9). Each code can only be used once.",
                    style: TextStyle(color: PokeColors.inkMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 19,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: PokeColors.inkDark,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: "ENTER 16-CHAR CODE",
                      hintStyle: const TextStyle(
                        color: PokeColors.inkSubtle,
                        letterSpacing: 1.8,
                      ),
                      counterText: "",
                      filled: true,
                      fillColor: PokeColors.creamSurface,
                      suffixText: "$charCount/16",
                      suffixStyle: TextStyle(
                        color: codeReady
                            ? PokeColors.pokeGreenDark
                            : PokeColors.inkMuted,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: PokeColors.frameBorderSoft, width: 1.4),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: PokeColors.giftCrimson, width: 1.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: codeReady
                          ? () => _redeemEnteredCode(trainer)
                          : null,
                      icon: const Icon(Icons.redeem_rounded, size: 18),
                      label: const Text(
                        "REDEEM GIFT CODE",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PokeColors.giftCrimson,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: PokeColors.panelSoft,
                        disabledForegroundColor: PokeColors.inkSubtle,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. External Distribution Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: PokeDecorations.card(
                fill: PokeColors.creamSurface,
                border: PokeColors.frameBorderSoft,
                radius: 16,
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: PokeColors.inkMuted, size: 18),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      "Event items and 16-character Mystery Gift codes are announced through external channels and are not listed in-app.",
                      style: TextStyle(
                          color: PokeColors.inkMuted,
                          fontSize: 11.5,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
