import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/game_service.dart';

class ZombieHubScreen extends StatelessWidget {
  const ZombieHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Consumer<GameService>(
        builder: (context, service, _) {
          return Scaffold(
            backgroundColor: AppColors.zombieDark,
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _buildPhaseWidget(context, service),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhaseWidget(BuildContext context, GameService service) {
    switch (service.phase) {
      case GamePhase.zombieRoleReveal:
        return _ZombieRoleWidget(key: const ValueKey('roleReveal'));
      case GamePhase.zombieNightPhase:
        return _ZombieNightWidget(key: const ValueKey('night'));
      case GamePhase.zombieMorningReveal:
        return _ZombieMorningWidget(key: const ValueKey('morning'));
      case GamePhase.zombieGameOver:
        return _ZombieFinalWidget(key: const ValueKey('gameover'));
      default:
        return Center(
          key: const ValueKey('loading'),
          child: Text(
            '⏳ تحميل...',
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 24),
          ),
        );
    }
  }
}

// ─── Role Reveal Screen ───────────────────────────────────────────────────────

class _ZombieRoleWidget extends StatefulWidget {
  const _ZombieRoleWidget({super.key});

  @override
  State<_ZombieRoleWidget> createState() => _ZombieRoleWidgetState();
}

class _ZombieRoleWidgetState extends State<_ZombieRoleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulse;
  int _countdown = 6;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GameService>();
    final isZombie = service.myZombieRole == ZombieRole.zombie;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isZombie
              ? [const Color(0xFF3B0000), AppColors.zombieDark]
              : [const Color(0xFF002244), const Color(0xFF000D1A)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(
                'دورك السري',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  color: Colors.white60,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, child) => Transform.scale(
                  scale: _pulse.value,
                  child: child,
                ),
                child: Text(
                  isZombie ? '🧟' : '👤',
                  style: const TextStyle(fontSize: 100),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isZombie ? 'أنت... زومبي!' : 'أنت... إنسان!',
                style: GoogleFonts.cairo(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: isZombie ? AppColors.zombieRed : AppColors.humanBlue,
                  shadows: [
                    Shadow(
                      color: (isZombie ? AppColors.zombieRed : AppColors.humanBlue)
                          .withOpacity(0.8),
                      blurRadius: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildAbilitiesCard(isZombie),
              const SizedBox(height: 24),
              if (isZombie)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.zombieRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.zombieRed.withOpacity(0.4)),
                  ),
                  child: Text(
                    '⚠️ لا تكشف دورك لأحد!',
                    style: GoogleFonts.cairo(
                      color: AppColors.zombieRed,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 32),
              Text(
                'ينتهي خلال $_countdown ثانية',
                style: GoogleFonts.cairo(color: Colors.white38, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbilitiesCard(bool isZombie) {
    final abilities = isZombie
        ? [
            ('🩸', 'العضة', 'اعضض أي لاعب في كل جولة'),
            ('👁️', 'الكشف (مرة واحدة)', 'اكشف دور لاعب سراً'),
            ('💉', 'اللقاح', 'بعد عضة... يمكنك التحول لإنسان'),
          ]
        : [
            ('🔫', 'الطلق', 'أطلق النار على لاعب - إن كان زومبي يُقضى عليه!'),
            ('⚠️', 'تحذير', 'إن أصبت إنساناً من فريقك تخسر نقاطاً'),
          ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isZombie ? AppColors.zombieRed : AppColors.humanBlue).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'قدراتك:',
            style: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...abilities.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.$1, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.$2,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            a.$3,
                            style: GoogleFonts.cairo(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Night Phase Screen ───────────────────────────────────────────────────────

class _ZombieNightWidget extends StatefulWidget {
  const _ZombieNightWidget({super.key});

  @override
  State<_ZombieNightWidget> createState() => _ZombieNightWidgetState();
}

class _ZombieNightWidgetState extends State<_ZombieNightWidget> {

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GameService>();
    final isZombie = service.myZombieRole == ZombieRole.zombie;
    final myPlayer = service.myPlayer;
    final otherPlayers = service.players
        .where((p) => p.id != service.myId && !p.isEliminated)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050A1A), Color(0xFF000308)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '🌙 مرحلة الليل - جولة ${service.currentRound}',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isZombie
                          ? AppColors.zombieRed.withOpacity(0.2)
                          : AppColors.humanBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isZombie ? AppColors.zombieRed : AppColors.humanBlue,
                      ),
                    ),
                    child: Text(
                      isZombie ? '🧟 زومبي' : '👤 إنسان',
                      style: GoogleFonts.cairo(
                        color: isZombie ? AppColors.zombieRed : AppColors.humanBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Timer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: LinearProgressIndicator(
                value: service.timeLeft / 30.0,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  service.timeLeft > 10 ? AppColors.zombieGreen : AppColors.zombieRed,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${service.timeLeft} ثانية',
                style: GoogleFonts.cairo(
                  color: service.timeLeft > 10 ? Colors.white60 : AppColors.zombieRed,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: service.myActionSubmitted
                  ? _buildWaiting(service)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Vaccine button (if available)
                          if (myPlayer?.canVaccine == true && !isZombie)
                            _buildVaccineButton(service),
                          // Reveal result (if zombie revealed)
                          if (isZombie &&
                              service.zombieRevealedName.isNotEmpty &&
                              myPlayer?.revealUsed == true)
                            _buildRevealResult(service),
                          // Players list
                          _buildPlayersList(
                            service,
                            otherPlayers,
                            isZombie,
                            myPlayer,
                          ),
                          // Pass button
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => service.submitZombieAction('pass', null),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white30),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'تمرير (لا أفعل شيئاً)',
                                style: GoogleFonts.cairo(color: Colors.white60, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccineButton(GameService service) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton.icon(
        onPressed: () => service.submitZombieAction('vaccine', null),
        icon: const Text('💉', style: TextStyle(fontSize: 20)),
        label: Text(
          'خذ اللقاح - ابق إنساناً!',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.humanBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: AppColors.humanBlue.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildRevealResult(GameService service) {
    final isRevealedZombie = service.zombieRevealedRole == ZombieRole.zombie;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRevealedZombie
            ? AppColors.zombieRed.withOpacity(0.15)
            : AppColors.humanBlue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRevealedZombie ? AppColors.zombieRed : AppColors.humanBlue,
        ),
      ),
      child: Row(
        children: [
          Text(isRevealedZombie ? '🧟' : '👤', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${service.zombieRevealedName}',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isRevealedZombie ? 'زومبي 🧟' : 'إنسان 👤',
                  style: GoogleFonts.cairo(
                    color: isRevealedZombie ? AppColors.zombieRed : AppColors.humanBlue,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList(
    GameService service,
    List<PlayerInfo> players,
    bool isZombie,
    PlayerInfo? myPlayer,
  ) {
    if (players.isEmpty) {
      return Text(
        'لا يوجد لاعبون آخرون',
        style: GoogleFonts.cairo(color: Colors.white60),
        textAlign: TextAlign.center,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '👥 اختر هدفك:',
          style: GoogleFonts.cairo(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...players.map((p) => _buildPlayerActionTile(service, p, isZombie, myPlayer)),
      ],
    );
  }

  Widget _buildPlayerActionTile(
    GameService service,
    PlayerInfo player,
    bool isZombie,
    PlayerInfo? myPlayer,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Text(player.avatar, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              player.name,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (isZombie) ...[
            // Bite button
            _actionButton(
              label: 'عض 🩸',
              color: AppColors.zombieRed,
              onTap: () => service.submitZombieAction('bite', player.id),
            ),
            const SizedBox(width: 8),
            // Reveal button (if not used)
            if (myPlayer?.revealUsed == false)
              _actionButton(
                label: 'اكشف 👁️',
                color: Colors.purple,
                onTap: () => service.submitZombieAction('reveal', player.id),
              ),
          ] else ...[
            // Shoot button
            _actionButton(
              label: 'أطلق 🔫',
              color: AppColors.humanBlue,
              onTap: () => service.submitZombieAction('shoot', player.id),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting(GameService service) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              color: AppColors.zombieGreen,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '⏳ في انتظار الآخرين...',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${service.timeLeft} ثانية متبقية',
            style: GoogleFonts.cairo(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─── Morning Reveal Screen ────────────────────────────────────────────────────

class _ZombieMorningWidget extends StatefulWidget {
  const _ZombieMorningWidget({super.key});

  @override
  State<_ZombieMorningWidget> createState() => _ZombieMorningWidgetState();
}

class _ZombieMorningWidgetState extends State<_ZombieMorningWidget> {
  int _visibleEvents = 0;
  Timer? _eventTimer;

  @override
  void initState() {
    super.initState();
    final service = context.read<GameService>();
    _startRevealAnimation(service.morningEvents.length);
  }

  void _startRevealAnimation(int eventCount) {
    _eventTimer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (_visibleEvents < eventCount) {
        setState(() => _visibleEvents++);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _eventTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GameService>();
    final events = service.morningEvents;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A0A00),
            AppColors.zombieDark,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                '☀️ الصباح يكشف كل شيء...',
                style: GoogleFonts.cairo(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'جولة ${service.currentRound} / ${service.totalRounds}',
              style: GoogleFonts.cairo(color: Colors.white54, fontSize: 14),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Events list
                    ...List.generate(
                      _visibleEvents.clamp(0, events.length),
                      (i) => _buildEventTile(events[i]),
                    ),
                    const SizedBox(height: 20),
                    // Survivors count
                    if (_visibleEvents >= events.length)
                      _buildSurvivorsCount(service),
                    const SizedBox(height: 20),
                    // Scores
                    if (_visibleEvents >= events.length) _buildScores(service),
                    const SizedBox(height: 24),
                    // Next round button (host only, shown after events)
                    if (_visibleEvents >= events.length && service.isHost)
                      _buildNextRoundButton(context, service),
                    if (_visibleEvents >= events.length && !service.isHost)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: AppColors.zombieGreen,
                                strokeWidth: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'في انتظار المضيف...',
                              style: GoogleFonts.cairo(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> event) {
    final type = event['event'] as String;
    String emoji;
    String text;
    Color color;

    switch (type) {
      case 'bitten':
        emoji = '🩸';
        text = 'تحوّل ${event['victimName']} إلى زومبي الليلة!';
        color = AppColors.zombieRed;
        break;
      case 'shot_zombie':
        emoji = '💥';
        text = '${event['shooterName']} أطلق النار على ${event['targetName']} الزومبي وقضى عليه!';
        color = AppColors.zombieGreen;
        break;
      case 'shot_human':
        emoji = '💥';
        text = '${event['shooterName']} أطلق النار على ${event['targetName']}... لكنه من فريقه!';
        color = Colors.yellow;
        break;
      case 'friendly_fire':
        emoji = '⚡';
        text = 'حدث ارتباك في صفوف الزومبي بين ${event['zombie1Name']} و ${event['zombie2Name']}!';
        color = Colors.purple;
        break;
      case 'vaccine':
        emoji = '💉';
        text = '${event['playerName']} استخدم اللقاح وعاد إنساناً!';
        color = AppColors.humanBlue;
        break;
      case 'quiet':
      default:
        emoji = '😴';
        text = 'ليلة هادئة... لا شيء يذكر';
        color = Colors.grey;
        break;
    }

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 600),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurvivorsCount(GameService service) {
    final alive = service.players.where((p) => !p.isEliminated).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              const Text('👤', style: TextStyle(fontSize: 32)),
              Text(
                '${alive.length}',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text('ناجون', style: GoogleFonts.cairo(color: Colors.white60, fontSize: 12)),
            ],
          ),
          Container(width: 1, height: 60, color: Colors.white12),
          Column(
            children: [
              const Text('💀', style: TextStyle(fontSize: 32)),
              Text(
                '${service.players.where((p) => p.isEliminated).length}',
                style: GoogleFonts.cairo(
                  color: AppColors.zombieRed,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'تحولوا',
                style: GoogleFonts.cairo(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScores(GameService service) {
    final sorted = List<PlayerInfo>.from(service.players)
      ..sort((a, b) => b.score.compareTo(a.score));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(
            '🏅 النقاط',
            style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...sorted.map((p) {
            final isMe = p.id == service.myId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(p.avatar, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.name,
                      style: GoogleFonts.cairo(
                        color: isMe ? AppColors.accent : Colors.white,
                        fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (p.isEliminated)
                    Text(
                      '💀 ',
                      style: GoogleFonts.cairo(color: AppColors.zombieRed, fontSize: 12),
                    ),
                  Text(
                    '${p.score} نقطة',
                    style: GoogleFonts.cairo(
                      color: isMe ? AppColors.accent : AppColors.zombieGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNextRoundButton(BuildContext context, GameService service) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          // Server auto-advances, just wait for next zombie_phase message
        },
        icon: const Icon(Icons.nightlight_round, size: 22),
        label: Text(
          'الجولة التالية ▶️',
          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.zombieGreen.withOpacity(0.8),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ─── Final Screen ─────────────────────────────────────────────────────────────

class _ZombieFinalWidget extends StatefulWidget {
  const _ZombieFinalWidget({super.key});

  @override
  State<_ZombieFinalWidget> createState() => _ZombieFinalWidgetState();
}

class _ZombieFinalWidgetState extends State<_ZombieFinalWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _bounce = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GameService>();
    final winner = service.zombieWinner;
    final zombiesWin = winner == 'zombies';
    final isDraw = winner == 'draw';

    final List<Color> bgColors = zombiesWin
        ? [const Color(0xFF3B0000), AppColors.zombieDark]
        : isDraw
            ? [const Color(0xFF1A1A00), const Color(0xFF0A0A00)]
            : [const Color(0xFF002244), const Color(0xFF000D1A)];

    final String bigEmoji = zombiesWin ? '🧟' : isDraw ? '🤝' : '🏆';
    final String title = zombiesWin
        ? 'الزومبي انتشر!'
        : isDraw
            ? 'ما انحسم الأمر... تعادل!'
            : 'البشرية نجت!';
    final Color titleColor = zombiesWin
        ? AppColors.zombieRed
        : isDraw
            ? Colors.yellow
            : AppColors.humanBlue;

    final sorted = List<PlayerInfo>.from(service.players)
      ..sort((a, b) => b.score.compareTo(a.score));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bgColors,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _bounce,
                builder: (_, child) =>
                    Transform.scale(scale: _bounce.value, child: child),
                child: Text(bigEmoji, style: const TextStyle(fontSize: 100)),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: titleColor,
                  shadows: [
                    Shadow(color: titleColor.withOpacity(0.6), blurRadius: 20),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Final leaderboard
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Text(
                      '🏆 الترتيب النهائي',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...sorted.asMap().entries.map((e) {
                      final rank = e.key;
                      final player = e.value;
                      final isMe = player.id == service.myId;
                      final rankEmojis = ['🥇', '🥈', '🥉'];
                      final rankDisplay = rank < 3 ? rankEmojis[rank] : '${rank + 1}';
                      // Role display - we only know our own role
                      String roleDisplay = '';
                      if (player.id == service.myId) {
                        roleDisplay = service.myZombieRole == ZombieRole.zombie
                            ? '🧟'
                            : '👤';
                      } else if (player.isEliminated) {
                        roleDisplay = '💀';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isMe
                              ? titleColor.withOpacity(0.15)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isMe ? titleColor.withOpacity(0.4) : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(rankDisplay, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 10),
                            Text(player.avatar, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        player.name,
                                        style: GoogleFonts.cairo(
                                          color: isMe ? titleColor : Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (roleDisplay.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          roleDisplay,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isMe)
                                    Text(
                                      'أنت',
                                      style: GoogleFonts.cairo(
                                        color: titleColor.withOpacity(0.7),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '${player.score} نقطة',
                              style: GoogleFonts.cairo(
                                color: isMe ? titleColor : AppColors.zombieGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Play again button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    service.disconnect();
                    Navigator.popUntil(context, (r) => r.isFirst);
                  },
                  icon: const Icon(Icons.home_rounded, size: 24),
                  label: Text(
                    'العب مجدداً',
                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: titleColor,
                    foregroundColor:
                        zombiesWin || isDraw ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 10,
                    shadowColor: titleColor.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
