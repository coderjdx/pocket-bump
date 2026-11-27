import 'package:flutter/material.dart';
import 'game_region.dart';

enum GameVersion {
  red,
  blueGreen,
  gold,
  silver,
}

extension GameVersionExtension on GameVersion {
  GameRegion get region {
    switch (this) {
      case GameVersion.red:
      case GameVersion.blueGreen:
        return GameRegion.kanto;
      case GameVersion.gold:
      case GameVersion.silver:
        return GameRegion.johto;
    }
  }

  static List<GameVersion> forRegion(GameRegion region) {
    switch (region) {
      case GameRegion.kanto:
        return const [GameVersion.red, GameVersion.blueGreen];
      case GameRegion.johto:
        return const [GameVersion.gold, GameVersion.silver];
    }
  }

  String get storageKey {
    switch (this) {
      case GameVersion.red:
        return 'red';
      case GameVersion.blueGreen:
        return 'blue_green';
      case GameVersion.gold:
        return 'gold';
      case GameVersion.silver:
        return 'silver';
    }
  }

  String get displayName {
    switch (this) {
      case GameVersion.red:
        return 'Red Version';
      case GameVersion.blueGreen:
        return 'Blue Version';
      case GameVersion.gold:
        return 'Gold Version';
      case GameVersion.silver:
        return 'Silver Version';
    }
  }

  String get shortLabel {
    switch (this) {
      case GameVersion.red:
        return 'RED';
      case GameVersion.blueGreen:
        return 'BLUE';
      case GameVersion.gold:
        return 'GOLD';
      case GameVersion.silver:
        return 'SILVER';
    }
  }

  String get elementTag {
    switch (this) {
      case GameVersion.red:
        return 'FIRE';
      case GameVersion.blueGreen:
        return 'WATER';
      case GameVersion.gold:
        return 'SUNLIT SKY';
      case GameVersion.silver:
        return 'DEEP TIDE';
    }
  }

  Color get primaryColor {
    switch (this) {
      case GameVersion.red:
        return const Color(0xFFE53935);
      case GameVersion.blueGreen:
        return const Color(0xFF1E88E5);
      case GameVersion.gold:
        return const Color(0xFFD99B00);
      case GameVersion.silver:
        return const Color(0xFF546E7A);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case GameVersion.red:
        return const Color(0xFFFF7043);
      case GameVersion.blueGreen:
        return const Color(0xFF26A69A);
      case GameVersion.gold:
        return const Color(0xFFFFCA28);
      case GameVersion.silver:
        return const Color(0xFF78909C);
    }
  }

  int get mascotSpeciesId {
    switch (this) {
      case GameVersion.red:
        return 6; // Charizard
      case GameVersion.blueGreen:
        return 9; // Blastoise
      case GameVersion.gold:
        return 250; // Ho-Oh
      case GameVersion.silver:
        return 249; // Lugia
    }
  }

  List<int> get sampleExclusiveIds {
    switch (this) {
      case GameVersion.red:
        return const [23, 43, 56, 58, 123, 125];
      case GameVersion.blueGreen:
        return const [27, 37, 52, 69, 126, 127];
      case GameVersion.gold:
        return const [167, 207, 216, 226, 250];
      case GameVersion.silver:
        return const [165, 225, 227, 231, 249];
    }
  }

  String get exclusivesSummary {
    switch (this) {
      case GameVersion.red:
        return 'Ekans, Oddish, Mankey, Growlithe, Scyther, Electabuzz';
      case GameVersion.blueGreen:
        return 'Sandshrew, Vulpix, Meowth, Bellsprout, Magmar, Pinsir';
      case GameVersion.gold:
        return 'Spinarak, Gligar, Teddiursa, Mantine, Ho-Oh';
      case GameVersion.silver:
        return 'Ledyba, Delibird, Skarmory, Phanpy, Lugia';
    }
  }

  static GameVersion? fromStorageKey(String? raw) {
    if (raw == 'red') return GameVersion.red;
    if (raw == 'blue_green') return GameVersion.blueGreen;
    if (raw == 'gold') return GameVersion.gold;
    if (raw == 'silver') return GameVersion.silver;
    return null;
  }
}
