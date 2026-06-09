import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:agent/features/app/agent_app.dart';
import 'package:agent/core/services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await dotenv.load(fileName: '.env');
  unawaited(PushNotificationService.instance.start());
  runApp(const AgentApp());
}
