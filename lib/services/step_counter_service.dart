import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'health_steps_bridge.dart';

enum StepSyncStatus {
  webPreview,
  syncing,
  syncedHealthAndSensor,
  syncedHealthOnly,
  syncedSensorOnly,
  needsPermission,
  unavailable,
}

class StepSyncState {
  final StepSyncStatus status;
  final String label;
  final String detail;
  final DateTime? lastSyncedAt;

  const StepSyncState({
    required this.status,
    required this.label,
    required this.detail,
    this.lastSyncedAt,
  });
}

class StepCounterService {
  static const String _prefLastHwStepsKey = 'pb_step_last_hw_steps';
  static const String _prefLastHwDateKey = 'pb_step_last_hw_date';
  static const String _prefPendingHcCreditKey = 'pb_step_pending_hc_credit';

  static StreamSubscription<StepCount>? _stepSubscription;
  static Timer? _pollTimer;

  static int Function()? _getCurrentDailySteps;
  static void Function(int stepDelta, {required bool isLiveStep})? _onStepDelta;

  static bool _initialized = false;
  static bool _prefsLoaded = false;
  static bool _isSyncing = false;

  static int _lastHardwareSteps = -1;
  static String _lastHardwareDate = '';
  static int _pendingHealthCredit = 0;

  static bool _sensorPermGranted = false;
  static bool _sensorActive = false;
  static bool _healthActive = false;
  static HealthStepsAccessState _hcAccessState =
      HealthStepsAccessState.unsupported;

  static final ValueNotifier<StepSyncState> syncState =
      ValueNotifier<StepSyncState>(
    const StepSyncState(
      status: StepSyncStatus.syncing,
      label: 'INIT',
      detail: 'Preparing phone step sync...',
    ),
  );

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> _loadPersistedState() async {
    if (_prefsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      final savedDate = prefs.getString(_prefLastHwDateKey) ?? '';
      if (savedDate == today) {
        _lastHardwareSteps = prefs.getInt(_prefLastHwStepsKey) ?? -1;
        _lastHardwareDate = savedDate;
        _pendingHealthCredit =
            max(0, prefs.getInt(_prefPendingHcCreditKey) ?? 0);
      } else {
        _lastHardwareSteps = -1;
        _lastHardwareDate = today;
        _pendingHealthCredit = 0;
        await prefs.setString(_prefLastHwDateKey, today);
        await prefs.remove(_prefLastHwStepsKey);
        await prefs.setInt(_prefPendingHcCreditKey, 0);
      }
    } catch (_) {}
    _prefsLoaded = true;
  }

