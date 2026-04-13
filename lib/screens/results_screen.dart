import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/game_service.dart';
import 'game_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _particlesController;
  late Animation<double> _entranceFade;
  late Animation<double> _entranceSlide;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();

    final rng = Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: rng.nextDouble() * 8 + 4,
        speed: rng.nextDouble() * 0.3 + 0.1,
        color: AppColors.groupColors[rng.nextInt(AppColors.groupColors.length)],
      ));
    }

    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _entranceFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );
    _entranceSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOut),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Consumer<GameService>(
        builder: (context, service, _) {
          // Navigate to next round or final
          if (service.phase == GamePhase.playing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 500),
                    pageBuilder: (_, __, ___) => const GameScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                  ),
                );
              }
            });
          }

          final isFinalResults = service.phase == GamePhase.finalResults;

          return Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(
              children: [
                // Particles background
                AnimatedBuilder(
                  animation: _particlesController,
                  builder: (_, __) => CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _ParticlesPainter(_particles, _particlesController.value),
                  ),
                ),
                // Content
                SafeArea(
                  child: AnimatedBuilder(
                    animation: _entranceController,
                    builder: (_, child) => Opacity(
                      opacity: _entranceFade.value,
                      child: Transform.translate(
                        offset: Offset(0, _entranceSlide.value),
                        child: child,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildHeader(service, isFinalResults),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                if (isFinalResults) ...[
                                  _buildFinalLeaderboard(service),
                                  const SizedBox(height: 24),
                                  _buildPlayAgainButton(context, service),
                                ] else ...[
                                  _buildRoundTitle(service),
                                  const SizedBox(height: 16),
                                  _buildAnswerGroups(service),
                                  const SizedBox(height: 16),
                                  _buildScoreboard(service),
                                  const SizedBox(height: 24),
                                  if (service.isHost) _buildNextRoundButton(context, service),
                                  if (!service.isHost) _buildWaitingText(),
                                  const SizedBox(height: 20),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(GameService service, bool isFinal) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              service.disconnect();
              Navigator.popUntil(context, (r) => r.isFirst);
            },
          ),
          Expanded(
            child: Text(
              isFinal ? '🏆 النتائج النهائية' : '📊 نتائج الجولة ${service.currentRound}',
              style: GoogleFonts.cairo(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildRoundTitle(GameService service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withOpacity(0.3), AppColors.primary.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            service.currentEmoji,
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 8),
          Text(
            service.currentCategory,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerGroups(GameService service) {
    if (service.answerGroups.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'إجابات اللاعبين',
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ...service.answerGroups.map((group) => _buildGroupCard(group, service)),
      ],
    );
  }

  Widget _buildGroupCard(AnswerGroup group, GameService service) {
    final isMatch = group.playerIds.length >= 2;
    final color = isMatch && group.colorIndex >= 0
        ? AppColors.groupColors[group.colorIndex % AppColors.groupColors.length]
        : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMatch ? color.withOpacity(0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMatch ? color.withOpacity(0.5) : AppColors.cardBorder,
          width: isMatch ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Answer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.answer.isEmpty ? '(لم يجب)' : group.answer,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isMatch ? color : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: group.playerIds.map((id) {
                    final player = service.players.firstWhere(
                      (p) => p.id == id,
                      orElse: () => PlayerInfo(id: '', name: '؟'),
                    );
                    final isMe = id == service.myId;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.accent.withOpacity(0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        player.name,
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          color: isMe ? AppColors.accent : Colors.white70,
                          fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Points
          if (isMatch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '+${group.pointsEarned}',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  Text(
                    'نقطة',
                    style: GoogleFonts.cairo(fontSize: 11, color: color.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          if (!isMatch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '0',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreboard(GameService service) {
    final sorted = List<PlayerInfo>.from(service.players)
      ..sort((a, b) => b.score.compareTo(a.score));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏅 الترتيب الحالي',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ...sorted.asMap().entries.map((e) => _buildScoreRow(e.value, e.key, service.myId)),
        ],
      ),
    );
  }

  Widget _buildScoreRow(PlayerInfo player, int rank, String myId) {
    final isMe = player.id == myId;
    final rankEmojis = ['🥇', '🥈', '🥉'];
    final rankDisplay = rank < 3 ? rankEmojis[rank] : '${rank + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.accent.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? AppColors.accent.withOpacity(0.3) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(rankDisplay, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              style: GoogleFonts.cairo(
                color: isMe ? AppColors.accent : Colors.white,
                fontSize: 16,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${player.score} نقطة',
            style: GoogleFonts.cairo(
              color: isMe ? AppColors.accent : AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalLeaderboard(GameService service) {
    final sorted = List<PlayerInfo>.from(service.players)
      ..sort((a, b) => b.score.compareTo(a.score));

    return Column(
      children: [
        // Winner
        if (sorted.isNotEmpty) _buildWinnerCard(sorted.first, service.myId),
        const SizedBox(height: 20),
        // All players
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            children: [
              Text(
                '🏆 الترتيب النهائي',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...sorted.asMap().entries.map(
                    (e) => _buildFinalScoreRow(e.value, e.key, service.myId),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWinnerCard(PlayerInfo winner, String myId) {
    final isMe = winner.id == myId;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 8),
          Text(
            isMe ? '🎉 أنت الفائز! 🎉' : 'الفائز!',
            style: GoogleFonts.cairo(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            winner.name,
            style: GoogleFonts.cairo(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
          Text(
            '${winner.score} نقطة',
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalScoreRow(PlayerInfo player, int rank, String myId) {
    final isMe = player.id == myId;
    final rankEmojis = ['🥇', '🥈', '🥉'];
    final rankDisplay = rank < 3 ? rankEmojis[rank] : '${rank + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: rank == 0
              ? [AppColors.accent.withOpacity(0.2), AppColors.accent.withOpacity(0.05)]
              : isMe
                  ? [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0.05)]
                  : [AppColors.surfaceLight, Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank == 0
              ? AppColors.accent.withOpacity(0.4)
              : isMe
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(rankDisplay, style: TextStyle(fontSize: rank < 3 ? 28 : 20)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              player.name,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '${player.score}',
            style: GoogleFonts.cairo(
              color: rank == 0 ? AppColors.accent : AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'نقطة',
            style: GoogleFonts.cairo(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextRoundButton(BuildContext context, GameService service) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: service.nextRound,
        icon: const Icon(Icons.skip_next_rounded, size: 26),
        label: Text(
          'الجولة التالية ←',
          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 10,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildPlayAgainButton(BuildContext context, GameService service) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              service.disconnect();
              Navigator.popUntil(context, (r) => r.isFirst);
            },
            icon: const Icon(Icons.home_rounded, size: 26),
            label: Text(
              'العودة للرئيسية',
              style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingText() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Text(
            'في انتظار المضيف...',
            style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _Particle {
  final double x, y, size, speed;
  final Color color;
  _Particle({required this.x, required this.y, required this.size, required this.speed, required this.color});
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  final double animValue;

  _ParticlesPainter(this.particles, this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final yPos = (p.y - animValue * p.speed) % 1.0;
      final paint = Paint()..color = p.color.withOpacity(0.3);
      canvas.drawCircle(
        Offset(p.x * size.width, yPos * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter old) => old.animValue != animValue;
}
