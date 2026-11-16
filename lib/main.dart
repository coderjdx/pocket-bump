import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/trainer.dart';
import 'screens/starter_select_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PocketBumpApp());
}

class PocketBumpApp extends StatelessWidget {
  const PocketBumpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<Trainer>(
      create: (_) => Trainer(name: "Red"),
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
          );
        },
      ),
    );
  }
}
