# ⚡ Pocket Bump
*A real-world Pokémon encounter and fist-bump battling app for Android.*

---

## 🎮 What is Pocket Bump?

Pocket Bump transforms real-world movement and physical social interactions into an authentic Pokémon journey:

1. **Pocket Encounters (Background Pokéwalker):**
   - Keep your phone in your pocket with the screen locked.
   - As you walk throughout your day, the app passively listens to your hardware step coprocessor.
   - Every ~350 steps, your phone gives a sharp **double-vibration** and sends a **lock-screen alert** with the classic Pokémon cry: *"A wild Pokémon appeared in the tall grass!"*
   - Tap the alert to jump directly into the wild battle and catch it!

2. **Fist-Bump Battling & Trading (Kinetic Matchmaking):**
   - Meet another trainer in real life.
   - Both players hold their phones and physically **bump fists**!
   - The accelerometer detects the sudden kinetic shock, pairs your session, and launches a live battle or trade screen.

3. **Classic Gen 4 Turn-Based Engine:**
   - 6 Stats (HP, Attack, Defense, Special Attack, Special Defense, Speed).
   - Physical / Special Move Split.
   - 18 Types & full elemental effectiveness matrix.
   - Authentic damage formulas, STAB bonuses, crits, and accuracy checks.
   - Future-proofed for Mega Evolutions and Terastallization.

---

## 📱 How to Download & Install the APK on Android

Thanks to **GitHub Actions**, you don't need to install Android Studio or Flutter on your computer to build the app. The cloud compiles it automatically on every push!

### 📥 Step-by-Step Installation:
1. Open this repository on your Android phone's browser.
2. Go to the **[Releases](../../releases)** tab (or the **Actions** tab).
3. Download the latest **`app-release.apk`**.
4. Tap the downloaded file to install.
   - *If prompted by Android:* Allow "Install from unknown sources" for your browser.
5. Launch **Pocket Bump**, choose your starter (*Bulbasaur, Charmander, or Squirtle*), and start your journey!

---

## 🛠️ Architecture & Tech Stack

- **Framework:** Flutter (Dart) targeting Android (API 24+)
- **Sensor Engine:**
  - `pedometer`: Hardware step-counter coprocessor listener (`Sensor.TYPE_STEP_COUNTER`) for 24/7 background tracking (<1% battery).
  - `sensors_plus`: High-frequency 3D accelerometer magnitude shock detection for the fist-bump.
  - `flutter_local_notifications`: Heads-up lock-screen wild encounter alerts.
- **CI/CD:** GitHub Actions workflow (`.github/workflows/build_apk.yml`) building release APKs on Ubuntu runners.
