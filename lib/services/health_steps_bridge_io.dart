import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

enum HealthStepsAccessState {
  unsupported,
  needsInstall,
  needsPermission,
  granted,
}

class HealthStepsBridge {
  static final Health _health = Health();
  static bool _configured = false;

  static const List<HealthDataType> _stepTypes = [HealthDataType.STEPS];
  static const List<HealthDataAccess> _stepPerms = [HealthDataAccess.READ];

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  static Future<HealthStepsAccessState> checkStatus() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return HealthStepsAccessState.unsupported;
    }
    try {
      await _ensureConfigured();
      if (Platform.isAndroid) {
        final sdkStatus = await _health.getHealthConnectSdkStatus();
        if (sdkStatus ==
            HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          return HealthStepsAccessState.needsInstall;
        }
        if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
          return HealthStepsAccessState.unsupported;
        }
      }
      final has = await _health.hasPermissions(
        _stepTypes,
        permissions: _stepPerms,
      );
      return has == true
          ? HealthStepsAccessState.granted
          : HealthStepsAccessState.needsPermission;
    } catch (_) {
      return HealthStepsAccessState.unsupported;
    }
  }

  static Future<HealthStepsAccessState> requestPermission() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return HealthStepsAccessState.unsupported;
    }
    try {
      await _ensureConfigured();
      if (Platform.isAndroid) {
        final sdkStatus = await _health.getHealthConnectSdkStatus();
        if (sdkStatus ==
            HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          return HealthStepsAccessState.needsInstall;
        }
        if (sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
          return HealthStepsAccessState.unsupported;
        }
      }
      final granted = await _health.requestAuthorization(
        _stepTypes,
        permissions: _stepPerms,
      );
      return granted
          ? HealthStepsAccessState.granted
          : HealthStepsAccessState.needsPermission;
    } catch (_) {
      return HealthStepsAccessState.needsPermission;
    }
  }

  static Future<int?> readTodaySteps() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return null;
    }
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      if (steps == null || steps < 0) return null;
      return steps;
    } catch (_) {
      return null;
    }
  }

  static Future<void> openHealthConnectInstall() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _health.installHealthConnect();
    } catch (_) {}
  }
}
