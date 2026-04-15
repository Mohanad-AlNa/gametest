import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../data/categories.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum GameMode { telepathy, zombie }

enum GamePhase {
  idle,
  lobby,
  countdown,
  playing,
  reviewing,
  finalResults,
  zombieRoleReveal,
  zombieNightPhase,
  zombieMorningReveal,
  zombieGameOver,
}

enum ZombieRole { human, zombie }

// ─── Models ───────────────────────────────────────────────────────────────────

class PlayerInfo {
  final String id;
  final String name;
  String avatar;
  bool isReady;
  bool isHost;
  int score;
  bool hasAnswered;
  bool isEliminated;
  bool canVaccine;
  bool revealUsed;

  PlayerInfo({
    required this.id,
    required this.name,
    this.avatar = '🧠',
    this.isReady = false,
    this.isHost = false,
    this.score = 0,
    this.hasAnswered = false,
    this.isEliminated = false,
    this.canVaccine = false,
    this.revealUsed = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'isReady': isReady,
        'isHost': isHost,
        'score': score,
        'hasAnswered': hasAnswered,
        'isEliminated': isEliminated,
        'canVaccine': canVaccine,
        'revealUsed': revealUsed,
      };

  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        avatar: j['avatar'] as String? ?? '🧠',
        isReady: j['isReady'] as bool? ?? false,
        isHost: j['isHost'] as bool? ?? false,
        score: j['score'] as int? ?? 0,
        hasAnswered: j['hasAnswered'] as bool? ?? false,
        isEliminated: j['isEliminated'] as bool? ?? false,
        canVaccine: j['canVaccine'] as bool? ?? false,
        revealUsed: j['revealUsed'] as bool? ?? false,
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
        answer: j['answer'] as String,
        playerIds: List<String>.from(j['playerIds'] as List),
        pointsEarned: j['pointsEarned'] as int,
        colorIndex: j['colorIndex'] as int,
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
  final Map<String, String> _playerIdToSocket = {};

  // ── Client state ──
  WebSocket? _socket;
  bool _isHost = false;
  String _localIp = '';

  // ── Game state ──
  String _myId = '';
  String _myName = '';
  String _myAvatar = '🧠';
  GamePhase _phase = GamePhase.idle;
  GameMode _gameMode = GameMode.telepathy;
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

  // ── Zombie state (client-side) ──
  ZombieRole? _myZombieRole;
  String _zombieRevealedName = '';
  ZombieRole? _zombieRevealedRole;
  List<Map<String, dynamic>> _morningEvents = [];
  String _zombieWinner = '';
  bool _myActionSubmitted = false;

  // ── Server-side zombie private state ──
  Map<String, ZombieRole> _serverZombieRoles = {};
  Map<String, Map<String, dynamic>> _serverNightActions = {};

  // ─── Getters ──────────────────────────────────────────────────────────────

  bool get isHost => _isHost;
  String get localIp => _localIp;
  String get myId => _myId;
  String get myName => _myName;
  String get myAvatar => _myAvatar;
  GamePhase get phase => _phase;
  GameMode get gameMode => _gameMode;
  ZombieRole? get myZombieRole => _myZombieRole;
  String get zombieRevealedName => _zombieRevealedName;
  ZombieRole? get zombieRevealedRole => _zombieRevealedRole;
  List<Map<String, dynamic>> get morningEvents => List.unmodifiable(_morningEvents);
  String get zombieWinner => _zombieWinner;
  bool get myActionSubmitted => _myActionSubmitted;
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
      _players.where((p) => p.id == _myId).isEmpty
          ? null
          : _players.firstWhere((p) => p.id == _myId);
  bool get canStartGame => _isHost && _players.length >= 2;
  int get answeredCount => _players.where((p) => p.hasAnswered).length;

  // ─── Host: Create Lobby ───────────────────────────────────────────────────

  Future<bool> createLobby(
    String playerName, {
    int rounds = 5,
    String avatar = '🧠',
    GameMode gameMode = GameMode.telepathy,
  }) async {
    _myName = playerName;
    _myAvatar = avatar;
    _totalRounds = rounds;
    _gameMode = gameMode;
    _isHost = true;
    _errorMessage = '';

    try {
      _localIp = await _getLocalIp();
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 4567, shared: true);
      _listenToServer();
      await _connectToServer('127.0.0.1', playerName, avatar);
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
        case 'zombie_night_action':
          _serverHandleZombieNightAction(socket, msg);
          break;
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }

  void _serverHandleJoin(WebSocket socket, Map<String, dynamic> msg) {
    if (_phase != GamePhase.lobby && _phase != GamePhase.idle) return;
    final name = msg['name'] as String;
    final avatar = msg['avatar'] as String? ?? '🧠';
    final id = 'p${DateTime.now().millisecondsSinceEpoch}${_clients.indexOf(socket)}';
    final isFirst = _players.isEmpty;
    final socketKey = socket.hashCode.toString();
    _socketToPlayerId[socketKey] = id;
    _playerIdToSocket[id] = socketKey;
    _players.add(PlayerInfo(id: id, name: name, avatar: avatar, isHost: isFirst));
    _phase = GamePhase.lobby;
    _broadcastPlayerList();
    _sendTo(socket, {'type': 'joined', 'id': id, 'isHost': isFirst});
  }

  void _serverHandleStartGame(Map<String, dynamic> msg) {
    if (!_isHost || _players.length < 2) return;
    final modeStr = msg['mode'] as String? ?? 'telepathy';
    if (modeStr == 'zombie') {
      _gameMode = GameMode.zombie;
      _serverStartZombieGame();
    } else {
      _gameMode = GameMode.telepathy;
      _roundCategories = getShuffledCategories(_totalRounds);
      _currentRound = 0;
      _broadcast({'type': 'game_started', 'totalRounds': _totalRounds});
      _serverStartNextRound();
    }
  }

  // ─── Telepathy server logic ───────────────────────────────────────────────

  void _serverStartNextRound() {
    _currentRound++;
    if (_currentRound > _totalRounds) {
      _serverEndGame();
      return;
    }
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
    if (_answers.containsKey(id)) return;
    final answer = (msg['answer'] as String).trim().toLowerCase();
    _answers[id] = answer;
    final player = _players.firstWhere(
      (p) => p.id == id,
      orElse: () => PlayerInfo(id: '', name: ''),
    );
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
    final groups = <String, List<String>>{};
    _answers.forEach((playerId, answer) {
      groups.putIfAbsent(answer, () => []).add(playerId);
    });

    final answerGroups = <Map<String, dynamic>>[];
    int colorIdx = 0;
    groups.forEach((answer, ids) {
      final points = ids.length >= 2 ? ids.length * 10 : 0;
      for (final id in ids) {
        final p = _players.firstWhere(
          (pp) => pp.id == id,
          orElse: () => PlayerInfo(id: '', name: ''),
        );
        if (p.id.isNotEmpty) p.score += points;
      }
      answerGroups.add({
        'answer': answer,
        'playerIds': ids,
        'pointsEarned': ids.length >= 2 ? ids.length * 10 : 0,
        'colorIndex': ids.length >= 2 ? colorIdx++ % 8 : -1,
      });
    });

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

  // ─── Zombie server logic ──────────────────────────────────────────────────

  void _serverStartZombieGame() {
    _currentRound = 0;
    _serverZombieRoles = {};
    _serverNightActions = {};

    for (var p in _players) {
      p.isEliminated = false;
      p.canVaccine = false;
      p.revealUsed = false;
      p.score = 0;
    }

    const maxZombieCount = 3;
    final playerCount = _players.length;
    final zombieCount = min((playerCount ~/ 3) + 1, maxZombieCount);
    final shuffled = List<PlayerInfo>.from(_players)..shuffle(Random());
    for (int i = 0; i < shuffled.length; i++) {
      _serverZombieRoles[shuffled[i].id] =
          i < zombieCount ? ZombieRole.zombie : ZombieRole.human;
    }

    _broadcast({
      'type': 'game_started',
      'totalRounds': _totalRounds,
      'mode': 'zombie',
    });

    // Send private role to each player
    for (final p in _players) {
      final role = _serverZombieRoles[p.id];
      final socketKey = _playerIdToSocket[p.id];
      if (socketKey != null && role != null) {
        final socket = _clients.firstWhere(
          (c) => c.hashCode.toString() == socketKey,
          orElse: () => _clients.first,
        );
        _sendTo(socket, {
          'type': 'your_zombie_role',
          'role': role == ZombieRole.zombie ? 'zombie' : 'human',
        });
      }
    }

    _broadcast({
      'type': 'zombie_phase',
      'phase': 'roleReveal',
      'players': _players.map((p) => p.toJson()).toList(),
    });

    Timer(const Duration(seconds: 6), _serverStartZombieNight);
  }

  void _serverStartZombieNight() {
    _currentRound++;
    _serverNightActions = {};

    _broadcast({
      'type': 'zombie_phase',
      'phase': 'nightPhase',
      'round': _currentRound,
      'totalRounds': _totalRounds,
      'players': _players.map((p) => p.toJson()).toList(),
    });

    int timeLeft = 30;
    _roundTimer?.cancel();
    _roundTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      timeLeft--;
      _broadcast({'type': 'timer', 'timeLeft': timeLeft});
      if (timeLeft <= 0) {
        t.cancel();
        _serverProcessZombieNight();
      }
    });
  }

