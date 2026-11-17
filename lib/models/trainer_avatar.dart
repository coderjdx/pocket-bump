import 'package:flutter/material.dart';

enum TrainerHairStyle {
  spikyShort,
  longStraight,
  twinPonytails,
  twinPigtails,
}

enum TrainerHatStyle {
  classicCap,
  backwardCap,
  sunHat,
  beret,
  explorerHat,
}

class TrainerAvatar {
  final String id;
  final String title;
  final bool isFemale;
  final Color hatPrimary;
  final Color hatAccent;
  final Color hairColor;
  final Color outfitPrimary;
  final Color outfitSecondary;
  final Color bottomColor;
  final Color bagColor;
  final TrainerHairStyle hairStyle;
  final TrainerHatStyle hatStyle;

  const TrainerAvatar({
    required this.id,
    required this.title,
    required this.isFemale,
    required this.hatPrimary,
    required this.hatAccent,
    required this.hairColor,
    required this.outfitPrimary,
    required this.outfitSecondary,
    required this.bottomColor,
    required this.bagColor,
    required this.hairStyle,
    required this.hatStyle,
  });

  static const List<TrainerAvatar> presets = [
    // 3 Male Trainers
    TrainerAvatar(
      id: 'male_red',
      title: 'Ace Red',
      isFemale: false,
      hatPrimary: Color(0xFFD32F2F),
      hatAccent: Color(0xFFFFFFFF),
      hairColor: Color(0xFF1E1E24),
      outfitPrimary: Color(0xFFE53935),
      outfitSecondary: Color(0xFFFFFFFF),
      bottomColor: Color(0xFF28559A),
      bagColor: Color(0xFF8D6E63),
      hairStyle: TrainerHairStyle.spikyShort,
      hatStyle: TrainerHatStyle.classicCap,
    ),
    TrainerAvatar(
      id: 'male_blue',
      title: 'Vanguard Blue',
      isFemale: false,
      hatPrimary: Color(0xFF1565C0),
      hatAccent: Color(0xFF90CAF9),
      hairColor: Color(0xFF5D4037),
      outfitPrimary: Color(0xFF1E88E5),
      outfitSecondary: Color(0xFFECEFF1),
      bottomColor: Color(0xFF37474F),
      bagColor: Color(0xFF263238),
      hairStyle: TrainerHairStyle.spikyShort,
      hatStyle: TrainerHatStyle.classicCap,
    ),
    TrainerAvatar(
      id: 'male_gold',
      title: 'Ranger Gold',
      isFemale: false,
      hatPrimary: Color(0xFF212121),
      hatAccent: Color(0xFFFFB300),
      hairColor: Color(0xFF1C1C1C),
      outfitPrimary: Color(0xFF2E7D32),
      outfitSecondary: Color(0xFFFFF8E1),
      bottomColor: Color(0xFF8D7B52),
      bagColor: Color(0xFF556B2F),
      hairStyle: TrainerHairStyle.spikyShort,
      hatStyle: TrainerHatStyle.backwardCap,
    ),

    // 3 Female Trainers
    TrainerAvatar(
      id: 'female_leaf',
      title: 'Ace Leaf',
      isFemale: true,
      hatPrimary: Color(0xFFFAFAFA),
      hatAccent: Color(0xFFE53935),
      hairColor: Color(0xFF6D4C41),
      outfitPrimary: Color(0xFF00ACC1),
      outfitSecondary: Color(0xFFFFFFFF),
      bottomColor: Color(0xFF1E3A5F),
      bagColor: Color(0xFFD32F2F),
      hairStyle: TrainerHairStyle.longStraight,
      hatStyle: TrainerHatStyle.sunHat,
    ),
    TrainerAvatar(
      id: 'female_marina',
      title: 'Star Marina',
      isFemale: true,
      hatPrimary: Color(0xFF29B6F6),
      hatAccent: Color(0xFFFFD54F),
      hairColor: Color(0xFF00838F),
      outfitPrimary: Color(0xFFC62828),
      outfitSecondary: Color(0xFFFFFFFF),
      bottomColor: Color(0xFF263238),
      bagColor: Color(0xFFECEFF1),
      hairStyle: TrainerHairStyle.twinPonytails,
      hatStyle: TrainerHatStyle.beret,
    ),
    TrainerAvatar(
      id: 'female_lyra',
      title: 'Scout Lyra',
      isFemale: true,
      hatPrimary: Color(0xFFFFF3E0),
      hatAccent: Color(0xFFEF5350),
      hairColor: Color(0xFF5D4037),
      outfitPrimary: Color(0xFFEC407A),
      outfitSecondary: Color(0xFFFFFFFF),
      bottomColor: Color(0xFF3949AB),
      bagColor: Color(0xFFA1887F),
      hairStyle: TrainerHairStyle.twinPigtails,
      hatStyle: TrainerHatStyle.explorerHat,
    ),
  ];

  static List<TrainerAvatar> byGender({required bool isFemale}) {
    return presets.where((a) => a.isFemale == isFemale).toList();
  }
}
