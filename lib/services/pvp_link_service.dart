import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pokemon_instance.dart';
import '../models/trainer.dart';
import 'pvp_transport.dart';

class PvpDeviceIdentity {
  static const String _prefsKey = 'pocket_bump_device_id';
  static String? _deviceId;

  static Future<void> loadOrInit() async {
    if (_deviceId != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey)?.trim();
      if (saved != null && saved.isNotEmpty) {
        _deviceId = saved;
        return;
      }
      final generated = _generate();
      _deviceId = generated;
      await prefs.setString(_prefsKey, generated);
    } catch (_) {
      _deviceId ??= _generate();
    }
  }

  static String _generate() {
    final rng = Random();
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final buf = StringBuffer('d');
    for (int i = 0; i < 10; i++) {
      buf.write(chars[rng.nextInt(chars.length)]);
    }
    return buf.toString();
  }

  static String get id {
    _deviceId ??= _generate();
    return _deviceId!;
  }
}

enum BumpLinkMode {
  battle,
  doubleBattle,
  trade,
}

extension BumpLinkModeExt on BumpLinkMode {
  bool get isBattle =>
      this == BumpLinkMode.battle || this == BumpLinkMode.doubleBattle;
  bool get isDoubleBattle => this == BumpLinkMode.doubleBattle;
  String get displayLabel {
    switch (this) {
      case BumpLinkMode.battle:
        return 'Singles Battle';
      case BumpLinkMode.doubleBattle:
        return 'Doubles Battle';
      case BumpLinkMode.trade:
        return 'Trade';
    }
  }
}

BumpLinkMode parseBumpLinkMode(String? raw) {
  switch (raw) {
    case 'trade':
      return BumpLinkMode.trade;
    case 'doubleBattle':
      return BumpLinkMode.doubleBattle;
    default:
      return BumpLinkMode.battle;
  }
}

class NearbyRadarTrainer {
  final String deviceId;
  final String name;
  final String title;
  final int partyCount;
  final BumpLinkMode mode;
  final int lastServerTime;

  const NearbyRadarTrainer({
    required this.deviceId,
    required this.name,
    required this.title,
    required this.partyCount,
    this.mode = BumpLinkMode.battle,
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
  final BumpLinkMode mode;

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
    this.mode = BumpLinkMode.battle,
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

class PvpTradeSession {
  static const String _baseHttp = 'https://ntfy.sh';
  static const String _baseWss = 'wss://ntfy.sh';

  final String matchId;
  final String myDeviceId;
  final String peerDeviceId;
  final String partnerName;
  final String partnerTitle;
  final String partnerSpriteId;

  VoidCallback? onStateChanged;
  VoidCallback? onPeerLeft;
  void Function(int partyIndex, PokemonInstance receivedMon)? onTradeExecute;

  late final String _topic;
  PvpWsChannel? _ws;
  Timer? _wsReconnectTimer;
  Timer? _pollTimer;
  Timer? _confirmRetryTimer;
  bool _listening = false;
  bool _disposed = false;
  bool _pollInFlight = false;
  bool _peerLeft = false;

  final Set<String> _seenMessageIds = {};

  int _round = 1;
  int _mySeq = 0;
  int _peerSeq = 0;
  int? _myPartyIndex;
  PokemonInstance? _myOffer;
  PokemonInstance? _peerOffer;

  bool _myConfirmed = false;
  bool _peerConfirmed = false;
  int? _myConfirmedSelfSeq;
  int? _myConfirmedPeerSeq;
  int? _peerConfirmedSelfSeq;
  int? _peerConfirmedTargetSeq;
  bool _tradeExecuted = false;

  // Buffer latest higher-round peer offer/confirm while local side finishes animations
  final Map<int, Map<String, dynamic>> _pendingNextRoundOffers = {};

  PvpTradeSession({
    required this.matchId,
    required this.myDeviceId,
    required this.peerDeviceId,
    required this.partnerName,
    required this.partnerTitle,
    required this.partnerSpriteId,
  }) {
    _topic = 'pocket_bump_trade_${_sanitizeTopicToken(matchId)}';
  }

  factory PvpTradeSession.fromMatch(PvpMatchSession match) {
    return PvpTradeSession(
      matchId: match.matchId,
      myDeviceId: match.myDeviceId,
      peerDeviceId: match.peerDeviceId,
      partnerName: match.opponentName,
      partnerTitle: match.opponentTitle,
      partnerSpriteId: match.opponentSpriteId,
    );
  }

  int get round => _round;
  int? get myPartyIndex => _myPartyIndex;
  PokemonInstance? get myOffer => _myOffer;
  PokemonInstance? get peerOffer => _peerOffer;
  bool get myConfirmed => _myConfirmed;
  bool get peerConfirmed => _peerConfirmed;
  bool get tradeExecuted => _tradeExecuted;
  bool get isPeerLeft => _peerLeft;

  void startListening() {
    if (_listening || _disposed) return;
    _listening = true;
    _openWebSocket();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!_disposed) _pollRoom();
    });
    unawaited(_pollRoom());
  }

