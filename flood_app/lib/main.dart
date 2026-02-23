import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';

// ─── Theme ────────────────────────────────────────────────────────────────────
const _bgDeep    = Color(0xFF080C14);
const _bgCard    = Color(0xFF0F1624);
const _bgSurface = Color(0xFF161E30);
const _accent    = Color(0xFF00E5FF);
const _accentDim = Color(0xFF0097A7);
const _danger    = Color(0xFFFF3B30);
const _safe      = Color(0xFF00E676);
const _warn      = Color(0xFFFFD600);
const _textPrimary   = Color(0xFFEEF2FF);
const _textSecondary = Color(0xFF7B8BB2);

// ─── Data ─────────────────────────────────────────────────────────────────────
enum AnalysisResult { none, proceed, turnBack }

class AnalysisRecord {
  final String imagePath;
  final AnalysisResult result;
  final String reason;
  final DateTime time;

  AnalysisRecord({required this.imagePath, required this.result, required this.reason, required this.time});

  Map<String, dynamic> toJson() => {
    'imagePath': imagePath,
    'result': result.index,
    'reason': reason,
    'time': time.toIso8601String(),
  };

  factory AnalysisRecord.fromJson(Map<String, dynamic> j) => AnalysisRecord(
    imagePath: j['imagePath'],
    result: AnalysisResult.values[j['result']],
    reason: j['reason'],
    time: DateTime.parse(j['time']),
  );
}

const _safetyTips = [
  "Never attempt to cross if water is above your tyres.",
  "Moving water is stronger than it looks — 6 inches can knock you down.",
  "Turn around, don't drown. Most flood deaths occur in vehicles.",
  "If swept away, exit the vehicle immediately and swim to safety.",
  "Flooded roads may have hidden damage or debris underneath.",
  "Avoid driving at night through unfamiliar flooded areas.",
  "Keep windows slightly open so you can escape if submerged.",
];

const _emergencyContacts = [
  {'name': 'Bomba (Fire & Rescue)', 'number': '994',        'icon': Icons.local_fire_department_rounded, 'color': 0xFFFF3B30},
  {'name': 'Police',                'number': '999',        'icon': Icons.local_police_rounded,           'color': 0xFF5E9EFF},
  {'name': 'Ambulance',             'number': '999',        'icon': Icons.emergency_rounded,              'color': 0xFF00E676},
  {'name': 'Civil Defence (APM)',   'number': '03-86888888','icon': Icons.shield_rounded,                 'color': 0xFFFFD600},
  {'name': 'JKM (Welfare Dept)',    'number': '15999',      'icon': Icons.people_rounded,                 'color': 0xFFCF6DFF},
  {'name': 'Tenaga Nasional (TNB)', 'number': '15454',      'icon': Icons.bolt_rounded,                   'color': 0xFFFFAB40},
];

const _floodAreas = [
  {'state': 'Kelantan',       'area': 'Kuala Krai, Gua Musang',    'risk': 'High'},
  {'state': 'Terengganu',     'area': 'Kuala Terengganu, Kemaman', 'risk': 'High'},
  {'state': 'Pahang',         'area': 'Temerloh, Kuantan',         'risk': 'High'},
  {'state': 'Johor',          'area': 'Kota Tinggi, Segamat',      'risk': 'High'},
  {'state': 'Perak',          'area': 'Sungai Perak Basin',        'risk': 'Medium'},
  {'state': 'Selangor',       'area': 'Shah Alam, Klang',          'risk': 'Medium'},
  {'state': 'Sabah',          'area': 'Tawau, Keningau',           'risk': 'Medium'},
  {'state': 'Sarawak',        'area': 'Kapit, Sri Aman',           'risk': 'Medium'},
  {'state': 'Kedah',          'area': 'Pendang, Baling',           'risk': 'Low'},
  {'state': 'Negeri Sembilan','area': 'Kuala Pilah',               'risk': 'Low'},
];

// ─── Entry ────────────────────────────────────────────────────────────────────
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
    theme: _appTheme(),
    home: const Scaffold(backgroundColor: _bgDeep,
        body: Center(child: Text("No Camera Found.", style: TextStyle(color: _textSecondary)))),
  );
}

ThemeData _appTheme() => ThemeData.dark().copyWith(
  scaffoldBackgroundColor: _bgDeep,
  colorScheme: const ColorScheme.dark(primary: _accent, secondary: _accentDim, surface: _bgCard),
);

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({Key? key, required this.camera}) : super(key: key);
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Projek Awaas',
    theme: _appTheme(),
    debugShowCheckedModeBanner: false,
    home: FloodVisionScreen(camera: camera),
  );
}

