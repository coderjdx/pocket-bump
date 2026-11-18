import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import 'pvp_transport.dart';

class PvpDeviceIdentity {
  static String? _deviceId;

  static String get id {
    if (_deviceId != null) return _deviceId!;
    final rng = Random();
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final buf = StringBuffer('d');
    for (int i = 0; i < 10; i++) {
      buf.write(chars[rng.nextInt(chars.length)]);
    }
    _deviceId = buf.toString();
    return _deviceId!;
  }
}

class NearbyRadarTrainer {
  final String deviceId;
  final String name;
  final String title;
  final int partyCount;
  final int lastServerTime;

  const NearbyRadarTrainer({
    required this.deviceId,
    required this.name,
    required this.title,
    required this.partyCount,
    required this.lastServerTime,
  });
}

class PvpTurnPacket {
  final int turn;
  final String senderId;
  final int seed;
  final Map<String, dynamic> action;
  final Map<String, dynamic> activeMon;

  const PvpTurnPacket({
    required this.turn,
    required this.senderId,
    required this.seed,
    required this.action,
    required this.activeMon,
  });
}

List<Map<String, dynamic>> serializeTrainerPartyForPvp(Trainer trainer) {
  final lead = trainer.leadPokemon;
  final List<PokemonInstance> ordered = [];
  if (lead != null) {
    ordered.add(lead);
  }
  for (final mon in trainer.party) {
    if (mon != lead) {
      ordered.add(mon);
    }
  }
  return ordered.map((p) => p.toJson()).toList();
}

List<PokemonInstance> _parsePeerParty(dynamic rawParty) {
  if (rawParty is! List) return [];
  final List<PokemonInstance> result = [];
  for (final item in rawParty) {
    if (item is Map<String, dynamic>) {
      result.add(PokemonInstance.fromJson(item));
    } else if (item is Map) {
      result.add(PokemonInstance.fromJson(Map<String, dynamic>.from(item)));
    }
  }
  return result;
}

String _sanitizeTopicToken(String raw) {
  return raw.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
}

class PvpMatchSession {
  static const String _baseHttp = 'https://ntfy.sh';
  static const String _baseWss = 'wss://ntfy.sh';

  final String matchId;
  final String myDeviceId;
  final String peerDeviceId;
  final bool isHost;
  final String opponentName;
  final String opponentTitle;
  final String opponentSpriteId;
  final List<PokemonInstance> opponentTeam;

  VoidCallback? onPeerForfeit;

  late final String _topic;
  PvpWsChannel? _ws;
  Timer? _wsReconnectTimer;
  Timer? _pollTimer;
  bool _listening = false;
  bool _disposed = false;
  bool _peerForfeited = false;
  bool _pollInFlight = false;
  int _activeWaiters = 0;

  final Set<String> _seenMessageIds = {};
  final Map<int, PvpTurnPacket> _turnPackets = {};
  final Map<int, Completer<PvpTurnPacket>> _turnWaiters = {};
  final Map<int, Map<String, dynamic>> _forcedSwitches = {};
  final Map<int, Completer<Map<String, dynamic>>> _forcedSwitchWaiters = {};
  final Map<int, String> _outboundTurnPayloads = {};

  PvpMatchSession({
    required this.matchId,
    required this.myDeviceId,
    required this.peerDeviceId,
    required this.isHost,
    required this.opponentName,
    required this.opponentTitle,
    required this.opponentSpriteId,
    required this.opponentTeam,
  }) {
    _topic = 'pocket_bump_match_${_sanitizeTopicToken(matchId)}';
  }

  bool get isPeerForfeited => _peerForfeited;

  void startListening() {
    if (_listening || _disposed) return;
    _listening = true;
    _openWebSocket();
  }

  void _openWebSocket() {
    if (_disposed) return;
    _ws?.close();
    _ws = connectWebSocket(
      '$_baseWss/$_topic/ws',
      onMessage: _handleRawFrame,
      onClosed: () {
        if (!_disposed && _listening) {
          _wsReconnectTimer?.cancel();
          _wsReconnectTimer = Timer(const Duration(seconds: 2), _openWebSocket);
        }
      },
    );
  }

