import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'core/settings.dart' as settings;
import 'state/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig(settings.createSettingsStore());
  final session = SessionController(config: config);
  await session.init();
  runApp(AppScope(controller: session, child: const JustWorkApp()));
}
