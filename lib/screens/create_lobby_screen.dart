import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/game_service.dart';
import 'lobby_screen.dart';

class CreateLobbyScreen extends StatefulWidget {
  final String playerName;
  const CreateLobbyScreen({super.key, required this.playerName});

  @override
  State<CreateLobbyScreen> createState() => _CreateLobbyScreenState();
}

class _CreateLobbyScreenState extends State<CreateLobbyScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _success = false;
  late AnimationController _pulseController;
  late Animation<double> _pulse;
  int _selectedRounds = 5;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _createLobby();
  }

  Future<void> _createLobby() async {
    final service = context.read<GameService>();
    final ok = await service.createLobby(widget.playerName, rounds: _selectedRounds);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _loading = false;
        _success = true;
      });
    } else {
      setState(() => _loading = false);
      _showError(service.errorMessage);
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('خطأ', style: GoogleFonts.cairo(color: Colors.white)),
        content: Text(msg, style: GoogleFonts.cairo(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('حسناً', style: GoogleFonts.cairo(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _proceedToLobby() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LobbyScreen()),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () {
              context.read<GameService>().disconnect();
              Navigator.pop(context);
            },
          ),
          title: Text('إنشاء غرفة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: _loading
            ? _buildLoading()
            : _success
                ? _buildContent()
                : const SizedBox(),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text('جاري إنشاء الغرفة...', style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final service = context.watch<GameService>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // IP Card
          _buildIpCard(service.localIp),
          const SizedBox(height: 24),
          // Rounds selector
          _buildRoundsSelector(),
          const SizedBox(height: 24),
          // Players list
          _buildPlayerList(service),
          const SizedBox(height: 24),
          // Start button
          _buildStartButton(service),
          const SizedBox(height: 16),
          Text(
            'في انتظار انضمام الأصدقاء...',
            style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildIpCard(String ip) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('📡', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'عنوان الغرفة',
            style: GoogleFonts.cairo(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Transform.scale(scale: _pulse.value, child: child),
            child: Text(
              ip,
              style: GoogleFonts.cairo(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'شارك هذا العنوان مع أصدقائك',
            style: GoogleFonts.cairo(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: ip));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم نسخ العنوان!', style: GoogleFonts.cairo()),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            icon: const Icon(Icons.copy, color: Colors.white, size: 18),
            label: Text('نسخ العنوان', style: GoogleFonts.cairo(color: Colors.white, fontSize: 14)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundsSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(
            '⚙️ عدد الجولات',
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [3, 5, 7, 10].map((n) {
              final selected = _selectedRounds == n;
              return GestureDetector(
                onTap: () => setState(() => _selectedRounds = n),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.cardBorder,
                      width: 2,
                    ),
                    boxShadow: selected
                        ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12)]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$n',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerList(GameService service) {
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
                style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${service.players.length}/8',
                  style: GoogleFonts.cairo(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (service.players.isEmpty)
            Center(
              child: Text(
                'لا يوجد لاعبون بعد...',
                style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 14),
              ),
            )
          else
            ...service.players.map((p) => _buildPlayerTile(p, service.myId)),
        ],
      ),
    );
  }

  Widget _buildPlayerTile(PlayerInfo p, String myId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: p.id == myId
            ? AppColors.primary.withOpacity(0.15)
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: p.id == myId ? AppColors.primary.withOpacity(0.5) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                p.name.isNotEmpty ? p.name[0] : '?',
                style: GoogleFonts.cairo(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.name,
              style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          if (p.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('👑 مضيف', style: GoogleFonts.cairo(color: AppColors.accent, fontSize: 12)),
            ),
          if (p.id == myId && !p.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('أنت', style: GoogleFonts.cairo(color: AppColors.secondary, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildStartButton(GameService service) {
    final canStart = service.canStartGame;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canStart ? _proceedToLobby : null,
        icon: const Icon(Icons.play_arrow_rounded, size: 26),
        label: Text(
          canStart
              ? 'ابدأ اللعبة (${service.players.length} لاعبين)'
              : 'في انتظار لاعبين... (2 على الأقل)',
          style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canStart ? AppColors.success : AppColors.surface,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surface,
          disabledForegroundColor: AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: canStart ? 8 : 0,
          shadowColor: AppColors.success.withOpacity(0.5),
        ),
      ),
    );
  }
}