  Future<void> _postPacket(Map<String, dynamic> payload) async {
    if (_disposed) return;
    final encoded = jsonEncode(payload);
    final resp = await httpPostString('$_baseHttp/$_topic', encoded);
    if (resp != null && resp.isNotEmpty) {
      try {
        final decoded = jsonDecode(resp);
        if (decoded is Map && decoded['id'] is String) {
          _seenMessageIds.add(decoded['id'] as String);
        }
      } catch (_) {}
    }
  }

  Future<void> _pollMessages() async {
    if (_disposed || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final body =
          await httpGetString('$_baseHttp/$_topic/json?poll=1&since=all');
      if (body == null || body.isEmpty || _disposed) return;
      for (final line in LineSplitter.split(body)) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          _handleRawFrame(trimmed);
        }
      }
    } catch (_) {
    } finally {
      _pollInFlight = false;
    }
  }

  void _handleRawFrame(String raw) {
    if (_disposed) return;
    try {
      final envelope = jsonDecode(raw);
      if (envelope is! Map) return;
      if (envelope['event'] != 'message') return;
      final id = envelope['id'] as String?;
      if (id != null && !_seenMessageIds.add(id)) return;

      final msgStr = envelope['message'] as String?;
      if (msgStr == null || msgStr.isEmpty) return;
      final payload = jsonDecode(msgStr);
      if (payload is! Map) return;

      final senderId = payload['senderId'] as String?;
      if (senderId == null || senderId == myDeviceId) return;
      if (senderId != peerDeviceId) return;

      final kind = payload['kind'] as String?;
      if (kind == 'TURN_ACTION') {
        final turn = (payload['turn'] as num?)?.toInt();
        if (turn == null) return;
        final seed = (payload['seed'] as num?)?.toInt() ?? 0;
        final rawAction = payload['action'];
        final rawMon = payload['activeMon'];
        final packet = PvpTurnPacket(
          turn: turn,
          senderId: senderId,
          seed: seed,
          action: rawAction is Map
              ? Map<String, dynamic>.from(rawAction)
              : <String, dynamic>{},
          activeMon: rawMon is Map
              ? Map<String, dynamic>.from(rawMon)
              : <String, dynamic>{},
        );
        _turnPackets[turn] = packet;
        final waiter = _turnWaiters.remove(turn);
        if (waiter != null && !waiter.isCompleted) {
          waiter.complete(packet);
        }
      } else if (kind == 'FORCED_SWITCH') {
        final turn = (payload['turn'] as num?)?.toInt();
        if (turn == null) return;
        final data = Map<String, dynamic>.from(payload);
        _forcedSwitches[turn] = data;
        final waiter = _forcedSwitchWaiters.remove(turn);
        if (waiter != null && !waiter.isCompleted) {
          waiter.complete(data);
        }
      } else if (kind == 'FORFEIT') {
        _peerForfeited = true;
        _failPendingWaiters();
        onPeerForfeit?.call();
      }
    } catch (_) {}
  }

  void _failPendingWaiters() {
    for (final w in _turnWaiters.values) {
      if (!w.isCompleted) {
        w.completeError(StateError('peer_forfeit'));
      }
    }
    _turnWaiters.clear();
    for (final w in _forcedSwitchWaiters.values) {
      if (!w.isCompleted) {
        w.completeError(StateError('peer_forfeit'));
      }
    }
    _forcedSwitchWaiters.clear();
  }

  void _beginWaitPolling({int? resendTurn}) {
    _activeWaiters++;
    if (_pollTimer != null) return;
    int ticks = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (_disposed || _peerForfeited || _activeWaiters <= 0) {
        _pollTimer?.cancel();
        _pollTimer = null;
        return;
      }
      ticks++;
      _pollMessages();
      if (ticks % 4 == 0 && resendTurn != null) {
        final cached = _outboundTurnPayloads[resendTurn];
        if (cached != null) {
          httpPostString('$_baseHttp/$_topic', cached);
        }
      }
    });
  }

  void _endWaitPolling() {
    _activeWaiters = max(0, _activeWaiters - 1);
    if (_activeWaiters == 0) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<PvpTurnPacket> exchangeTurnAction({
    required int turn,
    required int mySeed,
    required Map<String, dynamic> action,
    required Map<String, dynamic> activeMon,
  }) async {
    startListening();
    if (_peerForfeited) {
      throw StateError('peer_forfeit');
    }

    final payload = <String, dynamic>{
      'kind': 'TURN_ACTION',
      'senderId': myDeviceId,
      'turn': turn,
      'seed': mySeed,
      'action': action,
      'activeMon': activeMon,
    };
    _outboundTurnPayloads[turn] = jsonEncode(payload);
    unawaited(_postPacket(payload));

    final existing = _turnPackets[turn];
    if (existing != null) {
      return existing;
    }

    final completer = _turnWaiters.putIfAbsent(
      turn,
      () => Completer<PvpTurnPacket>(),
    );
    _beginWaitPolling(resendTurn: turn);
    unawaited(_pollMessages());
    try {
      return await completer.future;
    } finally {
      _endWaitPolling();
    }
  }

  Future<void> sendForcedSwitch({
    required int turn,
    required int partyIndex,
    required Map<String, dynamic> activeMon,
  }) async {
    startListening();
    await _postPacket(<String, dynamic>{
      'kind': 'FORCED_SWITCH',
      'senderId': myDeviceId,
      'turn': turn,
      'partyIndex': partyIndex,
      'activeMon': activeMon,
    });
  }

  Future<Map<String, dynamic>> waitForPeerForcedSwitch({
    required int turn,
  }) async {
    startListening();
    if (_peerForfeited) {
      throw StateError('peer_forfeit');
    }

    final existing = _forcedSwitches[turn];
    if (existing != null) {
      return existing;
    }

    final completer = _forcedSwitchWaiters.putIfAbsent(
      turn,
      () => Completer<Map<String, dynamic>>(),
    );
    _beginWaitPolling();
    unawaited(_pollMessages());
    try {
      return await completer.future;
    } finally {
      _endWaitPolling();
    }
  }

  void sendForfeit() {
    if (_disposed) return;
    final payload = jsonEncode(<String, dynamic>{
      'kind': 'FORFEIT',
      'senderId': myDeviceId,
    });
    unawaited(httpPostString('$_baseHttp/$_topic', payload));
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _listening = false;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _ws?.close();
    _ws = null;
    for (final w in _turnWaiters.values) {
      if (!w.isCompleted) {
        w.completeError(StateError('session_disposed'));
      }
    }
    _turnWaiters.clear();
    for (final w in _forcedSwitchWaiters.values) {
      if (!w.isCompleted) {
        w.completeError(StateError('session_disposed'));
      }
    }
    _forcedSwitchWaiters.clear();
  }
}

