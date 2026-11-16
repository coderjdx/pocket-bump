import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class StepCounterService {
  static StreamSubscription<StepCount>? _stepSubscription;
  static int _initialSteps = -1;
  static int _sessionSteps = 0;
  static int _stepsUntilNextEncounter = 350;

  static final Random _rng = Random();

  static Future<void> initialize({required Function() onEncounter}) async {
    // 1. Request Activity Recognition permission
    await Permission.activityRecognition.request();

    // 2. Listen to hardware pedometer coprocessor
    try {
      _stepSubscription = Pedometer.stepCountStream.listen((StepCount event) {
        if (_initialSteps == -1) {
          _initialSteps = event.steps;
        }

        int currentSession = event.steps - _initialSteps;
        int diff = currentSession - _sessionSteps;
        if (diff > 0) {
          _sessionSteps = currentSession;
          _stepsUntilNextEncounter -= diff;

          if (_stepsUntilNextEncounter <= 0) {
            // Trigger random encounter!
            _stepsUntilNextEncounter = 300 + _rng.nextInt(200); // Reset for next ~300-500 steps
            _triggerEncounterAlert();
            onEncounter();
          }
        }
      });
    } catch (e) {
      // Step counter sensor may not be supported on some emulators
    }
  }

  static Future<void> _triggerEncounterAlert() async {
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
  }

  static int get sessionSteps => _sessionSteps;

  static void dispose() {
    _stepSubscription?.cancel();
  }
}
