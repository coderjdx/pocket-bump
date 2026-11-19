import '../models/game_version.dart';
import '../models/item.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import 'pokedex_database.dart';

class EventGiftDefinition {
  final String id;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Map<String, int> items;
  final int? pokemonSpeciesId;
  final int pokemonLevel;

  const EventGiftDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    this.items = const {},
    this.pokemonSpeciesId,
    this.pokemonLevel = 5,
  });
}

class GiftRedemptionResult {
  final bool success;
  final String title;
  final String message;
  final PokemonInstance? grantedPokemon;
  final Map<String, int> grantedItems;
  final int? boxNumber;

  const GiftRedemptionResult({
    required this.success,
    required this.title,
    required this.message,
    this.grantedPokemon,
    this.grantedItems = const {},
    this.boxNumber,
  });
}

class MysteryGiftService {
  /// 16-character alphanumeric event code granting Lv.5 Chimchar (Red) or Piplup (Blue/Green).
  static const String sinnohStarterCode = 'SINNOH2026GIFT04';

  static const List<EventGiftDefinition> activeEventDistributions = [
    EventGiftDefinition(
      id: 'event_kanto_supply_pack',
      title: 'Kanto Explorer Supply Pack',
      subtitle: '5× Ultra Ball, 5× Hyper Potion & 3× Sitrus Berry',
      badgeLabel: 'ACTIVE EVENT',
      items: {
        'ultra_ball': 5,
        'hyper_potion': 5,
        'sitrus_berry': 3,
      },
    ),
    EventGiftDefinition(
      id: 'event_evolution_festival',
      title: 'Evolution Stone Celebration',
      subtitle: '1× Fire, Water, Thunder & Leaf Stone',
      badgeLabel: 'SPECIAL DISTRIBUTION',
      items: {
        'fire_stone': 1,
        'water_stone': 1,
        'thunder_stone': 1,
        'leaf_stone': 1,
      },
    ),
  ];

  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValidSixteenCharCode(String raw) {
    final norm = normalizeCode(raw);
    return RegExp(r'^[A-Z0-9]{16}$').hasMatch(norm);
  }

  static List<EventGiftDefinition> unclaimedEvents(Trainer trainer) =>
      activeEventDistributions
          .where((e) => !trainer.hasClaimedEventGift(e.id))
          .toList();

  static GiftRedemptionResult claimEventGift(
    Trainer trainer,
    EventGiftDefinition event,
  ) {
    if (trainer.hasClaimedEventGift(event.id)) {
      return const GiftRedemptionResult(
        success: false,
        title: 'Already Claimed',
        message: 'You have already received this Mystery Gift event.',
      );
    }

    PokemonInstance? grantedMon;
    int? boxNum;
    if (event.pokemonSpeciesId != null) {
      if (trainer.isStorageFull) {
        return const GiftRedemptionResult(
          success: false,
          title: 'Storage Full',
          message:
              'Your Party and PC Boxes are full (320/320). Free up a slot first!',
        );
      }
      final spec = PokedexDatabase.species[event.pokemonSpeciesId!]!;
      grantedMon = PokedexDatabase.createPokemon(
        event.pokemonSpeciesId!,
        level: event.pokemonLevel,
        respectMinEncounterLevel: false,
        isShiny: PokedexDatabase.rollShiny(spec),
        hiddenAbilityChance: 0.05,
      );
      boxNum = trainer.addPokemon(grantedMon);
    }

    for (final entry in event.items.entries) {
      if (ItemDatabase.byId(entry.key) != null) {
        trainer.adjustItemCount(entry.key, entry.value);
      }
    }

    trainer.markEventGiftClaimed(event.id);
    trainer.saveProgress();

    return GiftRedemptionResult(
      success: true,
      title: event.title,
      message: event.subtitle,
      grantedPokemon: grantedMon,
      grantedItems: event.items,
      boxNumber: boxNum,
    );
  }

  static GiftRedemptionResult redeemCode(Trainer trainer, String rawCode) {
    final normalized = normalizeCode(rawCode);
    if (!RegExp(r'^[A-Z0-9]{16}$').hasMatch(normalized)) {
      return const GiftRedemptionResult(
        success: false,
        title: 'Invalid Gift Code',
        message:
            'Gift codes must be exactly 16 alphanumeric characters (A–Z, 0–9).',
      );
    }

    if (trainer.hasRedeemedGiftCode(normalized)) {
      return const GiftRedemptionResult(
        success: false,
        title: 'Code Already Used',
        message: 'This Mystery Gift code can only be redeemed once per player.',
      );
    }

    if (normalized == sinnohStarterCode) {
      final version = trainer.gameVersion;
      if (version == null) {
        return const GiftRedemptionResult(
          success: false,
          title: 'Choose Game Version First',
          message:
              'Select Red Version or Blue/Green Version first to claim your version starter gift!',
        );
      }

      if (trainer.isStorageFull) {
        return const GiftRedemptionResult(
          success: false,
          title: 'Storage Full',
          message:
              'Your Party and PC Boxes are full (320/320). Release a Pokémon first!',
        );
      }

      final int speciesId = version == GameVersion.red ? 390 : 393; // Chimchar or Piplup
      final spec = PokedexDatabase.species[speciesId]!;
      final giftedMon = PokedexDatabase.createPokemon(
        speciesId,
        level: 5,
        respectMinEncounterLevel: false,
        isShiny: PokedexDatabase.rollShiny(spec),
        hiddenAbilityChance: 0.05,
      );
      final int? boxNum = trainer.addPokemon(giftedMon);
      trainer.markGiftCodeRedeemed(normalized);
      trainer.saveProgress();

      final String destNote = (boxNum != null && boxNum > 0)
          ? 'Transferred to PC Box #$boxNum!'
          : 'Added directly to your Party!';

      return GiftRedemptionResult(
        success: true,
        title: 'Mystery Gift Received!',
        message:
            '${version.shortLabel} Gift: Received Lv. 5 ${spec.name}! $destNote',
        grantedPokemon: giftedMon,
        boxNumber: boxNum,
      );
    }

    return const GiftRedemptionResult(
      success: false,
      title: 'Code Not Recognized',
      message:
          'No active Mystery Gift matched "$rawCode". Check the code and try again.',
    );
  }
}