class PvpLobbyMatchmaker {
  static const String _baseHttp = 'https://ntfy.sh';
  static const String _baseWss = 'wss://ntfy.sh';
  static const String _lobbyTopic = 'pocket_bump_vs_lobby_v2';

  final Trainer trainer;
  final void Function(PvpMatchSession session) onMatched;
  final void Function(List<NearbyRadarTrainer> nearby)? onNearbyChanged;
  final VoidCallback? onOfferTimeout;

  late final String myDeviceId;
  PvpWsChannel? _ws;
  Timer? _wsReconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _pollTimer;
  Timer? _offerTimeoutTimer;
  Timer? _offerRetryTimer;

  bool _started = false;
  bool _disposed = false;
  bool _matched = false;
  bool _searchingBump = false;
  bool _pollInFlight = false;
  String? _activeOfferNonce;

  int? _sessionAnchorServerTime;
  int _latestServerTime = 0;

  final Set<String> _seenMessageIds = {};
  final Map<String, NearbyRadarTrainer> _nearbyTrainers = {};

  PvpLobbyMatchmaker({
    required this.trainer,
    required this.onMatched,
    this.onNearbyChanged,
    this.onOfferTimeout,
  }) {
    myDeviceId = PvpDeviceIdentity.id;
  }

  bool get isSearchingBump => _searchingBump;
  bool get isMatched => _matched;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    await _sendPresence();
    if (_disposed || _matched) return;

