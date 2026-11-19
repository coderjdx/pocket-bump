import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game_version.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import '../services/mystery_gift_service.dart';
import '../services/sound_service.dart';
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
          backgroundColor: const Color(0xFF15192B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            result.message,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                SoundService.instance.playUiTap();
                Navigator.pop(ctx);
              },
              child: const Text("OK",
                  style: TextStyle(
                      color: Colors.amberAccent, fontWeight: FontWeight.bold)),
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
        backgroundColor: const Color(0xFF13182A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
              color: const Color(0xFFFFD54F).withOpacity(0.65), width: 1.4),
        ),
        title: Row(
          children: [
            const Icon(Icons.card_giftcard_rounded,
                color: Color(0xFFFFD54F), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                result.title,
                style: const TextStyle(
                  color: Color(0xFFFFE082),
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
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1020),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: mon.species.types.first.color.withOpacity(0.55)),
                ),
                child: Column(
                  children: [
                    Image.network(
                      mon.spriteUrl,
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.none,
                      errorBuilder: (_, __, ___) => Image.network(
                        mon.staticSpriteUrl,
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.none,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.catching_pokemon,
                          size: 64,
                          color: mon.species.types.first.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (mon.isShiny) ...[
                          const Icon(Icons.auto_awesome_rounded,
                              color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          "${mon.species.name} • Lv.${mon.level}",
                          style: const TextStyle(
                            color: Colors.white,
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
                            ? const Color(0xFFFFD54F)
                            : Colors.cyanAccent,
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
                decoration: BoxDecoration(
                  color: const Color(0xFF0C101E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
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
                              color: item?.color ?? Colors.cyanAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item?.name ?? e.key,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            "×${e.value}",
                            style: const TextStyle(
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 13),
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
                  color: Colors.white70, fontSize: 12.5, height: 1.4),
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
              backgroundColor: const Color(0xFFFFD54F),
              foregroundColor: Colors.black87,
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
    final version = trainer.gameVersion;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1322),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 18),
          onPressed: () {
            SoundService.instance.playUiCancel();
            Navigator.pop(context);
          },
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard_rounded,
                color: Color(0xFFFFD54F), size: 20),
            SizedBox(width: 8),
            Text(
              "MYSTERY GIFT",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Check for Event Items / Distributions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF17223B), Color(0xFF111629)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wifi_tethering_rounded,
                          color: Colors.cyanAccent, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "EVENT DISTRIBUTIONS",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      if (MysteryGiftService.unclaimedEvents(trainer)
                          .isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.greenAccent.withOpacity(0.6)),
                          ),
                          child: Text(
                            "${MysteryGiftService.unclaimedEvents(trainer).length} AVAILABLE",
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Scan for official Pocket Bump event items and seasonal distributions.",
                    style: TextStyle(color: Colors.white60, fontSize: 12),
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
                                color: Colors.black87,
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
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (_hasCheckedEvents ||
                      MysteryGiftService.activeEventDistributions
                          .any((e) => trainer.hasClaimedEventGift(e.id))) ...[
                    const SizedBox(height: 14),
                    ...MysteryGiftService.activeEventDistributions.map((event) {
                      final bool claimed =
                          trainer.hasClaimedEventGift(event.id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C1020),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: claimed
                                ? Colors.white12
                                : const Color(0xFFFFD54F).withOpacity(0.5),
                          ),
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
                                          ? Colors.white38
                                          : const Color(0xFFFFD54F),
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
                                          ? Colors.white54
                                          : Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event.subtitle,
                                    style: const TextStyle(
                                      color: Colors.white60,
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
                                backgroundColor: const Color(0xFFFFD54F),
                                foregroundColor: Colors.black87,
                                disabledBackgroundColor: Colors.white10,
                                disabledForegroundColor: Colors.white38,
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
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF241A2E), Color(0xFF131728)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: const Color(0xFFFFD54F).withOpacity(0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.confirmation_number_rounded,
                          color: Color(0xFFFFD54F), size: 20),
                      SizedBox(width: 8),
                      Text(
                        "GET WITH CODE / PASSWORD",
                        style: TextStyle(
                          color: Colors.white,
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
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 19,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: "SINNOH2026GIFT04",
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        letterSpacing: 1.8,
                      ),
                      counterText: "",
                      filled: true,
                      fillColor: const Color(0xFF0A0D18),
                      suffixText: "$charCount/16",
                      suffixStyle: TextStyle(
                        color: codeReady ? Colors.greenAccent : Colors.white54,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFFFFD54F), width: 1.6),
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
                        backgroundColor: const Color(0xFFFFD54F),
                        foregroundColor: Colors.black87,
                        disabledBackgroundColor: Colors.white10,
                        disabledForegroundColor: Colors.white38,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Featured Event Code Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF101526),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (version?.primaryColor ?? Colors.amberAccent)
                      .withOpacity(0.45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.campaign_rounded,
                          color: Colors.amberAccent, size: 18),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          "ACTIVE SINNOH STARTER CODE",
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                      if (trainer.hasRedeemedGiftCode(
                          MysteryGiftService.sinnohStarterCode))
                        const Text(
                          "REDEEMED ✓",
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Red Version players receive a Lv. 5 Chimchar • Blue/Green Version players receive a Lv. 5 Piplup.",
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11.5, height: 1.35),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      SoundService.instance.playUiTap();
                      _codeController.text =
                          MysteryGiftService.sinnohStarterCode;
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090C16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            MysteryGiftService.sinnohStarterCode,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            "TAP TO FILL",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
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
