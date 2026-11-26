import 'package:flutter/material.dart';
import '../services/sound_service.dart';
import 'poke_theme.dart';

class SoundToggleButton extends StatelessWidget {
  final Color iconColor;
  final double size;
  final Color? bgColor;
  final Color? borderColor;

  const SoundToggleButton({
    super.key,
    this.iconColor = PokeColors.inkDark,
    this.size = 18,
    this.bgColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SoundService.instance,
      builder: (context, _) {
        final sound = SoundService.instance;
        return InkWell(
          onTap: () => sound.toggleAllMute(),
          onLongPress: () => showSoundSettingsSheet(context),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor ?? PokeColors.cardWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor ??
                    (sound.isMuted
                        ? PokeColors.pokeRed
                        : PokeColors.frameBorderSoft),
                width: 1.3,
              ),
            ),
            child: Icon(
              sound.isMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              size: size,
              color: sound.isMuted ? PokeColors.pokeRed : iconColor,
            ),
          ),
        );
      },
    );
  }
}

void showSoundSettingsSheet(BuildContext context) {
  SoundService.instance.playUiTap();
  showModalBottomSheet(
    context: context,
    backgroundColor: PokeColors.creamSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => ListenableBuilder(
      listenable: SoundService.instance,
      builder: (context, _) {
        final s = SoundService.instance;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded,
                        color: PokeColors.pokeBlue, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "SOUND & BGM SETTINGS",
                        style: TextStyle(
                          color: PokeColors.inkDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        s.playUiTap();
                        s.toggleAllMute();
                      },
                      icon: Icon(
                        s.isMuted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        size: 16,
                        color: s.isMuted
                            ? PokeColors.pokeRed
                            : PokeColors.pokeGreen,
                      ),
                      label: Text(
                        s.isMuted ? "MUTED" : "ACTIVE",
                        style: TextStyle(
                          color: s.isMuted
                              ? PokeColors.pokeRed
                              : PokeColors.pokeGreen,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 92,
                      child: Text(
                        "Music (BGM)",
                        style: TextStyle(
                          color: PokeColors.inkMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: s.bgmVolume,
                        activeColor: PokeColors.pokeBlue,
                        inactiveColor: PokeColors.frameBorderSoft,
                        onChanged: s.isMuted ? null : (v) => s.setBgmVolume(v),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        s.bgmToggle
                            ? Icons.music_off_rounded
                            : Icons.music_note_rounded,
                        color: s.bgmToggle
                            ? PokeColors.inkSubtle
                            : PokeColors.pokeBlue,
                        size: 18,
                      ),
                      onPressed: () => s.setBgmMuted(!s.bgmToggle),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(
                      width: 92,
                      child: Text(
                        "SFX & Cries",
                        style: TextStyle(
                          color: PokeColors.inkMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: s.sfxVolume,
                        activeColor: PokeColors.pokeRed,
                        inactiveColor: PokeColors.frameBorderSoft,
                        onChanged: s.isMuted ? null : (v) => s.setSfxVolume(v),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        s.sfxToggle
                            ? Icons.notifications_off_rounded
                            : Icons.notifications_active_rounded,
                        color: s.sfxToggle
                            ? PokeColors.inkSubtle
                            : PokeColors.pokeRed,
                        size: 18,
                      ),
                      onPressed: () {
                        s.setSfxMuted(!s.sfxToggle);
                        if (s.sfxToggle) s.playUiTap();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
