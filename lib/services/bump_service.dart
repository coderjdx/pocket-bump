import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

class BumpService {
  static StreamSubscription<AccelerometerEvent>? _subscription;
  static DateTime? _lastBumpTime;

  /// Accelerometer shock threshold for detecting a fist-bump (in m/s^2)
  static const double bumpThreshold = 22.0;
  static const int debounceDurationMs = 1500;

  static void startListening({required Function(DateTime timestamp) onBump}) {
    _subscription?.cancel();

    _subscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        // Calculate 3D magnitude
        double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

        if (magnitude > bumpThreshold) {
          final now = DateTime.now();
          if (_lastBumpTime == null || now.difference(_lastBumpTime!).inMilliseconds > debounceDurationMs) {
            _lastBumpTime = now;
            // Trigger Haptic Feedback
            HapticFeedback.heavyImpact();
            onBump(now);
          }
        }
      },
      onError: (_) {},
    );
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}
