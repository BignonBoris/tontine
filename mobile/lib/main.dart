import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/auth/screens/auth_choice_screen.dart';
import 'package:mobile/features/auth/screens/auth_identification_screen.dart';
import 'package:mobile/features/auth/screens/auth_otp_screen.dart';
import 'package:mobile/features/auth/screens/auth_pin_setup_screen.dart';
import 'package:mobile/features/dashboard/data/services/notification_service.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_transaction.dart';
import 'package:mobile/features/navigation/presentation/bloc/navigation_bloc.dart';
import 'package:mobile/features/navigation/presentation/screens/main_navigation_screen.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import 'package:mobile/features/security/presentation/screens/app_unlock_screen.dart';
import 'package:mobile/features/splashscreen/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await initializeDateFormatting('fr_FR', null);
  await NotificationService.init();
  await Hive.initFlutter();

  Hive.registerAdapter(TontineTransactionAdapter());
  Hive.registerAdapter(TontineGoalAdapter());
  Hive.registerAdapter(GoalStatusAdapter());

  await Hive.openBox<TontineGoal>('goals_box');
  await Hive.openBox('wallet_box');
  await dotenv.load(fileName: ".env");
  runApp(const MaTontineApp());
}

class MaTontineApp extends StatelessWidget {
  const MaTontineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VizioBox',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      locale: const Locale('fr', 'FR'),
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
        '/auth_pin_setup': (context) => const AuthPinSetupScreen(),
        '/unlock': (context) => const AppUnlockScreen(),
        '/dashboard': (context) => BlocProvider(
          create: (context) => NavigationBloc(),
          child: const MainNavigationScreen(),
        ),
      },
    );
  }
}
