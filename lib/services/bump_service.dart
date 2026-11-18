import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'pvp_transport.dart';

class _MotionTracker {
  double? baselineMag;
  double? prevX;
  double? prevY;
  double? prevZ;
  int sampleCount = 0;

  void reset() {
    baselineMag = null;
    prevX = null;
    prevY = null;
    prevZ = null;
    sampleCount = 0;
  }
}

class BumpService {
  static StreamSubscription<AccelerometerEvent>? _subscription;
  static StreamSubscription<List<double>>? _webMotionSubscription;
  static DateTime? _lastBumpTime;
  static final _MotionTracker _accelTracker = _MotionTracker();
  static final _MotionTracker _webTracker = _MotionTracker();

  /// Deliberate fist-bump impact thresholds (in m/s^2).
  /// Requires a sharp collision spike rather than ordinary phone movement.
  static const double bumpThreshold = 23.5;
  static const double jerkThreshold = 12.0;
  static const double vectorJerkThreshold = 12.0;
  static const int settleSamples = 8;
  static const int debounceDurationMs = 1400;

  static void startListening({
    required Function(DateTime timestamp) onBump,
    void Function(double magnitude, double delta)? onMotionUpdate,
  }) {
    stopListening();
    _accelTracker.reset();
    _webTracker.reset();

    void handleSample(
      _MotionTracker tracker,
      double x,
      double y,
      double z,
    ) {
      if (x == 0.0 && y == 0.0 && z == 0.0) return;

      final double magnitude = sqrt(x * x + y * y + z * z);
      tracker.sampleCount++;

      if (tracker.baselineMag == null ||
          tracker.prevX == null ||
          tracker.prevY == null ||
          tracker.prevZ == null) {
        tracker.baselineMag = magnitude;
        tracker.prevX = x;
        tracker.prevY = y;
        tracker.prevZ = z;
        onMotionUpdate?.call(magnitude, 0.0);
        return;
      }

      final double dx = x - tracker.prevX!;
      final double dy = y - tracker.prevY!;
      final double dz = z - tracker.prevZ!;
      final double vectorJerk = sqrt(dx * dx + dy * dy + dz * dz);
      tracker.prevX = x;
      tracker.prevY = y;
      tracker.prevZ = z;

      final double delta = (magnitude - tracker.baselineMag!).abs();
      // Only adapt gravity/holding baseline when not mid-spike so impact delta stays crisp
      if (delta < 7.0) {
        tracker.baselineMag = tracker.baselineMag! * 0.90 + magnitude * 0.10;
      }

      onMotionUpdate?.call(magnitude, delta);

      final bool triggered = tracker.sampleCount >= settleSamples &&
          ((delta >= jerkThreshold && vectorJerk >= vectorJerkThreshold) ||
              (magnitude >= bumpThreshold && vectorJerk >= 10.5) ||
              delta >= 16.5);
      if (triggered) {
        final now = DateTime.now();
        if (_lastBumpTime == null ||
            now.difference(_lastBumpTime!).inMilliseconds > debounceDurationMs) {
          _lastBumpTime = now;
          HapticFeedback.heavyImpact();
          onBump(now);
        }
      }
    }

    try {
      _subscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          handleSample(_accelTracker, event.x, event.y, event.z);
        },
        onError: (_) {},
      );
    } catch (_) {}

    try {
      final webStream = webDeviceMotionStream();
      if (webStream != null) {
        _webMotionSubscription = webStream.listen(
          (List<double> xyz) {
            if (xyz.length >= 3) {
              handleSample(_webTracker, xyz[0], xyz[1], xyz[2]);
            }
          },
          onError: (_) {},
        );
      }
    } catch (_) {}
  }

  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _webMotionSubscription?.cancel();
    _webMotionSubscription = null;
  }
}
