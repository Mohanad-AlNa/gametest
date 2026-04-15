import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/game_service.dart';
import 'game_screen.dart';
import 'zombie_hub_screen.dart';

class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Consumer<GameService>(
        builder: (context, service, _) {
          // Navigate when game starts
          if (service.phase == GamePhase.playing ||
              service.phase == GamePhase.countdown) {
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

          if (service.phase == GamePhase.zombieRoleReveal ||
              service.phase == GamePhase.zombieNightPhase ||
              service.phase == GamePhase.zombieMorningReveal ||
              service.phase == GamePhase.zombieGameOver) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 500),
                    pageBuilder: (_, __, ___) => const ZombieHubScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                  ),
                );
              }
            });
          }

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () {
                  service.disconnect();
                  Navigator.popUntil(context, (r) => r.isFirst);
                },
              ),
              title: Text(
                service.isHost ? 'غرفتك' : 'انتظار بدء اللعبة',
                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildWaitingAnimation(service),
                  const SizedBox(height: 24),
                  _buildPlayersList(service),
                  const SizedBox(height: 24),
                  if (service.isHost) _buildStartButton(context, service),
                  if (!service.isHost) _buildWaitingText(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaitingAnimation(GameService service) {
    final isZombie = service.gameMode == GameMode.zombie;
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isZombie ? AppColors.zombieGreen : AppColors.primary).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Text(
                isZombie ? '🧟' : '🎮',
                style: const TextStyle(fontSize: 56),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'صالة الانتظار',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isZombie
                  ? AppColors.zombieGreen.withOpacity(0.15)
                  : AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isZombie ? AppColors.zombieGreen : AppColors.primary,
              ),
            ),
            child: Text(
              isZombie ? '🧟 وباء الزومبي' : '🧠 تخاطر',
              style: GoogleFonts.cairo(
                color: isZombie ? AppColors.zombieGreen : AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList(GameService service) {
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
          Row(
            children: [
              Text(
                '👥 اللاعبون',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${service.players.length} / 8',
                  style: GoogleFonts.cairo(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (service.gameMode == GameMode.zombie && service.players.length < 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '⚠️ لعبة الزومبي تحتاج 3 لاعبين على الأقل',
                style: GoogleFonts.cairo(color: AppColors.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          if (service.players.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'لا يوجد لاعبون بعد...',
                  style: GoogleFonts.cairo(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...service.players.map(
              (p) => _buildPlayerTile(p, service.myId),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerTile(PlayerInfo p, String myId) {
    final isMe = p.id == myId;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? AppColors.primary.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.2),
            ),
            child: Center(
              child: Text(p.avatar, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isMe)
                  Text(
                    'أنت',
                    style: GoogleFonts.cairo(color: AppColors.secondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          if (p.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '👑 مضيف',
                style: GoogleFonts.cairo(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context, GameService service) {
    final isZombie = service.gameMode == GameMode.zombie;
    final minPlayers = isZombie ? 3 : 2;
    final canStart = service.players.length >= minPlayers;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canStart ? service.startGame : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: Text(
              canStart
                  ? 'ابدأ اللعبة!'
                  : 'في انتظار لاعبين ($minPlayers على الأقل)',
              style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: canStart ? AppColors.success : AppColors.surface,
              disabledBackgroundColor: AppColors.surface,
              disabledForegroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: canStart ? 10 : 0,
              shadowColor: AppColors.success.withOpacity(0.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${service.players.length} لاعب${service.players.length == 1 ? '' : 'ين'} في الغرفة',
          style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 14),
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
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'في انتظار المضيف ليبدأ اللعبة...',
            style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }
}