  void _serverHandleZombieNightAction(WebSocket socket, Map<String, dynamic> msg) {
    final id = _socketToPlayerId[socket.hashCode.toString()];
    if (id == null) return;
    final player = _players.firstWhere(
      (p) => p.id == id,
      orElse: () => PlayerInfo(id: '', name: ''),
    );
    if (player.id.isEmpty || player.isEliminated) return;
    if (_serverNightActions.containsKey(id)) return;

    _serverNightActions[id] = {
      'action': msg['action'] ?? 'pass',
      'targetId': msg['targetId'] ?? '',
      'playerId': id,
    };

    final alivePlayers = _players.where((p) => !p.isEliminated).toList();
    if (_serverNightActions.length >= alivePlayers.length) {
      _roundTimer?.cancel();
      _serverProcessZombieNight();
    }
  }

  void _serverProcessZombieNight() {
    final events = <Map<String, dynamic>>[];
    final newlyInfected = <String>{};
    final eliminated = <String>{};

    for (final entry in _serverNightActions.entries) {
      final actorId = entry.key;
      final action = entry.value['action'] as String;
      final targetId = entry.value['targetId'] as String;
      final actorRole = _serverZombieRoles[actorId];
      final actor = _players.firstWhere(
        (p) => p.id == actorId,
        orElse: () => PlayerInfo(id: '', name: ''),
      );
      if (actor.id.isEmpty) continue;

      if (action == 'bite' && actorRole == ZombieRole.zombie) {
        if (targetId.isNotEmpty) {
          final target = _players.firstWhere(
            (p) => p.id == targetId,
            orElse: () => PlayerInfo(id: '', name: ''),
          );
          if (target.id.isNotEmpty && !target.isEliminated) {
            final targetRole = _serverZombieRoles[targetId];
            if (targetRole == ZombieRole.human) {
              newlyInfected.add(targetId);
              events.add({'event': 'bitten', 'victimName': target.name, 'victimId': targetId});
            } else if (targetRole == ZombieRole.zombie) {
              actor.score -= 20;
              target.score -= 20;
              events.add({
                'event': 'friendly_fire',
                'zombie1Name': actor.name,
                'zombie2Name': target.name,
              });
            }
          }
        }
      } else if (action == 'reveal' && actorRole == ZombieRole.zombie && !actor.revealUsed) {
        if (targetId.isNotEmpty) {
          final target = _players.firstWhere(
            (p) => p.id == targetId,
            orElse: () => PlayerInfo(id: '', name: ''),
          );
          if (target.id.isNotEmpty) {
            actor.revealUsed = true;
            final socketKey = _playerIdToSocket[actorId];
            if (socketKey != null) {
              final socket = _clients.firstWhere(
                (c) => c.hashCode.toString() == socketKey,
                orElse: () => _clients.first,
              );
              final targetRole = _serverZombieRoles[targetId];
              _sendTo(socket, {
                'type': 'reveal_result',
                'targetName': target.name,
                'targetRole': targetRole == ZombieRole.zombie ? 'zombie' : 'human',
              });
            }
          }
        }
      } else if (action == 'shoot' && actorRole == ZombieRole.human) {
        if (targetId.isNotEmpty) {
          final target = _players.firstWhere(
            (p) => p.id == targetId,
            orElse: () => PlayerInfo(id: '', name: ''),
          );
          if (target.id.isNotEmpty && !target.isEliminated) {
            final targetRole = _serverZombieRoles[targetId];
            if (targetRole == ZombieRole.zombie) {
              eliminated.add(targetId);
              events.add({
                'event': 'shot_zombie',
                'shooterName': actor.name,
                'targetName': target.name,
              });
            } else {
              actor.score -= 20;
              target.score -= 10;
              events.add({
                'event': 'shot_human',
                'shooterName': actor.name,
                'targetName': target.name,
              });
            }
          }
        }
      } else if (action == 'vaccine' && actor.canVaccine) {
        actor.canVaccine = false;
        newlyInfected.remove(actorId);
        events.add({'event': 'vaccine', 'playerName': actor.name});
      }
    }

    // Apply infections
    for (final id in newlyInfected) {
      _serverZombieRoles[id] = ZombieRole.zombie;
      final p = _players.firstWhere(
        (pp) => pp.id == id,
        orElse: () => PlayerInfo(id: '', name: ''),
      );
      if (p.id.isNotEmpty) {
        p.canVaccine = true;
      }
    }

    // Apply eliminations
    for (final id in eliminated) {
      final p = _players.firstWhere(
        (pp) => pp.id == id,
        orElse: () => PlayerInfo(id: '', name: ''),
      );
      if (p.id.isNotEmpty) p.isEliminated = true;
    }

    if (events.isEmpty) {
      events.add({'event': 'quiet'});
    }

    // Survivor points
    for (final p in _players) {
      if (!p.isEliminated) p.score += 10;
    }

    // Check win condition
    final aliveZombies = _players
        .where((p) => !p.isEliminated && _serverZombieRoles[p.id] == ZombieRole.zombie)
        .length;
    final aliveHumans = _players
        .where((p) => !p.isEliminated && _serverZombieRoles[p.id] == ZombieRole.human)
        .length;

    bool gameOver = false;
    String? winner;

    if (aliveZombies == 0) {
      gameOver = true;
      winner = 'humans';
    } else if (aliveZombies >= aliveHumans) {
      gameOver = true;
      winner = 'zombies';
    } else if (_currentRound >= _totalRounds) {
      gameOver = true;
      winner = aliveHumans > aliveZombies
          ? 'humans'
          : aliveZombies > aliveHumans
              ? 'zombies'
              : 'draw';
    }

    final scores = <String, int>{};
    for (var p in _players) {
      scores[p.id] = p.score;
    }

    _broadcast({
      'type': 'zombie_morning_result',
      'events': events,
      'players': _players.map((p) => p.toJson()).toList(),
      'scores': scores,
      'round': _currentRound,
      'totalRounds': _totalRounds,
      'gameOver': gameOver,
      'winner': winner,
    });

    if (!gameOver) {
      Timer(const Duration(seconds: 5), _serverStartZombieNight);
    }
  }

