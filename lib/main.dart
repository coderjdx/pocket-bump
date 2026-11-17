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
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();
              final screenWidth = MediaQuery.of(context).size.width;
              if (screenWidth <= 500) return child;
              return Scaffold(
                backgroundColor: const Color(0xFF121217),
                body: Center(
                  child: Container(
                    width: 420,
                    height: 840,
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
