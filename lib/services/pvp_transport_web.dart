// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

class PvpWsChannel {
  final html.WebSocket _socket;
  bool _closed = false;
  bool _connected = false;
  StreamSubscription<dynamic>? _msgSub;
  StreamSubscription<dynamic>? _openSub;
  StreamSubscription<dynamic>? _closeSub;
  StreamSubscription<dynamic>? _errSub;

  PvpWsChannel(
    String wssUrl, {
    required void Function(String data) onMessage,
    void Function()? onOpen,
    void Function()? onClosed,
  }) : _socket = html.WebSocket(wssUrl) {
    _openSub = _socket.onOpen.listen((_) {
      _connected = true;
      onOpen?.call();
    });
    _msgSub = _socket.onMessage.listen((event) {
      final data = event.data?.toString();
      if (data != null) {
        onMessage(data);
      }
    });
    _closeSub = _socket.onClose.listen((_) {
      _connected = false;
      if (!_closed) onClosed?.call();
    });
    _errSub = _socket.onError.listen((_) {
      _connected = false;
      if (!_closed) onClosed?.call();
    });
  }

  bool get isConnected => _connected && !_closed;

  void close() {
    if (_closed) return;
    _closed = true;
    _connected = false;
    _msgSub?.cancel();
    _openSub?.cancel();
    _closeSub?.cancel();
    _errSub?.cancel();
    try {
      _socket.close();
    } catch (_) {}
  }
}

Future<String?> httpPostString(String url, String body) async {
  try {
    final req = await html.HttpRequest.request(
      url,
      method: 'POST',
      sendData: body,
      requestHeaders: const {'Content-Type': 'text/plain; charset=utf-8'},
    ).timeout(const Duration(seconds: 6));
    final status = req.status ?? 0;
    if (status >= 200 && status < 300) {
      return req.responseText;
    }
  } catch (_) {}
  return null;
}

Future<String?> httpGetString(String url) async {
  try {
    final req = await html.HttpRequest.request(
      url,
      method: 'GET',
    ).timeout(const Duration(seconds: 6));
    final status = req.status ?? 0;
    if (status >= 200 && status < 300) {
      return req.responseText;
    }
  } catch (_) {}
  return null;
}

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

Stream<List<double>>? webDeviceMotionStream() {
  return html.window.onDeviceMotion.map((html.DeviceMotionEvent event) {
    final accG = event.accelerationIncludingGravity;
    final acc = (accG != null &&
            (accG.x != null || accG.y != null || accG.z != null))
        ? accG
        : event.acceleration;
    if (acc == null) {
      return const <double>[0.0, 0.0, 0.0];
    }
    return <double>[
      (acc.x ?? 0).toDouble(),
      (acc.y ?? 0).toDouble(),
      (acc.z ?? 0).toDouble(),
    ];
  });
}

Future<bool> requestWebMotionPermission() async {
  try {
    if (js_util.hasProperty(html.window, '__pbRequestMotionPermission')) {
      final result = js_util.callMethod<Object?>(
        html.window,
        '__pbRequestMotionPermission',
        const [],
      );
      if (result != null && js_util.hasProperty(result, 'then')) {
        final resolved = await js_util.promiseToFuture<Object?>(result);
        return resolved == true;
      }
      if (result is bool) return result;
    }
  } catch (_) {}
  return getWebMotionPermissionState() == 'granted';
}

String getWebMotionPermissionState() {
  try {
    if (js_util.hasProperty(html.window, '__pbMotionState')) {
      final state =
          js_util.getProperty<Object?>(html.window, '__pbMotionState');
      if (state != null) return state.toString();
    }
  } catch (_) {}
  return 'granted';
}
