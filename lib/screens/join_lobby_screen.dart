import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/game_service.dart';
import 'lobby_screen.dart';

class JoinLobbyScreen extends StatefulWidget {
  final String playerName;
  const JoinLobbyScreen({super.key, required this.playerName});

  @override
  State<JoinLobbyScreen> createState() => _JoinLobbyScreenState();
}

class _JoinLobbyScreenState extends State<JoinLobbyScreen> {
  final _ipController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      _showSnack('أدخل عنوان IP');
      return;
    }
    setState(() => _loading = true);
    final service = context.read<GameService>();
    final ok = await service.joinLobby(ip, widget.playerName);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LobbyScreen()),
      );
    } else {
      _showSnack(service.errorMessage);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.cairo()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('الانضمام لغرفة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 30),
                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.secondary.withOpacity(0.3), width: 2),
                  ),
                  child: const Center(child: Text('📡', style: TextStyle(fontSize: 50))),
                ),
                const SizedBox(height: 24),
                Text(
                  'أدخل عنوان الغرفة',
                  style: GoogleFonts.cairo(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'اطلب من مضيف الغرفة مشاركة عنوان IP معك',
                  style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // IP Input
                TextField(
                  controller: _ipController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: '192.168.1.x',
                    hintStyle: GoogleFonts.cairo(
                      color: AppColors.textSecondary,
                      fontSize: 22,
                      letterSpacing: 2,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  ),
                  onSubmitted: (_) => _join(),
                ),
                const SizedBox(height: 32),
                // Join button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _join,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.login_rounded, size: 22),
                    label: Text(
                      _loading ? 'جاري الاتصال...' : 'انضمام للغرفة',
                      style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 8,
                      shadowColor: AppColors.secondary.withOpacity(0.4),
                    ),
                  ),
                ),
                const Spacer(),
                // Hint
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'تأكد أن هاتفك متصل بنفس شبكة WiFi التي يستخدمها المضيف',
                          style: GoogleFonts.cairo(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
