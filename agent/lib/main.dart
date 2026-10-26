import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:agent/features/app/agent_app.dart';
import 'package:agent/core/services/push_notification_service.dart';
import 'package:agent/core/database/local_database_manager.dart';

import 'package:agent/core/security/auto_lock_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabaseManager.init();
  await initializeDateFormatting('fr_FR', null);
  await dotenv.load(fileName: '.env');
  unawaited(PushNotificationService.instance.start());

  final sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 1.0;
        // Identifie clairement les crashs comme venant de l'app agent
        options.environment = dotenv.env['APP_ENV'] ?? 'production';
        options.release = 'viziobox-agent@1.0.0';
      },
      appRunner: () => runApp(
        const AutoLockWrapper(child: AgentApp()),
      ),
    );
  } else {
    runApp(const AutoLockWrapper(child: AgentApp()));
  }
}

