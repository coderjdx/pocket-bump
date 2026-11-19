import 'dart:async';
import 'dart:convert';
import 'dart:io';

class PvpWsChannel {
  WebSocket? _ws;
  StreamSubscription<dynamic>? _sub;
  bool _closed = false;
  bool _connected = false;

  PvpWsChannel(
    String wssUrl, {
    required void Function(String data) onMessage,
    void Function()? onOpen,
    void Function()? onClosed,
  }) {
    _connect(wssUrl, onMessage: onMessage, onOpen: onOpen, onClosed: onClosed);
  }

  Future<void> _connect(
    String wssUrl, {
    required void Function(String data) onMessage,
    void Function()? onOpen,
    void Function()? onClosed,
  }) async {
    try {
      final ws =
          await WebSocket.connect(wssUrl).timeout(const Duration(seconds: 8));
      if (_closed) {
        await ws.close();
        return;
      }
      ws.pingInterval = const Duration(seconds: 20);
      _ws = ws;
      _connected = true;
      onOpen?.call();
      _sub = ws.listen(
        (data) {
          if (data is String) {
            onMessage(data);
          } else if (data is List<int>) {
            onMessage(utf8.decode(data, allowMalformed: true));
          }
        },
        onDone: () {
          _connected = false;
          if (!_closed) onClosed?.call();
        },
        onError: (_) {
          _connected = false;
          if (!_closed) onClosed?.call();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _connected = false;
      if (!_closed) onClosed?.call();
    }
  }

  bool get isConnected => _connected && !_closed;

  void close() {
    if (_closed) return;
    _closed = true;
    _connected = false;
    _sub?.cancel();
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
  }
}

Future<String?> httpPostString(String url, String body) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.postUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.contentTypeHeader, 'text/plain; charset=utf-8');
    req.add(utf8.encode(body));
    final resp = await req.close().timeout(const Duration(seconds: 6));
    final text = await utf8.decoder.bind(resp).join();
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return text;
    }
  } catch (_) {
  } finally {
    client.close(force: true);
  }
  return null;
}

Future<String?> httpGetString(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, 'PocketBump');
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final resp = await req.close().timeout(const Duration(seconds: 6));
    final text = await utf8.decoder.bind(resp).join();
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return text;
    }
  } catch (_) {
  } finally {
    client.close(force: true);
  }
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

Stream<List<double>>? webDeviceMotionStream() => null;

Future<bool> requestWebMotionPermission() async => true;

String getWebMotionPermissionState() => 'granted';