// ─── Main Screen ──────────────────────────────────────────────────────────────
class FloodVisionScreen extends StatefulWidget {
  final CameraDescription camera;
  const FloodVisionScreen({Key? key, required this.camera}) : super(key: key);
  @override
  State<FloodVisionScreen> createState() => _FloodVisionScreenState();
}

class _FloodVisionScreenState extends State<FloodVisionScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late CameraController _controller;
  late Future<void> _initFuture;

  bool _isAnalyzing = false;
  AnalysisResult _result = AnalysisResult.none;
  String _analysisReason = "";
  String? _capturedImagePath;

  List<AnalysisRecord> _history = [];
  StreamSubscription? _jobSubscription;
  int _currentTipIndex = 0;

  late AnimationController _pulseCtrl;
  late AnimationController _resultCtrl;
  late Animation<double> _resultScale;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high, enableAudio: false);
    _initFuture = _controller.initialize();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _resultScale = CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut);

    _rotateTip();
    _signInAnonymously();
    _loadHistory();
  }

  // ── Persistence ──────────────────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('scan_history') ?? [];
    setState(() {
      _history = raw
          .map((e) => AnalysisRecord.fromJson(jsonDecode(e)))
          .where((r) => File(r.imagePath).existsSync())
          .toList();
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('scan_history', _history.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scan_history');
    setState(() => _history.clear());
  }

  void _rotateTip() {
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _currentTipIndex = (_currentTipIndex + 1) % _safetyTips.length);
      _rotateTip();
    });
  }

  Future<void> _signInAnonymously() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    _jobSubscription?.cancel();
    super.dispose();
  }

  void _resetState() {
    _resultCtrl.reset();
    setState(() {
      _isAnalyzing = false;
      _result = AnalysisResult.none;
      _analysisReason = "";
      _capturedImagePath = null;
    });
  }

  Future<void> _captureAndAnalyze() async {
    if (_isAnalyzing) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isAnalyzing = true;
      _result = AnalysisResult.none;
      _analysisReason = "";
      _capturedImagePath = null;
    });

    try {
      await _initFuture;
      final image = await _controller.takePicture();
      setState(() => _capturedImagePath = image.path);

      final jobRef = await FirebaseFirestore.instance.collection('analysis_jobs').add({
        'status': 'processing',
        'result': null,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });
      final jobId = jobRef.id;

      _jobSubscription?.cancel();
      _jobSubscription = jobRef.snapshots().listen((snapshot) {
        final data = snapshot.data();
        if (data == null) return;
        final status = data['status'];
        if (status == 'completed') {
          final resultData = data['result'];
          final decision = resultData['decision'] == 'PROCEED' ? AnalysisResult.proceed : AnalysisResult.turnBack;
          final reason = resultData['reason'] as String;
          final record = AnalysisRecord(imagePath: image.path, result: decision, reason: reason, time: DateTime.now());
          setState(() {
            _history.insert(0, record);
            _result = decision;
            _analysisReason = reason;
            _isAnalyzing = false;
          });
          _saveHistory();
          _resultCtrl.forward();
          HapticFeedback.heavyImpact();
          _jobSubscription?.cancel();
        } else if (status == 'failed') {
          setState(() {
            _result = AnalysisResult.turnBack;
            _analysisReason = data['error'] ?? "Analysis failed on server.";
            _isAnalyzing = false;
          });
          _resultCtrl.forward();
          _jobSubscription?.cancel();
        }
      });

      Future.delayed(const Duration(minutes: 2), () {
        if (_isAnalyzing && mounted) {
          setState(() {
            _result = AnalysisResult.turnBack;
            _analysisReason = "Analysis timed out. Please try again.";
            _isAnalyzing = false;
          });
          _resultCtrl.forward();
          _jobSubscription?.cancel();
        }
      });

      await FirebaseStorage.instance.ref().child('uploads/$jobId.jpg').putFile(File(image.path));
    } catch (e) {
      setState(() {
        _result = AnalysisResult.turnBack;
        _analysisReason = "Connection error. Check internet and try again.";
        _isAnalyzing = false;
      });
      _resultCtrl.forward();
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bgDeep,
      drawer: _buildDrawer(),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          return Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildViewfinder()),
              _buildInfoBar(),
              _buildBottomPanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _bgCard,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: _accent.withValues(alpha: 0.15))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: _accentDim.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.water_rounded, color: _accent, size: 28),
                  ),
                  const SizedBox(height: 14),
                  const Text("PROJEK AWAAS",
                      style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  const Text("Your AI Flood Safety Co-Pilot",
                      style: TextStyle(color: _textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _DrawerItem(icon: Icons.menu_book_rounded,    label: "How to Use",         onTap: () => _openPage(const _HowToUsePage())),
                  _DrawerItem(icon: Icons.map_rounded,          label: "Flood Risk Map",      onTap: () => _openPage(const _FloodRiskMapPage())),
                  _DrawerItem(icon: Icons.contact_phone_rounded, label: "Emergency Contacts", onTap: () => _openPage(const _EmergencyContactsPage())),
                  _DrawerItem(
                    icon: Icons.history_rounded,
                    label: "Scan History",
                    badge: _history.isEmpty ? null : "${_history.length}",
                    onTap: () => _openPage(_HistoryPage(history: _history, onClear: _clearHistory)),
                  ),
                  const Divider(color: Color(0xFF1E2A42), height: 28, indent: 20, endIndent: 20),
                  _DrawerItem(icon: Icons.info_outline_rounded, label: "About Projek Awaas",  onTap: () => _openPage(const _AboutPage())),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: const Text("v1.0.0 · KitaHack 2026",
                  style: TextStyle(color: _textSecondary, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _accentDim.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.water_rounded, color: _accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("PROJEK AWAAS",
                          style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
                      Text("Flood Safety Advisor",
                          style: TextStyle(color: _textSecondary, fontSize: 11, letterSpacing: 0.5)),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accent.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.menu_rounded, color: _accent, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinder() {
    Color borderColor = _bgSurface;
    if (_isAnalyzing) borderColor = _warn;
    else if (_result == AnalysisResult.proceed)  borderColor = _safe;
    else if (_result == AnalysisResult.turnBack) borderColor = _danger;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            if (_result == AnalysisResult.proceed)
              BoxShadow(color: _safe.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 2),
            if (_result == AnalysisResult.turnBack)
              BoxShadow(color: _danger.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 2),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_capturedImagePath == null) CameraPreview(_controller)
              else Image.file(File(_capturedImagePath!), fit: BoxFit.cover),
              if (_capturedImagePath == null)
                CustomPaint(painter: _BracketPainter(color: _accent.withValues(alpha: 0.6))),
              if (_isAnalyzing) _buildScanningOverlay(),
              if (_capturedImagePath != null && !_isAnalyzing && _result != AnalysisResult.none)
                _buildResultOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              _warn.withValues(alpha: 0.0),
              _warn.withValues(alpha: 0.08 * _pulseCtrl.value),
              _warn.withValues(alpha: 0.0),
            ],
            stops: [0, _pulseCtrl.value, 1],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 56, height: 56,
                  child: CircularProgressIndicator(color: _warn, strokeWidth: 3)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text("ANALYZING FLOOD CONDITIONS",
                    style: TextStyle(color: _warn, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final isProceed = _result == AnalysisResult.proceed;
    final color = isProceed ? _safe : _danger;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ScaleTransition(
        scale: _resultScale,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(isProceed ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isProceed ? "PROCEED" : "TURN BACK",
                        style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text(_analysisReason,
                        style: const TextStyle(color: _textSecondary, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey(_currentTipIndex),
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accentDim.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: _warn, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_safetyTips[_currentTipIndex],
                  style: const TextStyle(color: _textSecondary, fontSize: 12, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: _isAnalyzing
            ? const Center(child: Text("Gemini AI is analyzing your image…",
                style: TextStyle(color: _textSecondary, fontSize: 13)))
            : _result != AnalysisResult.none
                ? _PrimaryButton(label: "SCAN AGAIN", icon: Icons.refresh_rounded, color: _accent, onTap: _resetState)
                : _PrimaryButton(label: "ANALYZE FLOOD", icon: Icons.water_rounded, color: _accent, onTap: _captureAndAnalyze),
      ),
    );
  }
}

// ─── Drawer Item ──────────────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;
  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: _bgSurface, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: _accent, size: 18),
      ),
      title: Text(label, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: badge != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge!, style: const TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w700)),
            )
          : const Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 20),
      onTap: onTap,
    );
  }
}

