enum HealthStepsAccessState {
  unsupported,
  needsInstall,
  needsPermission,
  granted,
}

class HealthStepsBridge {
  static Future<HealthStepsAccessState> checkStatus() async =>
      HealthStepsAccessState.unsupported;

  static Future<HealthStepsAccessState> requestPermission() async =>
      HealthStepsAccessState.unsupported;

  static Future<int?> readTodaySteps() async => null;

  static Future<void> openHealthConnectInstall() async {}
}
