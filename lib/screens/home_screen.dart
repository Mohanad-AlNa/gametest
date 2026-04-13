import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'create_lobby_screen.dart';
import 'join_lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  late AnimationController _bgController;
  late Animation<Alignment> _bgAnimation;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _bgAnimation = AlignmentTween(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _onCreateLobby() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('أدخل اسمك أولاً');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLobbyScreen(playerName: name),
      ),
    );
  }

  void _onJoinLobby() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('أدخل اسمك أولاً');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JoinLobbyScreen(playerName: name),
      ),
    );
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
        body: AnimatedBuilder(
          animation: _bgController,
          builder: (_, child) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: _bgAnimation.value,
                end: Alignment.center,
                colors: const [
                  Color(0xFF1A0A40),
                  Color(0xFF0A0717),
                  Color(0xFF0D1545),
                ],
              ),
            ),
            child: child,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  _buildLogo(),
                  const SizedBox(height: 16),
                  Text(
                    'تخاطر',
                    style: GoogleFonts.cairo(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: AppColors.primary.withOpacity(0.8),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'تزامن الأفكار مع أصدقائك',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 50),
                  // Name input
                  _buildNameInput(),
                  const SizedBox(height: 40),
                  // Buttons
                  _buildCreateButton(),
                  const SizedBox(height: 16),
                  _buildJoinButton(),
                  const SizedBox(height: 40),
                  // How to play
                  _buildHowToPlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Center(
        child: Text('🧠', style: TextStyle(fontSize: 46)),
      ),
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اسمك في اللعبة',
          style: GoogleFonts.cairo(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          textAlign: TextAlign.right,
          maxLength: 16,
          style: GoogleFonts.cairo(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: 'أدخل اسمك...',
            counterText: '',
            prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _onCreateLobby,
        icon: const Icon(Icons.add_circle_outline, size: 22),
        label: Text('إنشاء غرفة جديدة', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 8,
          shadowColor: AppColors.primary.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildJoinButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _onJoinLobby,
        icon: const Icon(Icons.login_outlined, size: 22, color: AppColors.secondary),
        label: Text(
          'الانضمام لغرفة موجودة',
          style: GoogleFonts.cairo(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          side: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildHowToPlay() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎮 كيف تلعب؟',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          _howToPlayItem('1️⃣', 'يظهر تصنيف لجميع اللاعبين'),
          _howToPlayItem('2️⃣', 'اكتب أول شيء يخطر ببالك'),
          _howToPlayItem('3️⃣', 'من كتب نفس الكلمة يحصل على نقاط'),
          _howToPlayItem('🏆', 'الأكثر تخاطراً مع الآخرين يفوز!'),
        ],
      ),
    );
  }

  Widget _howToPlayItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.cairo(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
