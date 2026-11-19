import 'package:flutter/material.dart';
import '../services/sound_service.dart';

class SoundToggleButton extends StatelessWidget {
  final Color iconColor;
  final double size;

  const SoundToggleButton({
    super.key,
    this.iconColor = Colors.white,
    this.size = 18,
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
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: sound.isMuted
                    ? Colors.redAccent.withOpacity(0.55)
                    : Colors.cyanAccent.withOpacity(0.4),
              ),
            ),
            child: Icon(
              sound.isMuted
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
              size: size,
              color: sound.isMuted ? Colors.redAccent : iconColor,
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
    backgroundColor: const Color(0xFF141828),
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
                        color: Colors.cyanAccent, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "SOUND & BGM SETTINGS",
                        style: TextStyle(
                          color: Colors.white,
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
                        color: s.isMuted ? Colors.redAccent : Colors.greenAccent,
                      ),
                      label: Text(
                        s.isMuted ? "MUTED" : "ACTIVE",
                        style: TextStyle(
                          color:
                              s.isMuted ? Colors.redAccent : Colors.greenAccent,
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
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: s.bgmVolume,
                        activeColor: Colors.cyanAccent,
                        onChanged: s.isMuted ? null : (v) => s.setBgmVolume(v),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        s.bgmToggle
                            ? Icons.music_off_rounded
                            : Icons.music_note_rounded,
                        color: s.bgmToggle ? Colors.white38 : Colors.cyanAccent,
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
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: s.sfxVolume,
                        activeColor: const Color(0xFFFFD54F),
                        onChanged: s.isMuted ? null : (v) => s.setSfxVolume(v),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        s.sfxToggle
                            ? Icons.notifications_off_rounded
                            : Icons.notifications_active_rounded,
                        color: s.sfxToggle
                            ? Colors.white38
                            : const Color(0xFFFFD54F),
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
