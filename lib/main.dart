import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/trainer.dart';
import 'screens/starter_select_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final savedTrainer = await Trainer.loadOrCreate();
  runApp(PocketBumpApp(initialTrainer: savedTrainer));
}

class PocketBumpApp extends StatefulWidget {
  final Trainer initialTrainer;

  const PocketBumpApp({super.key, required this.initialTrainer});

  @override
  State<PocketBumpApp> createState() => _PocketBumpAppState();
}

class _PocketBumpAppState extends State<PocketBumpApp> {
  bool _didPrecache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      _didPrecache = true;
      _prewarmAssets();
    }
  }

  void _prewarmAssets() {
    const assetPaths = [
      'assets/images/battle_bg_route.png',
      'assets/images/battle_bg_cave.png',
      'assets/images/battle_bg_beach.png',
      'assets/images/battle_bg_forest.png',
      'assets/images/battle_bg_volcano.png',
      'assets/images/battle_bg_urban.png',
      'assets/images/battle_bg_pvp_arena.png',
      'assets/images/battle_bg_gym_rock.png',
      'assets/images/battle_bg_gym_water.png',
      'assets/images/battle_bg_gym_electric.png',
      'assets/images/battle_bg_gym_grass.png',
      'assets/images/battle_bg_gym_poison.png',
      'assets/images/battle_bg_gym_psychic.png',
      'assets/images/battle_bg_gym_fire.png',
      'assets/images/battle_bg_gym_ground.png',
      'assets/images/home_bg.png',
      'assets/images/bg_pokemon_center.png',
      'assets/images/bg_poke_mart.png',
      'assets/images/bg_pokemon_lab.png',
      'assets/images/bg_pokemon_league.png',
      'assets/images/bg_pokedex.png',
      'assets/images/bg_pc_storage.png',
      'assets/images/bg_bump_radar.png',
      'assets/images/bg_starter_select.png',
      'assets/images/badges/boulder_badge.png',
      'assets/images/badges/cascade_badge.png',
      'assets/images/badges/thunder_badge.png',
      'assets/images/badges/rainbow_badge.png',
      'assets/images/badges/soul_badge.png',
      'assets/images/badges/marsh_badge.png',
      'assets/images/badges/volcano_badge.png',
      'assets/images/badges/earth_badge.png',
    ];
    for (final path in assetPaths) {
      precacheImage(AssetImage(path), context).catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<Trainer>.value(
      value: widget.initialTrainer,
      child: Consumer<Trainer>(
        builder: (context, trainer, child) {
          return MaterialApp(
            title: 'Pocket Bump',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF1E1E24),
              primaryColor: Colors.red.shade700,
              textTheme: ThemeData.dark().textTheme.copyWith(
                bodyMedium: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              colorScheme: ColorScheme.dark(
                primary: Colors.red.shade700,
                secondary: Colors.amberAccent,
                surface: const Color(0xFF2A2A35),
              ),
            ),
            home: trainer.party.isEmpty
                ? const StarterSelectScreen()
                : const HomeScreen(),
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();
              final mediaQuery = MediaQuery.of(context);
              final screenWidth = mediaQuery.size.width;
              final screenHeight = mediaQuery.size.height;

              // On mobile phones (portrait), adjust to phone's resolution directly
              if (screenWidth <= 500) return child;

              // On wide screens (e.g. desktop/web preview), frame in a sleek portrait phone viewport
              // that dynamically scales to the available window height so no scrolling is required
              final containerHeight = (screenHeight * 0.94).clamp(560.0, 840.0);
              final containerWidth = (containerHeight * (9.0 / 19.5)).clamp(320.0, 420.0);

              return Scaffold(
                backgroundColor: const Color(0xFF121217),
                body: Center(
                  child: Container(
                    width: containerWidth,
                    height: containerHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white12, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