  // ─── Broadcast / SendTo helpers ───────────────────────────────────────────

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
    final socketKey = socket.hashCode.toString();
    final id = _socketToPlayerId.remove(socketKey);
    if (id != null) {
      _playerIdToSocket.remove(id);
      _players.removeWhere((p) => p.id == id);
      _clients.remove(socket);
      if (_phase == GamePhase.lobby) _broadcastPlayerList();
    }
  }

  // ─── Client: Join Lobby ───────────────────────────────────────────────────

  Future<bool> joinLobby(String ip, String playerName, {String avatar = '🧠'}) async {
    _myName = playerName;
    _myAvatar = avatar;
    _isHost = false;
    _errorMessage = '';
    try {
      await _connectToServer(ip.trim(), playerName, avatar);
      return true;
    } catch (e) {
      _errorMessage = 'تعذّر الاتصال بالغرفة. تأكد من عنوان IP';
      notifyListeners();
      return false;
    }
  }

  Future<void> _connectToServer(String ip, String name, String avatar) async {
    _socket = await WebSocket.connect('ws://$ip:4567').timeout(const Duration(seconds: 5));
    _socket!.listen(
      _handleServerMessage,
      onDone: _handleDisconnect,
      onError: (_) => _handleDisconnect(),
    );
    _send({'type': 'join', 'name': name, 'avatar': avatar});
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
          final modeStr = msg['mode'] as String? ?? 'telepathy';
          _gameMode = modeStr == 'zombie' ? GameMode.zombie : GameMode.telepathy;
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
          final scoresR = msg['scores'] as Map<String, dynamic>;
          for (var p in _players) {
            p.score = scoresR[p.id] as int? ?? p.score;
          }
          _phase = GamePhase.reviewing;
          break;
        case 'game_over':
          final scoresG = msg['scores'] as Map<String, dynamic>;
          for (var p in _players) {
            p.score = scoresG[p.id] as int? ?? p.score;
          }
          _phase = GamePhase.finalResults;
          break;
        // Zombie messages
        case 'your_zombie_role':
          final roleStr = msg['role'] as String;
          _myZombieRole = roleStr == 'zombie' ? ZombieRole.zombie : ZombieRole.human;
          break;
        case 'zombie_phase':
          final phase = msg['phase'] as String;
          if (msg['players'] != null) {
            _players = (msg['players'] as List)
                .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
                .toList();
          }
          if (msg['round'] != null) _currentRound = msg['round'] as int;
          if (msg['totalRounds'] != null) _totalRounds = msg['totalRounds'] as int;
          switch (phase) {
            case 'roleReveal':
              _phase = GamePhase.zombieRoleReveal;
              break;
            case 'nightPhase':
              _phase = GamePhase.zombieNightPhase;
              _myActionSubmitted = false;
              _timeLeft = 30;
              break;
          }
          break;
        case 'reveal_result':
          _zombieRevealedName = msg['targetName'] as String;
          final roleStr2 = msg['targetRole'] as String;
          _zombieRevealedRole =
              roleStr2 == 'zombie' ? ZombieRole.zombie : ZombieRole.human;
          break;
        case 'zombie_morning_result':
          final rawEvents = msg['events'] as List;
          _morningEvents = rawEvents.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          if (msg['players'] != null) {
            _players = (msg['players'] as List)
                .map((p) => PlayerInfo.fromJson(p as Map<String, dynamic>))
                .toList();
          }
          final scoresM = msg['scores'] as Map<String, dynamic>;
          for (var p in _players) {
            p.score = scoresM[p.id] as int? ?? p.score;
          }
          _currentRound = msg['round'] as int;
          _totalRounds = msg['totalRounds'] as int;
          final gameOver = msg['gameOver'] as bool? ?? false;
          if (gameOver) {
            _zombieWinner = msg['winner'] as String? ?? '';
            _phase = GamePhase.zombieGameOver;
          } else {
            _phase = GamePhase.zombieMorningReveal;
          }
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

  // ─── Game Actions ──────────────────────────────────────────────────────────

  void startGame() {
    if (!_isHost) return;
    _send({
      'type': 'start_game',
      'mode': _gameMode == GameMode.zombie ? 'zombie' : 'telepathy',
    });
  }

  void submitAnswer(String answer) {
    if (answer.trim().isEmpty) return;
    _send({'type': 'submit_answer', 'answer': answer.trim()});
    final p = _players.firstWhere(
      (pp) => pp.id == _myId,
      orElse: () => PlayerInfo(id: '', name: ''),
    );
    if (p.id.isNotEmpty) {
      p.hasAnswered = true;
      notifyListeners();
    }
  }

  void nextRound() {
    if (!_isHost) return;
    _send({'type': 'next_round'});
  }

  void submitZombieAction(String action, String? targetId) {
    if (_myActionSubmitted) return;
    _myActionSubmitted = true;
    _send({'type': 'zombie_night_action', 'action': action, 'targetId': targetId ?? ''});
    notifyListeners();
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
    _playerIdToSocket.clear();
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
    _myAvatar = '🧠';
    _currentRound = 0;
    _errorMessage = '';
    _myZombieRole = null;
    _zombieRevealedName = '';
    _zombieRevealedRole = null;
    _morningEvents = [];
    _zombieWinner = '';
    _myActionSubmitted = false;
    _serverZombieRoles = {};
    _serverNightActions = {};
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
