import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

enum AnalysisResult { none, proceed, turnBack }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final cameras = await availableCameras();
  if (cameras.isEmpty) {
    runApp(const NoCameraApp());
    return;
  }
  runApp(MyApp(camera: cameras.first));
}

class NoCameraApp extends StatelessWidget {
  const NoCameraApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => const MaterialApp(
      home: Scaffold(body: Center(child: Text("No Cameras Found."))));
}

class MyApp extends StatelessWidget {
  final CameraDescription? camera;
  const MyApp({Key? key, required this.camera}) : super(key: key);
  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Projek Awaas',
      theme: ThemeData.dark(),
      home: FloodVisionScreen(camera: camera));
}

class FloodVisionScreen extends StatefulWidget {
  final CameraDescription? camera;
  const FloodVisionScreen({Key? key, required this.camera}) : super(key: key);
  @override
  _FloodVisionScreenState createState() => _FloodVisionScreenState();
}

class _FloodVisionScreenState extends State<FloodVisionScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isAnalyzing = false;
  AnalysisResult _result = AnalysisResult.none;
  String _analysisReason = "";
  String? _capturedImagePath;

  @override
  void initState() {
    super.initState();
    _signInAnonymously();

    if (widget.camera != null) {
      _controller = CameraController(widget.camera!, ResolutionPreset.medium,
          enableAudio: false);
      _initializeControllerFuture = _controller!.initialize();
    }
  }

  Future<void> _signInAnonymously() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (e) {
      // Handle sign-in failure if necessary
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _resetState() {
    setState(() {
      _isAnalyzing = false;
      _result = AnalysisResult.none;
      _analysisReason = "";
      _capturedImagePath = null;
    });
  }

  Future<void> _captureAndAnalyze() async {
    if (_isAnalyzing || _controller == null) return;

    setState(() {
      _isAnalyzing = true;
      _result = AnalysisResult.none;
      _analysisReason = "";
      _capturedImagePath = null; // Reset image path at the start
    });

    try {
      // STEP 1: Capture the image FIRST.
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      
      // Update the UI to show the captured image immediately.
      setState(() {
        _capturedImagePath = image.path;
      });

      // STEP 2: Now, try to communicate with Firebase.
      final jobRef =
          await FirebaseFirestore.instance.collection('analysis_jobs').add({
        'status': 'processing',
        'result': null,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
      final jobId = jobRef.id;

      final subscription = jobRef.snapshots().listen((snapshot) {
        final data = snapshot.data();
        if (data != null) {
          final status = data['status'];
          if (status == 'completed') {
            final resultData = data['result'];
            setState(() {
              _result = (resultData['decision'] == 'PROCEED')
                  ? AnalysisResult.proceed
                  : AnalysisResult.turnBack;
              _analysisReason = resultData['reason'];
              _isAnalyzing = false;
            });
          } else if (status == 'failed') {
            setState(() {
              _result = AnalysisResult.turnBack;
              _analysisReason = data['error'] ?? "Analysis failed on server.";
              _isAnalyzing = false;
            });
          }
        }
      });
      
      // STEP 3: Upload the image.
      final fileName = 'uploads/$jobId.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      await storageRef.putFile(File(image.path));
      
      Future.delayed(const Duration(minutes: 2), () {
        subscription.cancel();
      });

    } catch (e) {
      // If ANY of the above fails (especially network), update the UI with a clear error.
      setState(() {
        _result = AnalysisResult.turnBack;
        _analysisReason = "Connection Error. Check internet and try again.";
        _isAnalyzing = false;
        // Keep _capturedImagePath so the user can see what failed.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            Color borderColor = Colors.transparent;
            if (_isAnalyzing) {
              borderColor = Colors.yellow;
            } else if (_result == AnalysisResult.proceed) {
              borderColor = Colors.green;
            } else if (_result == AnalysisResult.turnBack) {
              borderColor = Colors.red;
            }

            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 8.0),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_capturedImagePath == null)
                    CameraPreview(_controller!)
                  else
                    Image.file(File(_capturedImagePath!), fit: BoxFit.cover),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      if (_capturedImagePath != null) _buildAnalysisBanner(),
                      const Spacer(),
                      _buildBottomButtonArea(),
                    ],
                  ),
                ],
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Widget _buildAnalysisBanner() {
    String title = "";
    String subtitle = "";

    if (_isAnalyzing) {
      title = "ANALYZING...";
      subtitle = "Please wait, assessing conditions.";
    } else if (_result != AnalysisResult.none) {
      title = _result == AnalysisResult.proceed ? 'PROCEED' : 'TURN BACK';
      subtitle = _analysisReason;
    }

    if (title.isEmpty && subtitle.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (subtitle.isNotEmpty) const SizedBox(height: 8),
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomButtonArea() {
    Widget buttonContent;

    if (_result != AnalysisResult.none) {
      buttonContent = ElevatedButton(
        onPressed: _resetState,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        child: const Text('Analyze Again'),
      );
    } else if (_isAnalyzing) {
      buttonContent = const Padding(
        padding: EdgeInsets.all(12.0),
        child: CircularProgressIndicator(color: Colors.white),
      );
    } else {
      buttonContent = ElevatedButton(
        onPressed: _captureAndAnalyze,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        child: const Text('Analyze'),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      width: double.infinity,
      color: Colors.black.withOpacity(0.5),
      child: Center(child: buttonContent),
    );
  }
}