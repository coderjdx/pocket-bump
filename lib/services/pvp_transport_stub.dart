import 'dart:async';

class PvpWsChannel {
  PvpWsChannel(
    String wssUrl, {
    required void Function(String data) onMessage,
    void Function()? onOpen,
    void Function()? onClosed,
  });

  bool get isConnected => false;

  void close() {}
}

Future<String?> httpPostString(String url, String body) async => null;

Future<String?> httpGetString(String url) async => null;

PvpWsChannel connectWebSocket(
  String wssUrl, {
  required void Function(String data) onMessage,
  void Function()? onOpen,
  void Function()? onClosed,
}) =>
    PvpWsChannel(
      wssUrl,
      onMessage: onMessage,
      onOpen: onOpen,
      onClosed: onClosed,
    );

Stream<List<double>>? webDeviceMotionStream() => null;

Future<bool> requestWebMotionPermission() async => true;

String getWebMotionPermissionState() => 'granted';