  static Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastHwDateKey, _lastHardwareDate);
      if (_lastHardwareSteps >= 0) {
        await prefs.setInt(_prefLastHwStepsKey, _lastHardwareSteps);
      } else {
        await prefs.remove(_prefLastHwStepsKey);
      }
      await prefs.setInt(_prefPendingHcCreditKey, max(0, _pendingHealthCredit));
    } catch (_) {}
  }

  static Future<void> resetPersistedBaselines() async {
    _lastHardwareSteps = -1;
    _lastHardwareDate = _todayKey();
    _pendingHealthCredit = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefLastHwStepsKey);
      await prefs.remove(_prefLastHwDateKey);
      await prefs.remove(_prefPendingHcCreditKey);
    } catch (_) {}
  }

  static Future<void> initialize({
    required int Function() getCurrentDailySteps,
    required void Function(int stepDelta, {required bool isLiveStep})
        onStepDelta,
    bool requestPermissions = true,
  }) async {
    _getCurrentDailySteps = getCurrentDailySteps;
    _onStepDelta = onStepDelta;

    if (kIsWeb) {
      _initialized = true;
      syncState.value = const StepSyncState(
        status: StepSyncStatus.webPreview,
        label: 'WEB',
        detail: 'Built-in phone step counter requires the Android app.',
      );
      return;
    }

    await _loadPersistedState();

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      syncNow(requestPermissions: false, forceSensorRefresh: false);
    });

    _initialized = true;
    await syncNow(
      requestPermissions: requestPermissions,
      forceSensorRefresh: true,
    );
  }

  static void _attachHardwareListener({required bool forceRefresh}) {
    if (_stepSubscription != null && !forceRefresh) return;
    _stepSubscription?.cancel();
    _stepSubscription = null;

    try {
      _stepSubscription = Pedometer.stepCountStream.listen(
        (StepCount event) async {
          _sensorActive = true;
          final today = _todayKey();

          if (_lastHardwareDate != today) {
            _lastHardwareDate = today;
            _lastHardwareSteps = event.steps;
            _pendingHealthCredit = 0;
            await _persistState();
            _updateStatus();
            return;
          }

          if (_lastHardwareSteps < 0) {
            _lastHardwareSteps = event.steps;
            _lastHardwareDate = today;
            await _persistState();
            _updateStatus();
            return;
          }

          final int rawDelta = event.steps >= _lastHardwareSteps
              ? (event.steps - _lastHardwareSteps)
              : event.steps; // Device rebooted since last reading
          _lastHardwareSteps = event.steps;
          _lastHardwareDate = today;

          final int absorbed = min(rawDelta, _pendingHealthCredit);
          _pendingHealthCredit -= absorbed;
          final int netDelta = rawDelta - absorbed;

          await _persistState();
          if (netDelta > 0) {
            _onStepDelta?.call(netDelta, isLiveStep: true);
          }
          _updateStatus();
        },
        onError: (_) {
          _sensorActive = false;
          _updateStatus();
        },
        cancelOnError: false,
      );
      // Assume sensor available until proven otherwise if permission granted
      _sensorActive = true;
    } catch (_) {
      _sensorActive = false;
    }
  }

  static void _updateStatus() {
    if (kIsWeb) return;
    final now = DateTime.now();
    if (_healthActive && _sensorActive) {
      syncState.value = StepSyncState(
        status: StepSyncStatus.syncedHealthAndSensor,
        label: 'SYNCED',
        detail: 'Synced with Health Connect & live phone step sensor.',
        lastSyncedAt: now,
      );
      return;
    }
    if (_healthActive) {
      syncState.value = StepSyncState(
        status: StepSyncStatus.syncedHealthOnly,
        label: 'SYNCED',
        detail: 'Synced daily steps from Health Connect.',
        lastSyncedAt: now,
      );
      return;
    }
    if (_sensorActive) {
      final bool hcNeedsSetup =
          _hcAccessState == HealthStepsAccessState.needsPermission ||
              _hcAccessState == HealthStepsAccessState.needsInstall;
      syncState.value = StepSyncState(
        status: StepSyncStatus.syncedSensorOnly,
        label: hcNeedsSetup ? 'LIVE • HC' : 'LIVE',
        detail: hcNeedsSetup
            ? 'Live step sensor active. Tap to connect Health Connect daily totals.'
            : 'Counting live steps via built-in phone step sensor.',
        lastSyncedAt: now,
      );
      return;
    }
    if (!_sensorPermGranted ||
        _hcAccessState == HealthStepsAccessState.needsPermission ||
        _hcAccessState == HealthStepsAccessState.needsInstall) {
      syncState.value = StepSyncState(
        status: StepSyncStatus.needsPermission,
        label: _hcAccessState == HealthStepsAccessState.needsInstall
            ? 'GET HC'
            : 'ENABLE',
        detail: _hcAccessState == HealthStepsAccessState.needsInstall
            ? 'Tap to install Health Connect or grant Physical Activity access.'
            : 'Tap to grant step & Health Connect permissions.',
        lastSyncedAt: now,
      );
      return;
    }
    syncState.value = StepSyncState(
      status: StepSyncStatus.unavailable,
      label: 'NO SENSOR',
      detail: 'No hardware step sensor or Health Connect step data found.',
      lastSyncedAt: now,
    );
  }

  static Future<({int syncedSteps, String message})> syncNow({
    bool requestPermissions = false,
    bool openSettingsIfDenied = false,
    bool forceSensorRefresh = true,
  }) async {
    if (kIsWeb) {
      return (
        syncedSteps: 0,
        message: 'Built-in phone step syncing works on the Android app.',
      );
    }
    if (_isSyncing) {
      return (syncedSteps: 0, message: 'Step sync already in progress...');
    }
    _isSyncing = true;
    await _loadPersistedState();

    syncState.value = StepSyncState(
      status: StepSyncStatus.syncing,
      label: 'SYNCING',
      detail: 'Syncing with phone step counter...',
      lastSyncedAt: syncState.value.lastSyncedAt,
    );

    int totalSynced = 0;
    bool openedSettings = false;

    try {
      // 1. Hardware step counter permission & listener
      try {
        var actStatus = await Permission.activityRecognition.status;
        if (!actStatus.isGranted && requestPermissions) {
          if (actStatus.isPermanentlyDenied) {
            if (openSettingsIfDenied) {
              openedSettings = await openAppSettings();
            }
          } else {
            actStatus = await Permission.activityRecognition.request();
            if (!actStatus.isGranted &&
                actStatus.isPermanentlyDenied &&
                openSettingsIfDenied) {
              openedSettings = await openAppSettings();
            }
          }
        }
        _sensorPermGranted = actStatus.isGranted;
        if (_sensorPermGranted) {
          _attachHardwareListener(forceRefresh: forceSensorRefresh);
        } else {
          _sensorActive = false;
        }
      } catch (_) {
        _sensorActive = false;
      }

      // 2. Health Connect built-in daily total sync
      try {
        _hcAccessState = await HealthStepsBridge.checkStatus();
        if (_hcAccessState == HealthStepsAccessState.needsPermission &&
            requestPermissions) {
          _hcAccessState = await HealthStepsBridge.requestPermission();
        }
        if (_hcAccessState == HealthStepsAccessState.needsInstall &&
            openSettingsIfDenied) {
          await HealthStepsBridge.openHealthConnectInstall();
        }

        if (_hcAccessState == HealthStepsAccessState.granted) {
          final int? phoneToday = await HealthStepsBridge.readTodaySteps();
          if (phoneToday != null) {
            _healthActive = true;
            final int currentDaily = _getCurrentDailySteps?.call() ?? 0;
            final int hcDelta = phoneToday - currentDaily;
            if (hcDelta > 0) {
              if (_lastHardwareSteps >= 0) {
                _pendingHealthCredit += hcDelta;
                await _persistState();
              }
              _onStepDelta?.call(hcDelta, isLiveStep: false);
              totalSynced += hcDelta;
            }
          } else {
            _healthActive = false;
          }
        } else {
          _healthActive = false;
        }
      } catch (_) {
        _healthActive = false;
      }

      _updateStatus();

      final String message;
      if (totalSynced > 0) {
        message = 'Synced +$totalSynced steps from your phone!';
      } else if (openedSettings) {
        message = 'Grant Physical Activity permission in Settings, then return.';
      } else if (_hcAccessState == HealthStepsAccessState.needsInstall &&
          openSettingsIfDenied) {
        message = 'Install or update Google Health Connect to sync daily phone steps.';
      } else if (!_sensorPermGranted &&
          _hcAccessState != HealthStepsAccessState.granted) {
        message = 'Grant Physical Activity or Health Connect permission to sync steps.';
      } else if (_healthActive) {
        message = 'Steps are up to date with Health Connect!';
      } else if (_sensorActive) {
        message = 'Live phone step sensor active — walk to count steps!';
      } else {
        message = 'No step sensor or Health Connect step records detected.';
      }

      return (syncedSteps: totalSynced, message: message);
    } finally {
      _isSyncing = false;
    }
  }

  static Future<void> onAppResumed() async {
    if (kIsWeb || !_initialized) return;
    await syncNow(requestPermissions: false, forceSensorRefresh: true);
  }

  static Future<void> triggerEncounterAlert() async {
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.alert);
  }

  static void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _stepSubscription?.cancel();
    _stepSubscription = null;
    _initialized = false;
  }
}