// ─── Primary Button ───────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _bgDeep, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: _bgDeep, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAGES
// ═══════════════════════════════════════════════════════════════════════════════

// ─── How to Use ───────────────────────────────────────────────────────────────
class _HowToUsePage extends StatelessWidget {
  const _HowToUsePage();
  static const _steps = [
    {'icon': Icons.location_on_rounded,    'title': 'Find a Flooded Road',    'desc': 'Approach a flooded area you need to cross. Keep your distance initially.'},
    {'icon': Icons.camera_alt_rounded,     'title': 'Open the App & Point',   'desc': 'Launch Projek Awaas and point your phone camera clearly at the flooded road ahead.'},
    {'icon': Icons.touch_app_rounded,      'title': 'Tap "Analyze Flood"',    'desc': 'Press the Analyze button. The app captures the image and sends it to our AI instantly.'},
    {'icon': Icons.cloud_upload_rounded,   'title': 'AI Processes the Image', 'desc': 'Google\'s Gemini AI model assesses water depth, flow, and road visibility.'},
    {'icon': Icons.check_circle_rounded,   'title': 'Get Your Decision',      'desc': 'In seconds, you\'ll see PROCEED (safe) or TURN BACK (dangerous) with a clear reason.'},
    {'icon': Icons.directions_car_rounded, 'title': 'Act on the Result',      'desc': 'Always follow the AI\'s advice. If in doubt, turn back — no road is worth your life.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: _AwaasAppBar(title: "How to Use"),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _steps.length,
        itemBuilder: (_, i) => _StepCard(
          number: i + 1,
          total: _steps.length,
          icon: _steps[i]['icon'] as IconData,
          title: _steps[i]['title'] as String,
          desc: _steps[i]['desc'] as String,
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number, total;
  final IconData icon;
  final String title, desc;
  const _StepCard({required this.number, required this.total, required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: _accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Center(child: Text("$number", style: const TextStyle(color: _accent, fontWeight: FontWeight.w800, fontSize: 14))),
              ),
              if (number < total)
                Container(width: 2, height: 20, color: _accent.withValues(alpha: 0.15)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, color: _accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: const TextStyle(color: _textPrimary, fontSize: 15, fontWeight: FontWeight.w700))),
                  ]),
                  const SizedBox(height: 6),
                  Text(desc, style: const TextStyle(color: _textSecondary, fontSize: 13, height: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Flood Risk Map ───────────────────────────────────────────────────────────
class _FloodRiskMapPage extends StatelessWidget {
  const _FloodRiskMapPage();

  Color _riskColor(String risk) {
    if (risk == 'High')   return _danger;
    if (risk == 'Medium') return _warn;
    return _safe;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: _AwaasAppBar(title: "Flood Risk Map"),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accentDim.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _LegendDot(color: _danger, label: "High Risk"),
                _LegendDot(color: _warn,   label: "Medium Risk"),
                _LegendDot(color: _safe,   label: "Low Risk"),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _warn.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _warn.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, color: _warn, size: 14),
                SizedBox(width: 8),
                Expanded(child: Text("Based on historical flood data (2015–2024). Check JPS Malaysia for real-time alerts.",
                    style: TextStyle(color: _warn, fontSize: 11, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: _floodAreas.length,
              itemBuilder: (_, i) {
                final area = _floodAreas[i];
                final color = _riskColor(area['risk']!);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(area['state']!, style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(area['area']!, style: const TextStyle(color: _textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(area['risk']!, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: _textSecondary, fontSize: 12)),
    ],
  );
}

// ─── Emergency Contacts ───────────────────────────────────────────────────────
class _EmergencyContactsPage extends StatelessWidget {
  const _EmergencyContactsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: _AwaasAppBar(title: "Emergency Contacts"),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: _danger, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text(
                  "In an emergency, call 999 immediately. Do not attempt to cross dangerous floodwaters.",
                  style: TextStyle(color: _textPrimary, fontSize: 13, height: 1.4),
                )),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: _emergencyContacts.length,
              itemBuilder: (_, i) {
                final c = _emergencyContacts[i];
                final color = Color(c['color'] as int);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(c['icon'] as IconData, color: color, size: 22),
                    ),
                    title: Text(c['name'] as String,
                        style: const TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: Text(c['number'] as String,
                        style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    trailing: GestureDetector(
                      onTap: () async {
                        final uri = Uri(scheme: 'tel', path: c['number'] as String);
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      },
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                        child: Icon(Icons.call_rounded, color: color, size: 20),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── History Page ─────────────────────────────────────────────────────────────
class _HistoryPage extends StatelessWidget {
  final List<AnalysisRecord> history;
  final VoidCallback onClear;
  const _HistoryPage({required this.history, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: AppBar(
        backgroundColor: _bgCard,
        title: const Text("Scan History", style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: _accent),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              onPressed: () { onClear(); Navigator.pop(context); },
              child: const Text("Clear All", style: TextStyle(color: _danger, fontSize: 13)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _accent.withValues(alpha: 0.1)),
        ),
      ),
      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, color: _textSecondary, size: 52),
                  SizedBox(height: 12),
                  Text("No scans yet", style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text("Your scan history will appear here", style: TextStyle(color: _textSecondary, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (_, i) {
                final rec = history[i];
                final isProceed = rec.result == AnalysisResult.proceed;
                final color = isProceed ? _safe : _danger;
                final timeStr =
                    "${rec.time.day.toString().padLeft(2,'0')}/${rec.time.month.toString().padLeft(2,'0')}/${rec.time.year}  "
                    "${rec.time.hour.toString().padLeft(2,'0')}:${rec.time.minute.toString().padLeft(2,'0')}";
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(File(rec.imagePath), width: 64, height: 64, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64, height: 64, color: _bgSurface,
                            child: const Icon(Icons.broken_image_outlined, color: _textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(isProceed ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 16),
                                const SizedBox(width: 6),
                                Text(isProceed ? "PROCEED" : "TURN BACK",
                                    style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(rec.reason,
                                style: const TextStyle(color: _textSecondary, fontSize: 12, height: 1.4),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 5),
                            Text(timeStr, style: const TextStyle(color: _textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ─── About Page ───────────────────────────────────────────────────────────────
class _AboutPage extends StatelessWidget {
  const _AboutPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      appBar: _AwaasAppBar(title: "About"),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _bgCard, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _accentDim.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.water_rounded, color: _accent, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text("PROJEK AWAAS",
                      style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3)),
                  const SizedBox(height: 6),
                  const Text("Your AI Safety Co-Pilot for Flooded Roads",
                      textAlign: TextAlign.center, style: TextStyle(color: _textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accent.withValues(alpha: 0.3)),
                    ),
                    child: const Text("v1.0.0 · KitaHack 2026",
                        style: TextStyle(color: _accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accentDim.withValues(alpha: 0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("UN SDG Alignment", style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SdgBadge(number: "3",  label: "Good Health\n& Well-being", color: const Color(0xFF4CAF50)),
                      const SizedBox(width: 8),
                      _SdgBadge(number: "11", label: "Sustainable\nCities",        color: const Color(0xFFFF9800)),
                      const SizedBox(width: 8),
                      _SdgBadge(number: "13", label: "Climate\nAction",            color: const Color(0xFF3F51B5)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accentDim.withValues(alpha: 0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Technology Stack", style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  ...[
                    [Icons.phone_android_rounded, "Frontend",  "Flutter & Dart"],
                    [Icons.cloud_rounded,          "Backend",   "Google Cloud Functions (Python)"],
                    [Icons.psychology_rounded,     "AI Model",  "Vertex AI · Gemini"],
                    [Icons.storage_rounded,        "Database",  "Cloud Firestore"],
                    [Icons.folder_rounded,         "Storage",   "Firebase Storage"],
                    [Icons.lock_rounded,           "Auth",      "Firebase Authentication"],
                  ].map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(row[0] as IconData, color: _accent, size: 16),
                        const SizedBox(width: 10),
                        Text(row[1] as String, style: const TextStyle(color: _textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(row[2] as String, style: const TextStyle(color: _textPrimary, fontSize: 12)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _bgCard, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accentDim.withValues(alpha: 0.2))),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Our Mission", style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  SizedBox(height: 10),
                  Text(
                    "Floods are one of Malaysia's most recurring disasters. Projek Awaas was built to eliminate the dangerous guesswork drivers face at flooded roads — giving anyone an instant, AI-powered safety verdict using just their phone camera.",
                    style: TextStyle(color: _textSecondary, fontSize: 13, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SdgBadge extends StatelessWidget {
  final String number, label;
  final Color color;
  const _SdgBadge({required this.number, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text("SDG $number", style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: _textSecondary, fontSize: 10, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

// ─── Shared AppBar ────────────────────────────────────────────────────────────
class _AwaasAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  const _AwaasAppBar({required this.title});
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);
  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: _bgCard,
    elevation: 0,
    title: Text(title, style: const TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
    iconTheme: const IconThemeData(color: _accent),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _accent.withValues(alpha: 0.1)),
    ),
  );
}

// ─── Bracket Painter ──────────────────────────────────────────────────────────
class _BracketPainter extends CustomPainter {
  final Color color;
  _BracketPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const len = 24.0, pad = 20.0;
    canvas.drawLine(Offset(pad, pad + len), Offset(pad, pad), paint);
    canvas.drawLine(Offset(pad, pad), Offset(pad + len, pad), paint);
    canvas.drawLine(Offset(size.width - pad - len, pad), Offset(size.width - pad, pad), paint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + len), paint);
    canvas.drawLine(Offset(pad, size.height - pad - len), Offset(pad, size.height - pad), paint);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + len, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad - len, size.height - pad), Offset(size.width - pad, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad - len), Offset(size.width - pad, size.height - pad), paint);
  }
  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}