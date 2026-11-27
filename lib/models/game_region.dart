import 'package:flutter/material.dart';

enum GameRegion {
  kanto,
  johto,
}

extension GameRegionExtension on GameRegion {
  String get storageKey {
    switch (this) {
      case GameRegion.kanto:
        return 'kanto';
      case GameRegion.johto:
        return 'johto';
    }
  }

  String get displayName {
    switch (this) {
      case GameRegion.kanto:
        return 'Kanto';
      case GameRegion.johto:
        return 'Johto';
    }
  }

  Color get accentColor {
    switch (this) {
      case GameRegion.kanto:
        return const Color(0xFFE53935);
      case GameRegion.johto:
        return const Color(0xFFFFB300);
    }
  }

  List<int> get starterIds {
    switch (this) {
      case GameRegion.kanto:
        return const [1, 4, 7];
      case GameRegion.johto:
        return const [152, 155, 158];
    }
  }

  GameRegion? get nextRegion {
    switch (this) {
      case GameRegion.kanto:
        return GameRegion.johto;
      case GameRegion.johto:
        return null;
    }
  }

  bool get hasFossilLab => this == GameRegion.kanto;

  static GameRegion fromStorageKey(String? raw) {
    for (final region in GameRegion.values) {
      if (region.storageKey == raw) return region;
    }
    return GameRegion.kanto;
  }
}