  void _openWebSocket() {
    if (_disposed) return;
    _ws?.close();
    _ws = connectWebSocket(
      '$_baseWss/$_topic/ws',
      onMessage: _handleRawEnvelope,
      onClosed: () {
        if (!_disposed && _listening) {
          _wsReconnectTimer?.cancel();
          _wsReconnectTimer = Timer(const Duration(seconds: 2), _openWebSocket);
        }
      },
    );
  }

  void selectOffer(int partyIndex, PokemonInstance mon) {
    if (_disposed || _tradeExecuted) return;
    _mySeq++;
    _myPartyIndex = partyIndex;
    _myOffer = PokemonInstance.fromJson(mon.toJson());
    _resetConfirmations();
    onStateChanged?.call();

    unawaited(_postRoom(<String, dynamic>{
      'kind': 'TRADE_OFFER',
      'senderId': myDeviceId,
      'round': _round,
      'seq': _mySeq,
      'mon': _myOffer!.toJson(),
    }));
  }

  void lockConfirmation() {
    if (_disposed || _tradeExecuted) return;
    if (_myOffer == null || _peerOffer == null) return;
    _myConfirmed = true;
    _myConfirmedSelfSeq = _mySeq;
    _myConfirmedPeerSeq = _peerSeq;
    onStateChanged?.call();
    _sendConfirmPacket();
    _confirmRetryTimer?.cancel();
    _confirmRetryTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (_disposed || _tradeExecuted || !_myConfirmed) {
        _confirmRetryTimer?.cancel();
        return;
      }
      _sendConfirmPacket();
    });
    _checkAndExecuteTrade();
  }

  void unlockConfirmation() {
    if (_disposed || _tradeExecuted || !_myConfirmed) return;
    _myConfirmed = false;
    _myConfirmedSelfSeq = null;
    _myConfirmedPeerSeq = null;
    _confirmRetryTimer?.cancel();
    onStateChanged?.call();
    unawaited(_postRoom(<String, dynamic>{
      'kind': 'TRADE_UNCONFIRM',
      'senderId': myDeviceId,
      'round': _round,
    }));
  }

  void _sendConfirmPacket() {
    if (_disposed || !_myConfirmed) return;
    unawaited(_postRoom(<String, dynamic>{
      'kind': 'TRADE_CONFIRM',
      'senderId': myDeviceId,
      'round': _round,
      'senderSeq': _myConfirmedSelfSeq,
      'targetSeq': _myConfirmedPeerSeq,
    }));
  }

  void startNextTradeRound() {
    if (_disposed) return;
    _confirmRetryTimer?.cancel();
    _round++;
    _mySeq = 0;
    _peerSeq = 0;
    _myPartyIndex = null;
    _myOffer = null;
    _peerOffer = null;
    _tradeExecuted = false;
    _resetConfirmations();

    final cached = _pendingNextRoundOffers.remove(_round);
    if (cached != null) {
      _applyPeerOfferPayload(cached);
    }
    onStateChanged?.call();
  }

  void sendLeave() {
    if (_disposed) return;
    unawaited(_postRoom(<String, dynamic>{
      'kind': 'TRADE_LEAVE',
      'senderId': myDeviceId,
    }));
  }

  void _resetConfirmations() {
    _confirmRetryTimer?.cancel();
    _myConfirmed = false;
    _peerConfirmed = false;
    _myConfirmedSelfSeq = null;
    _myConfirmedPeerSeq = null;
    _peerConfirmedSelfSeq = null;
    _peerConfirmedTargetSeq = null;
  }

  Future<void> _postRoom(Map<String, dynamic> payload) async {
    if (_disposed) return;
    final resp = await httpPostString(
      '$_baseHttp/$_topic',
      jsonEncode(payload),
    );
    if (resp != null && resp.isNotEmpty) {
      try {
        final decoded = jsonDecode(resp);
        if (decoded is Map && decoded['id'] is String) {
          _seenMessageIds.add(decoded['id'] as String);
        }
      } catch (_) {}
    }
  }

  Future<void> _pollRoom() async {
    if (_disposed || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final body = await httpGetString('$_baseHttp/$_topic/json?poll=1&since=all');
      if (body == null || body.isEmpty || _disposed) return;
      for (final line in LineSplitter.split(body)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        _handleRawEnvelope(trimmed);
      }
    } catch (_) {
    } finally {
      _pollInFlight = false;
    }
  }

  void _handleRawEnvelope(String raw) {
    if (_disposed) return;
    try {
      final env = jsonDecode(raw);
      if (env is! Map || env['event'] != 'message') return;
      final id = env['id'] as String?;
      if (id != null && !_seenMessageIds.add(id)) return;

      final msgStr = env['message'] as String?;
      if (msgStr == null || msgStr.isEmpty) return;
      final rawPayload = jsonDecode(msgStr);
      if (rawPayload is! Map) return;
      final payload = Map<String, dynamic>.from(rawPayload);

      final String? senderId = payload['senderId'] as String?;
      if (senderId == null || senderId == myDeviceId) return;

      final String? kind = payload['kind'] as String?;
      if (kind == 'TRADE_LEAVE') {
        _peerLeft = true;
        onPeerLeft?.call();
        return;
      }

      final int msgRound = (payload['round'] as num?)?.toInt() ?? 1;
      if (msgRound < _round) return;
      if (msgRound > _round) {
        if (kind == 'TRADE_OFFER') {
          _pendingNextRoundOffers[msgRound] = payload;
        }
        return;
      }
      if (_tradeExecuted) return;

      if (kind == 'TRADE_OFFER') {
        _applyPeerOfferPayload(payload);
        onStateChanged?.call();
      } else if (kind == 'TRADE_UNCONFIRM') {
        _peerConfirmed = false;
        _peerConfirmedSelfSeq = null;
        _peerConfirmedTargetSeq = null;
        onStateChanged?.call();
      } else if (kind == 'TRADE_CONFIRM') {
        final int pSelfSeq = (payload['senderSeq'] as num?)?.toInt() ?? -1;
        final int pTargetSeq = (payload['targetSeq'] as num?)?.toInt() ?? -1;
        if (pSelfSeq == _peerSeq && pTargetSeq == _mySeq) {
          _peerConfirmed = true;
          _peerConfirmedSelfSeq = pSelfSeq;
          _peerConfirmedTargetSeq = pTargetSeq;
          onStateChanged?.call();
          _checkAndExecuteTrade();
        }
      }
    } catch (_) {}
  }

  void _applyPeerOfferPayload(Map<String, dynamic> payload) {
    final int seq = (payload['seq'] as num?)?.toInt() ?? 0;
    if (seq <= _peerSeq) return;
    final rawMon = payload['mon'];
    if (rawMon is! Map) return;
    final mon = PokemonInstance.fromJson(Map<String, dynamic>.from(rawMon));
    _peerSeq = seq;
    _peerOffer = mon;
    _resetConfirmations();
  }

  void _checkAndExecuteTrade() {
    if (_tradeExecuted ||
        !_myConfirmed ||
        !_peerConfirmed ||
        _myPartyIndex == null ||
        _myOffer == null ||
        _peerOffer == null) {
      return;
    }
    final bool seqsAligned = _myConfirmedSelfSeq == _mySeq &&
        _myConfirmedPeerSeq == _peerSeq &&
        _peerConfirmedSelfSeq == _peerSeq &&
        _peerConfirmedTargetSeq == _mySeq;
    if (!seqsAligned) return;

    _tradeExecuted = true;
    _confirmRetryTimer?.cancel();
    onTradeExecute?.call(_myPartyIndex!, _peerOffer!);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _confirmRetryTimer?.cancel();
    _pollTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _ws?.close();
    _ws = null;
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
  BumpLinkMode mode;

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
    this.mode = BumpLinkMode.battle,
  }) {
    myDeviceId = PvpDeviceIdentity.id;
  }

  void setMode(BumpLinkMode newMode) {
    if (mode == newMode || _disposed || _matched) return;
    mode = newMode;
    cancelBumpOffer();
    if (_started) {
      unawaited(_sendPresence());
    }
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
      'mode': mode.name,
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
      'mode': mode.name,
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
    final BumpLinkMode payloadMode =
        parseBumpLinkMode(payload['mode'] as String?);
    if (kind == 'RADAR_PRESENCE') {
      _nearbyTrainers[senderId] = NearbyRadarTrainer(
        deviceId: senderId,
        name: (payload['trainerName'] as String?) ?? 'Trainer',
        title: (payload['trainerTitle'] as String?) ?? 'Trainer',
        partyCount: (payload['partyCount'] as num?)?.toInt() ?? 1,
        mode: payloadMode,
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
      if (payloadMode != mode) return;
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
      if (payloadMode != mode) return;
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
      mode: mode,
    );
    if (mode.isBattle) {
      session.startListening();
    }
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
