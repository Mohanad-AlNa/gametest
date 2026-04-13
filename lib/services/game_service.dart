import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../data/categories.dart';

// ─── Enums ───────────────────────────────────────────────────────────────────

enum GamePhase {
  idle,
  lobby,
  countdown,
  playing,
  reviewing,
  finalResults,
}

// ─── Models ──────────────────────────────────────────────────────────────────

class PlayerInfo {
  final String id;
  final String name;
  bool isReady;
  bool isHost;
  int score;
  bool hasAnswered;

  PlayerInfo({
    required this.id,
    required this.name,
    this.isReady = false,
    this.isHost = false,
    this.score = 0,
    this.hasAnswered = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isReady': isReady,
        'isHost': isHost,
        'score': score,
        'hasAnswered': hasAnswered,
      };

  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
        id: j['id'],
        name: j['name'],
        isReady: j['isReady'] ?? false,
        isHost: j['isHost'] ?? false,
        score: j['score'] ?? 0,
        hasAnswered: j['hasAnswered'] ?? false,
      );
}

class AnswerGroup {
  final String answer;
  final List<String> playerIds;
  final int pointsEarned;
  final int colorIndex;

  AnswerGroup({
    required this.answer,
    required this.playerIds,
    required this.pointsEarned,
    required this.colorIndex,
  });

  factory AnswerGroup.fromJson(Map<String, dynamic> j) => AnswerGroup(
        answer: j['answer'],
        playerIds: List<String>.from(j['playerIds']),
        pointsEarned: j['pointsEarned'],
        colorIndex: j['colorIndex'],
      );

  Map<String, dynamic> toJson() => {
        'answer': answer,
        'playerIds': playerIds,
        'pointsEarned': pointsEarned,
        'colorIndex': colorIndex,
      };
}

// ─── Game Service ─────────────────────────────────────────────────────────────

class GameService extends ChangeNotifier {
  // ── Server state ──
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final Map<String, String> _socketToPlayerId = {};

  // ── Client state ──
  WebSocket? _socket;
  bool _isHost = false;
  String _localIp = '';

  // ── Game state ──
  String _myId = '';
  String _myName = '';
  GamePhase _phase = GamePhase.idle;
  List<PlayerInfo> _players = [];
  int _currentRound = 0;
  int _totalRounds = 5;
  String _currentCategory = '';
  String _currentHint = '';
  String _currentEmoji = '';
  int _timeLeft = 30;
  Map<String, String> _answers = {};
  List<AnswerGroup> _answerGroups = [];
  String _errorMessage = '';
  Timer? _roundTimer;
  List<Map<String, String>> _roundCategories = [];

  // ─── Getters ─────────────────────────────────────────────────────────────

  bool get isHost => _isHost;
  String get localIp => _localIp;
  String get myId => _myId;
  String get myName => _myName;
  GamePhase get phase => _phase;
  List<PlayerInfo> get players => List.unmodifiable(_players);
  int get currentRound => _currentRound;
  int get totalRounds => _totalRounds;
  String get currentCategory => _currentCategory;
  String get currentHint => _currentHint;
  String get currentEmoji => _currentEmoji;
  int get timeLeft => _timeLeft;
  Map<String, String> get answers => Map.unmodifiable(_answers);
  List<AnswerGroup> get answerGroups => List.unmodifiable(_answerGroups);
  String get errorMessage => _errorMessage;
  PlayerInfo? get myPlayer =>
      _players.where((p) => p.id == _myId).isEmpty ? null : _players.firstWhere((p) => p.id == _myId);
  bool get canStartGame => _isHost && _players.length >= 2;
  int get answeredCount => _players.where((p) => p.hasAnswered).length;

  // ─── Host: Create Lobby ──────────────────────────────────────────────────

