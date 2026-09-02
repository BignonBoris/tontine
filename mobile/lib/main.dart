import 'dart:async';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/security/local_security_service.dart';
import 'package:mobile/core/services/push_notification_service.dart';
import 'package:mobile/core/storage/session_storage.dart';
import 'package:mobile/features/auth/screens/auth_choice_screen.dart';
import 'package:mobile/features/auth/screens/auth_identification_screen.dart';
import 'package:mobile/features/auth/screens/auth_otp_screen.dart';
import 'package:mobile/features/auth/screens/auth_pin_setup_screen.dart';
import 'package:mobile/features/dashboard/data/services/dashboard_cache_service.dart';
import 'package:mobile/features/dashboard/data/services/notification_service.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_goal.dart';
import 'package:mobile/features/dashboard/domain/entities/tontine_transaction.dart';
import 'package:mobile/features/groups/data/services/groups_cache_service.dart';
import 'package:mobile/features/groups/presentation/screens/group_invitation_screen.dart';
import 'package:mobile/features/groups/presentation/screens/group_qr_scanner_screen.dart';
import 'package:mobile/features/navigation/presentation/bloc/navigation_bloc.dart';
import 'package:mobile/features/navigation/presentation/screens/main_navigation_screen.dart';
import 'package:mobile/features/onboarding/onboarding_screen.dart';
import 'package:mobile/features/onboarding/presentation/screens/onboarding_goals_selection_screen.dart';
import 'package:mobile/features/security/presentation/screens/app_unlock_screen.dart';
import 'package:mobile/features/splashscreen/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await initializeDateFormatting('fr_FR', null);
  await NotificationService.init();
  unawaited(PushNotificationService.instance.start());
  await Hive.initFlutter();

  Hive.registerAdapter(TontineTransactionAdapter());
  Hive.registerAdapter(TontineGoalAdapter());
  Hive.registerAdapter(GoalStatusAdapter());

  await Hive.openBox<TontineGoal>('goals_box');
  await Hive.openBox('wallet_box');
  await Hive.openBox('dashboard_cache_box');
  await Hive.openBox('groups_cache_box');
  SessionStorage.registerBeforeClearHook(() async {
    await DashboardCacheService().clear();
    await GroupsCacheService().clear();
    await LocalSecurityService.clearTemporaryAppLockBypass();
  });

  final sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
      },
      appRunner: () => runApp(const MaTontineApp()),
    );
  } else {
    runApp(const MaTontineApp());
  }
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
      onGenerateRoute: (settings) {
        final routeName = settings.name ?? '';
        final uri = Uri.tryParse(routeName);
        if (uri != null &&
            uri.pathSegments.length == 2 &&
            uri.pathSegments[0] == 'group-invitations') {
          final token = uri.pathSegments[1];
          return MaterialPageRoute<void>(
            builder: (_) => GroupInvitationScreen(token: token),
            settings: settings,
          );
        }
        return null;
      },
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
        '/onboarding_goals': (context) =>
            const OnboardingGoalsSelectionScreen(),
        '/unlock': (context) => const AppUnlockScreen(),
        '/group-scanner': (context) => const GroupQrScannerScreen(),
        '/dashboard': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return BlocProvider(
            create: (context) => NavigationBloc(),
            child: MainNavigationScreen(
              skipOnboarding: args?['skip_onboarding'] ?? false,
            ),
          );
        },
      },
    );
  }
}
