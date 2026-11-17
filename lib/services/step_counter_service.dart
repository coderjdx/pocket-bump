import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class StepCounterService {
  static StreamSubscription<StepCount>? _stepSubscription;
  static int _initialSteps = -1;
  static int _sessionSteps = 0;

  static Future<void> initialize({
    Function()? onEncounter,
    void Function(int stepDelta)? onStepDelta,
  }) async {
    if (kIsWeb) return;

    // 1. Request Activity Recognition permission
    try {
      await Permission.activityRecognition.request();
    } catch (_) {}

    // 2. Listen to hardware pedometer coprocessor
    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) {
          if (_initialSteps == -1) {
            _initialSteps = event.steps;
          }

          int currentSession = event.steps - _initialSteps;
          int diff = currentSession - _sessionSteps;
          if (diff > 0) {
            _sessionSteps = currentSession;
            onStepDelta?.call(diff);
          }
        },
        onError: (_) {},
      );
    } catch (e) {
      // Step counter sensor may not be supported on some emulators
    }
  }

  static Future<void> triggerEncounterAlert() async {
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
  }

  static int get sessionSteps => _sessionSteps;

  static void dispose() {
    _stepSubscription?.cancel();
  }
}
