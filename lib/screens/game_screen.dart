import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/game_service.dart';
import 'results_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final _answerController = TextEditingController();
  bool _submitted = false;
  late AnimationController _categoryController;
  late AnimationController _timerController;
  late AnimationController _bgController;
  late Animation<double> _categorySlide;
  late Animation<double> _categoryFade;
  late Animation<Color?> _timerColor;

  @override
  void initState() {
    super.initState();
    _submitted = false;

    _categoryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _categorySlide = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _categoryController, curve: Curves.elasticOut),
    );
    _categoryFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _categoryController, curve: const Interval(0, 0.5)),
    );
    _timerColor = ColorTween(
      begin: AppColors.success,
      end: AppColors.error,
    ).animate(CurvedAnimation(parent: _timerController, curve: Curves.easeIn));

    _categoryController.forward();
    _timerController.forward();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _categoryController.dispose();
    _timerController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _submit() {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;
    setState(() => _submitted = true);
    context.read<GameService>().submitAnswer(answer);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Consumer<GameService>(
        builder: (context, service, _) {
          // Navigate to results
          if (service.phase == GamePhase.reviewing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 600),
                    pageBuilder: (_, __, ___) => const ResultsScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                  ),
                );
              }
            });
          }

          final timeLeft = service.timeLeft;
          final progress = timeLeft / 30.0;
          final answered = service.answeredCount;
          final total = service.players.length;

          return Scaffold(
            backgroundColor: AppColors.background,
            body: AnimatedBuilder(
              animation: _bgController,
              builder: (_, child) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(
                        const Color(0xFF100A30),
                        const Color(0xFF0A0A20),
                        _bgController.value,
                      )!,
                      AppColors.background,
                    ],
                  ),
                ),
                child: child,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Header: round + progress
                      _buildHeader(service),
                      const SizedBox(height: 20),
                      // Timer ring
                      _buildTimer(timeLeft, progress),
                      const SizedBox(height: 24),
                      // Category card
                      _buildCategoryCard(service),
                      const SizedBox(height: 28),
                      // Answer count
                      _buildAnswerCount(answered, total),
                      const SizedBox(height: 20),
                      // Answer input
                      _buildAnswerInput(),
                      const SizedBox(height: 16),
                      // Submit button
                      _buildSubmitButton(),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(GameService service) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                'جولة ${service.currentRound}/${service.totalRounds}',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // My score
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.accent.withOpacity(0.3), AppColors.accent.withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '${service.myPlayer?.score ?? 0}',
                style: GoogleFonts.cairo(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimer(int timeLeft, double progress) {
    return AnimatedBuilder(
      animation: _timerController,
      builder: (_, __) {
        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: AppColors.surface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _timerColor.value ?? AppColors.success,
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$timeLeft',
                    style: GoogleFonts.cairo(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: _timerColor.value ?? AppColors.success,
                    ),
                  ),
                  Text(
                    'ثانية',
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryCard(GameService service) {
    return AnimatedBuilder(
      animation: _categoryController,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _categorySlide.value),
        child: Opacity(opacity: _categoryFade.value, child: child),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              service.currentEmoji,
              style: const TextStyle(fontSize: 56),
            ),
            const SizedBox(height: 12),
            Text(
              service.currentCategory,
              style: GoogleFonts.cairo(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              height: 1,
              color: Colors.white24,
              margin: const EdgeInsets.symmetric(horizontal: 20),
            ),
            const SizedBox(height: 8),
            Text(
              service.currentHint,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerCount(int answered, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...List.generate(total, (i) {
          final done = i < answered;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: done ? 24 : 20,
            height: done ? 24 : 20,
            decoration: BoxDecoration(
              color: done ? AppColors.success : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: done ? AppColors.success : AppColors.cardBorder,
                width: 2,
              ),
            ),
            child: done
                ? const Center(
                    child: Icon(Icons.check, size: 14, color: Colors.white),
                  )
                : null,
          );
        }),
        const SizedBox(width: 10),
        Text(
          '$answered/$total أجاب',
          style: GoogleFonts.cairo(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerInput() {
    return TextField(
      controller: _answerController,
      enabled: !_submitted,
      textAlign: TextAlign.center,
      style: GoogleFonts.cairo(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      decoration: InputDecoration(
        hintText: _submitted ? '✅ تم إرسال إجابتك' : 'اكتب إجابتك هنا...',
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        filled: true,
        fillColor: _submitted
            ? AppColors.success.withOpacity(0.1)
            : AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: _submitted ? AppColors.success : AppColors.cardBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(
            color: _submitted ? AppColors.success : AppColors.cardBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      onSubmitted: _submitted ? null : (_) => _submit(),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _submitted ? null : _submit,
        icon: _submitted
            ? const Icon(Icons.check_circle, size: 24)
            : const Icon(Icons.send_rounded, size: 24),
        label: Text(
          _submitted ? 'تم الإرسال! في انتظار الآخرين...' : 'إرسال الإجابة',
          style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _submitted ? AppColors.success : AppColors.primary,
          disabledBackgroundColor: AppColors.success.withOpacity(0.6),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: _submitted ? 0 : 8,
          shadowColor: AppColors.primary.withOpacity(0.4),
        ),
      ),
    );
  }
}