  Future<bool> createLobby(String playerName, {int rounds = 5}) async {
    _myName = playerName;
    _totalRounds = rounds;
    _isHost = true;
    _errorMessage = '';

    try {
      _localIp = await _getLocalIp();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 4567, shared: true);
      _listenToServer();
      // Host connects as client via loopback
      await _connectToServer('127.0.0.1', playerName);
      return true;
    } catch (e) {
      _errorMessage = 'فشل إنشاء الغرفة: $e';
      _isHost = false;
      notifyListeners();
      return false;
    }
  }

  void _listenToServer() {
    _server!.transform(WebSocketTransformer()).listen(
      (WebSocket clientSocket) {
        _clients.add(clientSocket);
        clientSocket.listen(
          (data) => _handleClientMessage(clientSocket, data),
          onDone: () => _handleClientDisconnect(clientSocket),
          onError: (_) => _handleClientDisconnect(clientSocket),
        );
      },
      onError: (e) => debugPrint('Server error: $e'),
    );
  }

  void _handleClientMessage(WebSocket socket, dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = msg['type'] as String;

      switch (type) {
        case 'join':
          _serverHandleJoin(socket, msg);
          break;
        case 'start_game':
          _serverHandleStartGame(msg);
          break;
        case 'submit_answer':
          _serverHandleAnswer(socket, msg);
          break;
        case 'next_round':
          _serverHandleNextRound();
          break;
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }

  void _serverHandleJoin(WebSocket socket, Map<String, dynamic> msg) {
    if (_phase != GamePhase.lobby && _phase != GamePhase.idle) return;
    final name = msg['name'] as String;
    final id = 'p${DateTime.now().millisecondsSinceEpoch}${_clients.indexOf(socket)}';
    final isFirst = _players.isEmpty;
    _socketToPlayerId[socket.hashCode.toString()] = id;
    _players.add(PlayerInfo(id: id, name: name, isHost: isFirst));
    _phase = GamePhase.lobby;
    _broadcastPlayerList();
    // Tell the socket its own id
    _sendTo(socket, {'type': 'joined', 'id': id, 'isHost': isFirst});
  }

  void _serverHandleStartGame(Map<String, dynamic> msg) {
    if (!_isHost || _players.length < 2) return;
    _roundCategories = getShuffledCategories(_totalRounds);
    _currentRound = 0;
    _broadcast({'type': 'game_started', 'totalRounds': _totalRounds});
    _serverStartNextRound();
  }

  void _serverStartNextRound() {
    _currentRound++;
    if (_currentRound > _totalRounds) {
      _serverEndGame();
      return;
    }
    // Reset answers
    for (var p in _players) {
      p.hasAnswered = false;
    }
    _answers.clear();
    final catData = _roundCategories[_currentRound - 1];
    _broadcast({
      'type': 'new_round',
      'round': _currentRound,
      'totalRounds': _totalRounds,
      'category': catData['category'],
      'hint': catData['hint'],
      'emoji': catData['emoji'],
      'timeLimit': 30,
    });
    // Server-side timer
    _roundTimer?.cancel();
    int timeLeft = 30;
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      timeLeft--;
      _broadcast({'type': 'timer', 'timeLeft': timeLeft});
      if (timeLeft <= 0) {
        t.cancel();
        _serverCalculateResults();
      }
    });
  }

  void _serverHandleAnswer(WebSocket socket, Map<String, dynamic> msg) {
    final id = _socketToPlayerId[socket.hashCode.toString()];
    if (id == null) return;
    if (_answers.containsKey(id)) return; // already answered
    final answer = (msg['answer'] as String).trim().toLowerCase();
    _answers[id] = answer;
    final player = _players.firstWhere((p) => p.id == id, orElse: () => PlayerInfo(id: '', name: ''));
    if (player.id.isNotEmpty) player.hasAnswered = true;
    _broadcast({'type': 'answer_count', 'count': _answers.length, 'total': _players.length});
    if (_answers.length >= _players.length) {
      _roundTimer?.cancel();
      _serverCalculateResults();
    }
  }

  void _serverHandleNextRound() {
    _serverStartNextRound();
  }

  void _serverCalculateResults() {
    // Group answers
    final groups = <String, List<String>>{};
    _answers.forEach((playerId, answer) {
      groups.putIfAbsent(answer, () => []).add(playerId);
    });

    // Calculate points and build AnswerGroup list
    final answerGroups = <Map<String, dynamic>>[];
    int colorIdx = 0;
    groups.forEach((answer, ids) {
      final points = ids.length >= 2 ? ids.length * 10 : 0;
      for (final id in ids) {
        final p = _players.firstWhere((pp) => pp.id == id, orElse: () => PlayerInfo(id: '', name: ''));
        if (p.id.isNotEmpty) p.score += points;
      }
      answerGroups.add({
        'answer': answer,
        'playerIds': ids,
        'pointsEarned': ids.length >= 2 ? ids.length * 10 : 0,
        'colorIndex': ids.length >= 2 ? colorIdx++ % 8 : -1,
      });
    });

    // Build score map
    final scores = <String, int>{};
    for (var p in _players) {
      scores[p.id] = p.score;
    }

    _broadcast({
      'type': 'round_results',
      'round': _currentRound,
      'answers': _answers,
      'groups': answerGroups,
      'scores': scores,
    });
  }

  void _serverEndGame() {
    final scores = <String, int>{};
    for (var p in _players) {
      scores[p.id] = p.score;
    }
    _broadcast({'type': 'game_over', 'scores': scores});
  }

  void _broadcast(Map<String, dynamic> msg) {
    final data = jsonEncode(msg);
    for (final c in List.from(_clients)) {
      try {
        c.add(data);
      } catch (_) {}
    }
  }

  void _sendTo(WebSocket socket, Map<String, dynamic> msg) {
    try {
      socket.add(jsonEncode(msg));
    } catch (_) {}
  }

  void _broadcastPlayerList() {
    _broadcast({
      'type': 'player_list',
      'players': _players.map((p) => p.toJson()).toList(),
    });
  }

  void _handleClientDisconnect(WebSocket socket) {
    final id = _socketToPlayerId.remove(socket.hashCode.toString());
    if (id != null) {
      _players.removeWhere((p) => p.id == id);
      _clients.remove(socket);
      if (_phase == GamePhase.lobby) _broadcastPlayerList();
    }
  }

  // ─── Client: Join Lobby ──────────────────────────────────────────────────

  Future<bool> joinLobby(String ip, String playerName) async {
    _myName = playerName;
    _isHost = false;
    _errorMessage = '';
    try {
      await _connectToServer(ip.trim(), playerName);
      return true;
    } catch (e) {
      _errorMessage = 'تعذّر الاتصال بالغرفة. تأكد من عنوان IP';
      notifyListeners();
      return false;
    }
  }

  Future<void> _connectToServer(String ip, String name) async {
    _socket = await WebSocket.connect('ws://$ip:4567').timeout(const Duration(seconds: 5));
    _socket!.listen(
      _handleServerMessage,
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
    );
    _send({'type': 'join', 'name': name});
  }

  void _handleServerMessage(dynamic data) {
    try {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final type = msg['type'] as String;

      switch (type) {
        case 'joined':
          _myId = msg['id'] as String;
          _phase = GamePhase.lobby;
          break;
        case 'player_list':
          _players = (msg['players'] as List)
              .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
              .toList();
          break;
        case 'game_started':
          _totalRounds = msg['totalRounds'] as int;
          _phase = GamePhase.countdown;
          break;
        case 'new_round':
          _currentRound = msg['round'] as int;
          _totalRounds = msg['totalRounds'] as int;
          _currentCategory = msg['category'] as String;
          _currentHint = msg['hint'] as String;
          _currentEmoji = msg['emoji'] as String;
          _timeLeft = msg['timeLimit'] as int;
          _answers.clear();
          _answerGroups.clear();
          _phase = GamePhase.playing;
          break;
        case 'timer':
          _timeLeft = msg['timeLeft'] as int;
          break;
        case 'answer_count':
          final count = msg['count'] as int;
          for (int i = 0; i < _players.length; i++) {
            _players[i].hasAnswered = i < count;
          }
          break;
        case 'round_results':
          final rawAnswers = msg['answers'] as Map<String, dynamic>;
          _answers = rawAnswers.map((k, v) => MapEntry(k, v as String));
          _answerGroups = (msg['groups'] as List)
              .map((g) => AnswerGroup.fromJson(g as Map<String, dynamic>))
              .toList();
          final scores = msg['scores'] as Map<String, dynamic>;
          for (var p in _players) {
            p.score = scores[p.id] as int? ?? p.score;
          }
          _phase = GamePhase.reviewing;
          break;
        case 'game_over':
          final scores = msg['scores'] as Map<String, dynamic>;
          for (var p in _players) {
            p.score = scores[p.id] as int? ?? p.score;
          }
          _phase = GamePhase.finalResults;
          break;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error parsing server message: $e');
    }
  }

  void _handleDisconnect() {
    _phase = GamePhase.idle;
    _errorMessage = 'انقطع الاتصال بالغرفة';
    notifyListeners();
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _socket?.add(jsonEncode(msg));
    } catch (_) {}
  }

  // ─── Game Actions ─────────────────────────────────────────────────────────

  void startGame() {
    if (!_isHost) return;
    _send({'type': 'start_game'});
  }

  void submitAnswer(String answer) {
    if (answer.trim().isEmpty) return;
    _send({'type': 'submit_answer', 'answer': answer.trim()});
    // Optimistically mark as answered
    final p = _players.firstWhere((pp) => pp.id == _myId, orElse: () => PlayerInfo(id: '', name: ''));
    if (p.id.isNotEmpty) {
      p.hasAnswered = true;
      notifyListeners();
    }
  }

  void nextRound() {
    if (!_isHost) return;
    _send({'type': 'next_round'});
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _roundTimer?.cancel();
    _roundTimer = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    for (final c in _clients) {
      try {
        await c.close();
      } catch (_) {}
    }
    _clients.clear();
    _socketToPlayerId.clear();
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _players.clear();
    _answers.clear();
    _answerGroups.clear();
    _phase = GamePhase.idle;
    _isHost = false;
    _myId = '';
    _currentRound = 0;
    _errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
