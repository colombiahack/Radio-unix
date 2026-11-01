import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:permission_handler/permission_handler.dart';
import 'player_service.dart';
import 'screens.dart';
import 'settings.dart';
import 'update.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.radiomundo.audio',
    androidNotificationChannelName: 'Radio Mundo',
    androidNotificationOngoing: true,
  );
  await PlayerService.i.init();
  await Settings.init();
  runApp(const RadioMundoApp());
  // Android 13+: sin este permiso no se ven los controles en segundo plano.
  WidgetsBinding.instance
      .addPostFrameCallback((_) {
    Permission.notification.request();
    checkForUpdate();
  });
}

class RadioMundoApp extends StatelessWidget {
  const RadioMundoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Radio Mundo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF00BFA5),
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.transparent,
        ),
        home: const HomeShell(),
      );
}