    _openWebSocket();
    unawaited(_pollLobby());

    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_disposed || _matched) return;
      _sendPresence();
      _pruneStaleNearby();
    });

    _setPollInterval(const Duration(milliseconds: 2200));
  }

  void _setPollInterval(Duration duration) {
    _pollTimer?.cancel();
    if (_disposed || _matched) return;
    _pollTimer = Timer.periodic(duration, (_) {
      if (_disposed || _matched) return;
      _pollLobby();
    });
  }

  void _openWebSocket() {
    if (_disposed || _matched) return;
    _ws?.close();
    _ws = connectWebSocket(
      '$_baseWss/$_lobbyTopic/ws',
      onMessage: _handleWsMessage,
      onClosed: () {
        if (!_disposed && !_matched && _started) {
          _wsReconnectTimer?.cancel();
          _wsReconnectTimer = Timer(const Duration(seconds: 2), _openWebSocket);
        }
      },
    );
  }

  Future<void> _sendPresence() async {
    if (_disposed || _matched) return;
    await _postLobby({
      'kind': 'RADAR_PRESENCE',
      'senderId': myDeviceId,
      'trainerName': trainer.name,
      'trainerTitle': trainer.avatar.title,
      'avatarId': trainer.avatar.id,
      'partyCount': trainer.party.length,
    });
  }

  Future<void> triggerBumpOffer() async {
    if (_disposed || _matched) return;

    _searchingBump = true;
    final nonce =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    _activeOfferNonce = nonce;

    _offerTimeoutTimer?.cancel();
    _offerRetryTimer?.cancel();

    final offerPayload = _buildOfferOrAcceptPayload(
      kind: 'BUMP_OFFER',
      offerNonce: nonce,
    );

    unawaited(_postLobby(offerPayload));
    _setPollInterval(const Duration(milliseconds: 750));
    unawaited(_pollLobby());

    int retries = 0;
    _offerRetryTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (_disposed || _matched || !_searchingBump) {
        _offerRetryTimer?.cancel();
        return;
      }
      retries++;
      if (retries <= 2) {
        unawaited(_postLobby(offerPayload));
      }
    });

    _offerTimeoutTimer = Timer(const Duration(seconds: 7), () {
      if (_disposed || _matched || !_searchingBump) return;
      _searchingBump = false;
      _activeOfferNonce = null;
      _offerRetryTimer?.cancel();
      _setPollInterval(const Duration(milliseconds: 2200));
      onOfferTimeout?.call();
    });
  }

  void cancelBumpOffer() {
    _searchingBump = false;
    _activeOfferNonce = null;
    _offerTimeoutTimer?.cancel();
    _offerRetryTimer?.cancel();
    if (!_disposed && !_matched) {
      _setPollInterval(const Duration(milliseconds: 2200));
    }
  }

  Map<String, dynamic> _buildOfferOrAcceptPayload({
    required String kind,
    required String offerNonce,
    String? targetId,
    String? matchId,
  }) {
    return <String, dynamic>{
      'kind': kind,
      'senderId': myDeviceId,
      'offerNonce': offerNonce,
      if (targetId != null) 'targetId': targetId,
      if (matchId != null) 'matchId': matchId,
      'trainerName': trainer.name,
      'trainerTitle': trainer.avatar.title,
      'avatarId': trainer.avatar.id,
      'party': serializeTrainerPartyForPvp(trainer),
    };
  }

  Future<void> _postLobby(Map<String, dynamic> payload) async {
    if (_disposed) return;
    final resp = await httpPostString(
      '$_baseHttp/$_lobbyTopic',
      jsonEncode(payload),
    );
    if (resp != null && resp.isNotEmpty) {
      try {
        final decoded = jsonDecode(resp);
        if (decoded is Map) {
          final id = decoded['id'] as String?;
          if (id != null) _seenMessageIds.add(id);
          final srvTime = (decoded['time'] as num?)?.toInt();
          if (srvTime != null) _updateServerTime(srvTime);
        }
      } catch (_) {}
    }
  }

  void _updateServerTime(int t) {
    if (t > _latestServerTime) {
      _latestServerTime = t;
    }
    _sessionAnchorServerTime ??= t;
  }

  void _handleWsMessage(String raw) {
    if (_disposed || _matched) return;
    try {
      final env = jsonDecode(raw);
      if (env is! Map) return;
      final t = (env['time'] as num?)?.toInt();
      if (t != null) _updateServerTime(t);
      if (env['event'] != 'message') return;
      _processEnvelope(env);
    } catch (_) {}
  }

  Future<void> _pollLobby() async {
    if (_disposed || _matched || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final body = await httpGetString(
        '$_baseHttp/$_lobbyTopic/json?poll=1&since=all',
      );
      if (body == null || body.isEmpty || _disposed || _matched) return;

      final List<Map<dynamic, dynamic>> envelopes = [];
      for (final line in LineSplitter.split(body)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final env = jsonDecode(trimmed);
          if (env is Map) {
            final t = (env['time'] as num?)?.toInt();
            if (t != null) _updateServerTime(t);
            if (env['event'] == 'message') {
              envelopes.add(env);
            }
          }
        } catch (_) {}
      }

      for (final env in envelopes) {
        if (_disposed || _matched) break;
        _processEnvelope(env);
      }
    } catch (_) {
    } finally {
      _pollInFlight = false;
    }
  }

  void _processEnvelope(Map<dynamic, dynamic> env) {
    if (_disposed || _matched) return;

    final id = env['id'] as String?;
    if (id != null && !_seenMessageIds.add(id)) return;

    final int msgTime = (env['time'] as num?)?.toInt() ?? 0;
    final int newest = _latestServerTime > 0 ? _latestServerTime : msgTime;

    // Ignore stale messages older than 12s relative to ntfy.sh's server clock.
    if (newest > 0 && msgTime > 0 && (newest - msgTime) > 12) {
      return;
    }

    final msgStr = env['message'] as String?;
    if (msgStr == null || msgStr.isEmpty) return;

    final dynamic rawPayload = jsonDecode(msgStr);
    if (rawPayload is! Map) return;
    final payload = Map<String, dynamic>.from(rawPayload);

    final String? senderId = payload['senderId'] as String?;
    if (senderId == null || senderId == myDeviceId) return;

    final String? kind = payload['kind'] as String?;
    if (kind == 'RADAR_PRESENCE') {
      _nearbyTrainers[senderId] = NearbyRadarTrainer(
        deviceId: senderId,
        name: (payload['trainerName'] as String?) ?? 'Trainer',
        title: (payload['trainerTitle'] as String?) ?? 'Trainer',
        partyCount: (payload['partyCount'] as num?)?.toInt() ?? 1,
        lastServerTime: msgTime > 0 ? msgTime : newest,
      );
      _pruneStaleNearby();
      return;
    }

    final int anchor = _sessionAnchorServerTime ?? newest;
    // Do not match against bump offers/accepts from before this screen opened.
    if (anchor > 0 && msgTime > 0 && msgTime < (anchor - 4)) {
      return;
    }

    if (kind == 'BUMP_OFFER') {
      final peerTeam = _parsePeerParty(payload['party']);
      if (peerTeam.isEmpty) return;

      final String peerNonce = _sanitizeTopicToken(
        (payload['offerNonce'] as String?) ?? '${msgTime}_$senderId',
      );
      final String oppName = (payload['trainerName'] as String?) ?? 'Trainer';
      final String oppTitle = (payload['trainerTitle'] as String?) ?? 'Trainer';
      final String oppSprite =
          (payload['avatarId'] as String?) ?? 'male_red';

      late final String matchId;
      late final bool isHost;

      if (_searchingBump && _activeOfferNonce != null) {
        // Simultaneous bump: deterministic tie-break determines host & canonical matchId.
        isHost = myDeviceId.compareTo(senderId) < 0;
        final String hostId = isHost ? myDeviceId : senderId;
        final String guestId = isHost ? senderId : myDeviceId;
        final String hostNonce =
            _sanitizeTopicToken(isHost ? _activeOfferNonce! : peerNonce);
        matchId = 'm_${hostId}_${guestId}_$hostNonce';

        final acceptPayload = _buildOfferOrAcceptPayload(
          kind: 'BUMP_ACCEPT',
          offerNonce: peerNonce,
          targetId: senderId,
          matchId: matchId,
        );
        unawaited(_postLobby(acceptPayload));
      } else {
        // Peer bumped while this phone was actively scanning on BumpScreen.
        isHost = false;
        matchId = 'm_${senderId}_${myDeviceId}_$peerNonce';

        final acceptPayload = _buildOfferOrAcceptPayload(
          kind: 'BUMP_ACCEPT',
          offerNonce: peerNonce,
          targetId: senderId,
          matchId: matchId,
        );
        unawaited(_postLobby(acceptPayload));
      }

      _finalizeMatch(
        matchId: matchId,
        peerDeviceId: senderId,
        isHost: isHost,
        opponentName: oppName,
        opponentTitle: oppTitle,
        opponentSpriteId: oppSprite,
        opponentTeam: peerTeam,
      );
      return;
    }

    if (kind == 'BUMP_ACCEPT') {
      final String? targetId = payload['targetId'] as String?;
      if (targetId != myDeviceId || !_searchingBump) return;

      final peerTeam = _parsePeerParty(payload['party']);
      if (peerTeam.isEmpty) return;

      final String matchId = (payload['matchId'] as String?) ?? '';
      if (matchId.isEmpty) return;

      final bool isHost = matchId.startsWith('m_${myDeviceId}_');
      _finalizeMatch(
        matchId: matchId,
        peerDeviceId: senderId,
        isHost: isHost,
        opponentName: (payload['trainerName'] as String?) ?? 'Trainer',
        opponentTitle: (payload['trainerTitle'] as String?) ?? 'Trainer',
        opponentSpriteId: (payload['avatarId'] as String?) ?? 'male_red',
        opponentTeam: peerTeam,
      );
    }
  }

  void _pruneStaleNearby() {
    if (_latestServerTime > 0) {
      _nearbyTrainers.removeWhere(
        (_, entry) => (_latestServerTime - entry.lastServerTime) > 15,
      );
    }
    onNearbyChanged?.call(_nearbyTrainers.values.toList());
  }

  void _finalizeMatch({
    required String matchId,
    required String peerDeviceId,
    required bool isHost,
    required String opponentName,
    required String opponentTitle,
    required String opponentSpriteId,
    required List<PokemonInstance> opponentTeam,
  }) {
    if (_disposed || _matched) return;
    _matched = true;
    _searchingBump = false;
    _offerTimeoutTimer?.cancel();
    _offerRetryTimer?.cancel();
    _heartbeatTimer?.cancel();
    _pollTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _ws?.close();
    _ws = null;

    final session = PvpMatchSession(
      matchId: matchId,
      myDeviceId: myDeviceId,
      peerDeviceId: peerDeviceId,
      isHost: isHost,
      opponentName: opponentName,
      opponentTitle: opponentTitle,
      opponentSpriteId: opponentSpriteId,
      opponentTeam: opponentTeam,
    );
    session.startListening();
    onMatched(session);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _searchingBump = false;
    _offerTimeoutTimer?.cancel();
    _offerRetryTimer?.cancel();
    _heartbeatTimer?.cancel();
    _pollTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _ws?.close();
    _ws = null;
  }
}
