import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'player_service.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.radiomundo.audio',
    androidNotificationChannelName: 'Radio Mundo',
    androidNotificationOngoing: true,
  );
  await PlayerService.i.init();
  runApp(const RadioMundoApp());
}

class RadioMundoApp extends StatelessWidget {
  const RadioMundoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Radio Mundo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const HomeShell(),
      );
}
