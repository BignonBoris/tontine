import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/screens/auth_choice_screen.dart';
import 'package:mobile/features/auth/screens/auth_identification_screen.dart';
import 'package:mobile/features/auth/screens/auth_otp_screen.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import 'package:mobile/features/splashscreen/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ma Tontine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/auth_choice': (context) => const AuthChoiceScreen(),
        '/login': (context) =>
            const AuthIdentificationScreen(isRegistration: false),
        '/register': (context) =>
            const AuthIdentificationScreen(isRegistration: true),
        '/auth_otp': (context) => const AuthOtpScreen(),
        '/dashboard': (context) => const DashboardPlaceholderScreen(),
      },
    );
  }
}

class DashboardPlaceholderScreen extends StatelessWidget {
  const DashboardPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF1A237E);

    return Scaffold(
      appBar: AppBar(title: const Text('Tableau de bord')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.dashboard_rounded,
                size: 72,
                color: primaryBlue,
              ),
              const SizedBox(height: 16),
              Text(
                'Le dashboard n\'est pas encore implemente.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Le flux OTP ne casse plus pendant que cet ecran est en construction.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
