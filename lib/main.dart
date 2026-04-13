import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/game_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
  ));
  runApp(
    ChangeNotifierProvider(
      create: (_) => GameService(),
      child: const TakhatturApp(),
    ),
  );
}

class AppColors {
  static const Color background = Color(0xFF0A0717);
  static const Color surface = Color(0xFF1A1040);
  static const Color surfaceLight = Color(0xFF251860);
  static const Color primary = Color(0xFF7C4DFF);
  static const Color primaryDark = Color(0xFF5B2EE0);
  static const Color secondary = Color(0xFF00E5FF);
  static const Color accent = Color(0xFFFFD700);
  static const Color success = Color(0xFF00C897);
  static const Color error = Color(0xFFFF4757);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0A8D0);
  static const Color cardBorder = Color(0xFF3D2E80);

  static const List<Color> groupColors = [
    Color(0xFF7C4DFF),
    Color(0xFF00E5FF),
    Color(0xFFFF6B6B),
    Color(0xFFFFD700),
    Color(0xFF00C897),
    Color(0xFFFF8C00),
    Color(0xFFE91E8C),
    Color(0xFF76FF03),
  ];
}

class TakhatturApp extends StatelessWidget {
  const TakhatturApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تخاطر',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.cairoTextTheme(
          ThemeData.dark().textTheme,
        ).apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          labelStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
          hintStyle: GoogleFonts.cairo(color: AppColors.textSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
