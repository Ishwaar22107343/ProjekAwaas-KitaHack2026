import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'screens/flood_vision_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final cameras = await availableCameras();
  if (cameras.isEmpty) {
    runApp(const _NoCameraApp());
    return;
  }
  runApp(MyApp(camera: cameras.first));
}

class _NoCameraApp extends StatelessWidget {
  const _NoCameraApp();
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: appTheme(),
    home: const Scaffold(
      backgroundColor: bgDeep,
      body: Center(
        child: Text("No Camera Found.",
            style: TextStyle(color: textSecondary)),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Projek Awaas',
    theme: appTheme(),
    debugShowCheckedModeBanner: false,
    home: FloodVisionScreen(camera: camera),
  );
}