import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart'; // Import indispensable
// Importations de tes dossiers racines
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/dashboard/data/services/notification_service.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_transaction.dart';
import 'package:mobile/features/splashscreen/splash_screen.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import 'package:mobile/features/auth/screens/auth_choice_screen.dart';
import 'package:mobile/features/auth/screens/auth_identification_screen.dart';
import 'package:mobile/features/auth/screens/auth_otp_screen.dart';
import 'package:mobile/features/security/presentation/screens/app_unlock_screen.dart';
// Importations de la nouvelle architecture
import 'package:mobile/features/navigation/presentation/bloc/navigation_bloc.dart';
import 'package:mobile/features/navigation/presentation/screens/main_navigation_screen.dart';

void main() async {
  // 1. S'assurer que les services Flutter sont prêts
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialiser le formatage pour le français
  await initializeDateFormatting('fr_FR', null);
  await NotificationService.init();

  await Hive.initFlutter(); // Initialise Hive pour Flutter

  // Enregistre l'adaptateur que nous venons de générer
  Hive.registerAdapter(TontineTransactionAdapter());
  Hive.registerAdapter(TontineGoalAdapter());
  Hive.registerAdapter(GoalStatusAdapter());

  // Ouvre la boîte qui contiendra tes coffres
  await Hive.openBox<TontineGoal>('goals_box');
  await Hive.openBox('wallet_box');

  runApp(const MaTontineApp());
}

class MaTontineApp extends StatelessWidget {
  const MaTontineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ma Tontine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'), // Français
        Locale('en', 'US'), // Anglais (optionnel)
      ],
      locale: const Locale('fr', 'FR'), // Force la langue en français
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
        '/unlock': (context) => const AppUnlockScreen(),
        '/dashboard': (context) => BlocProvider(
          create: (context) => NavigationBloc(),
          child: const MainNavigationScreen(),
        ),
      },
    );
  }
}
