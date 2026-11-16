import 'dart:async';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class StepCounterService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription<StepCount>? _stepSubscription;
  static int _initialSteps = -1;
  static int _sessionSteps = 0;
  static int _stepsUntilNextEncounter = 350;

  static final Random _rng = Random();

  static Future<void> initialize({required Function() onEncounter}) async {
    // 1. Request Activity Recognition & Notification permissions
    await Permission.activityRecognition.request();
    await Permission.notification.request();

    // 2. Initialize Notification settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    // 3. Listen to hardware pedometer coprocessor
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
            _triggerEncounterNotification();
            onEncounter();
          }
        }
      });
    } catch (e) {
      // Step counter sensor may not be supported on some emulators
    }
  }

  static Future<void> _triggerEncounterNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'pocket_bump_encounters',
      'Wild Pokémon Encounters',
      channelDescription: 'Alerts when a wild Pokémon appears while walking.',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,
      '🍃 Rustling in the tall grass!',
      'A wild Pokémon appeared! Tap to catch it!',
      notificationDetails,
    );
  }

  static int get sessionSteps => _sessionSteps;

  static void dispose() {
    _stepSubscription?.cancel();
  }
}
