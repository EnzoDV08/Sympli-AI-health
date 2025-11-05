import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz; 
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';
import 'package:sympli_ai_health/firebase_options.dart';
import 'package:sympli_ai_health/app/services/router.dart';
import 'package:go_router/go_router.dart';
import 'package:sympli_ai_health/app/utils/logging.dart';
import 'package:sympli_ai_health/app/features/account/services/app_settings.dart';

final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

Future<void> _initNotifs() async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Johannesburg'));

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const settings = InitializationSettings(android: android, iOS: ios);

  await notificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload != null && payload.startsWith('/chat-ai')) {
        final uri = Uri.parse(payload);
        final condition = uri.queryParameters['condition'] ?? '';
        _navKey.currentContext?.go('/chat-ai?condition=$condition');
      }
    },
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  logI("dotenv loaded", name: "MAIN");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  logI("Firebase initialized", name: "MAIN");

  await _initNotifs();
  logI("Local notifications initialized", name: "MAIN");

  final openAiKey = dotenv.env['OPENAI_API_KEY'];
  if (openAiKey == null || openAiKey.isEmpty) {
    logW("OpenAI API Key not loaded", name: "MAIN");
  } else {
    logI("OpenAI API Key loaded (${openAiKey.substring(0, 8)}...)", name: "MAIN");
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(appSettingsProvider);

    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF37B7A5)),
      useMaterial3: true,
    );

    final theme = settings.darkModeEnabled
        ? baseTheme.copyWith(
            scaffoldBackgroundColor: const Color(0xFF0D1117),
            textTheme: baseTheme.textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
          )
        : baseTheme.copyWith(
            scaffoldBackgroundColor: Colors.white,
            textTheme: baseTheme.textTheme.apply(
              bodyColor: Colors.black87,
              displayColor: Colors.black87,
            ),
          );

    return MaterialApp.router(
      title: 'Sympli AI Health',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
    );
  }
}
