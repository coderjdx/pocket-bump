import 'package:flutter/material.dart';

enum GameVersion {
  red,
  blueGreen,
}

extension GameVersionExtension on GameVersion {
  String get storageKey {
    switch (this) {
      case GameVersion.red:
        return 'red';
      case GameVersion.blueGreen:
        return 'blue_green';
    }
  }

  String get displayName {
    switch (this) {
      case GameVersion.red:
        return 'Red Version';
      case GameVersion.blueGreen:
        return 'Blue / Green Version';
    }
  }

  String get shortLabel {
    switch (this) {
      case GameVersion.red:
        return 'RED';
      case GameVersion.blueGreen:
        return 'BLUE / GREEN';
    }
  }

  Color get primaryColor {
    switch (this) {
      case GameVersion.red:
        return const Color(0xFFE53935);
      case GameVersion.blueGreen:
        return const Color(0xFF1E88E5);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case GameVersion.red:
        return const Color(0xFFFF7043);
      case GameVersion.blueGreen:
        return const Color(0xFF26A69A);
    }
  }

  int get mascotSpeciesId {
    switch (this) {
      case GameVersion.red:
        return 6; // Charizard
      case GameVersion.blueGreen:
        return 9; // Blastoise
    }
  }

  List<int> get sampleExclusiveIds {
    switch (this) {
      case GameVersion.red:
        return const [23, 43, 56, 58, 123, 125];
      case GameVersion.blueGreen:
        return const [27, 37, 52, 69, 126, 127];
    }
  }

  String get exclusivesSummary {
    switch (this) {
      case GameVersion.red:
        return 'Ekans, Oddish, Mankey, Growlithe, Scyther, Electabuzz';
      case GameVersion.blueGreen:
        return 'Sandshrew, Vulpix, Meowth, Bellsprout, Magmar, Pinsir';
    }
  }

  static GameVersion? fromStorageKey(String? raw) {
    if (raw == 'red') return GameVersion.red;
    if (raw == 'blue_green') return GameVersion.blueGreen;
    return null;
  }
}
