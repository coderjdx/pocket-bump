import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'pvp_transport.dart';

class _MotionTracker {
  double? baselineMag;
  int sampleCount = 0;

  void reset() {
    baselineMag = null;
    sampleCount = 0;
  }
}

class BumpService {
  static StreamSubscription<AccelerometerEvent>? _subscription;
  static StreamSubscription<List<double>>? _webMotionSubscription;
  static DateTime? _lastBumpTime;
  static final _MotionTracker _accelTracker = _MotionTracker();
  static final _MotionTracker _webTracker = _MotionTracker();

  /// Peak 3D acceleration threshold (in m/s^2) and high-pass jerk threshold.
  static const double bumpThreshold = 15.2;
  static const double jerkThreshold = 5.5;
  static const int debounceDurationMs = 1200;

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

      if (tracker.baselineMag == null) {
        tracker.baselineMag = magnitude;
        onMotionUpdate?.call(magnitude, 0.0);
        return;
      }

      final double delta = (magnitude - tracker.baselineMag!).abs();
      tracker.baselineMag = tracker.baselineMag! * 0.85 + magnitude * 0.15;

      onMotionUpdate?.call(magnitude, delta);

      final bool triggered = tracker.sampleCount >= 2 &&
          (magnitude >= bumpThreshold || delta >= jerkThreshold);
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
