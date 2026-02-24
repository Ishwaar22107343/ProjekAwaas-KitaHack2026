import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../constants.dart';
import '../models/analysis_record.dart';
import '../widgets/drawer_item.dart';
import '../widgets/primary_button.dart';
import '../widgets/bracket_painter.dart';
import 'how_to_use_page.dart';
import 'flood_risk_map_page.dart';
import 'emergency_contacts_page.dart';
import 'history_page.dart';
import 'about_page.dart';

class FloodVisionScreen extends StatefulWidget {
  final CameraDescription camera;
  const FloodVisionScreen({Key? key, required this.camera}) : super(key: key);

  @override
  State<FloodVisionScreen> createState() => _FloodVisionScreenState();
}

class _FloodVisionScreenState extends State<FloodVisionScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Camera
  late CameraController _controller;
  late Future<void> _initFuture;

  // Analysis state
  bool _isAnalyzing = false;
  AnalysisResult _result = AnalysisResult.none;
  String _analysisReason = "";
  String? _capturedImagePath;

  // History & subscriptions
  List<AnalysisRecord> _history = [];
  StreamSubscription? _jobSubscription;

  // Tips rotation
  int _currentTipIndex = 0;

  // Animations
  late AnimationController _pulseCtrl;
  late AnimationController _resultCtrl;
  late Animation<double> _resultScale;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

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

  @override
  void dispose() {
    _controller.dispose();
    _pulseCtrl.dispose();
    _resultCtrl.dispose();
    _jobSubscription?.cancel();
    super.dispose();
  }

  // ── Persistence ────────────────────────────────────────────────────────────

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
    await prefs.setStringList(
      'scan_history',
      _history.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scan_history');
    setState(() => _history.clear());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _rotateTip() {
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _currentTipIndex = (_currentTipIndex + 1) % safetyTips.length);
      _rotateTip();
    });
  }

  Future<void> _signInAnonymously() async {
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }
    } catch (_) {}
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

  void _openPage(Widget page) {
    Navigator.pop(context); // close drawer
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // ── Analysis ───────────────────────────────────────────────────────────────

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
          final decision = resultData['decision'] == 'PROCEED'
              ? AnalysisResult.proceed
              : AnalysisResult.turnBack;
          final reason = resultData['reason'] as String;
          final record = AnalysisRecord(
            imagePath: image.path,
            result: decision,
            reason: reason,
            time: DateTime.now(),
          );
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

      // Timeout fallback
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

      await FirebaseStorage.instance
          .ref()
          .child('uploads/$jobId.jpg')
          .putFile(File(image.path));
    } catch (e) {
      setState(() {
        _result = AnalysisResult.turnBack;
        _analysisReason = "Connection error. Check internet and try again.";
        _isAnalyzing = false;
      });
      _resultCtrl.forward();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgDeep,
      drawer: _buildDrawer(),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: accent));
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

  // ── Drawer ─────────────────────────────────────────────────────────────────

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: bgCard,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: accent.withValues(alpha: 0.15))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accentDim.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.water_rounded, color: accent, size: 28),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "PROJEK AWAAS",
                    style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Your AI Flood Safety Co-Pilot",
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Nav items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  DrawerItem(icon: Icons.menu_book_rounded,     label: "How to Use",          onTap: () => _openPage(const HowToUsePage())),
                  DrawerItem(icon: Icons.map_rounded,           label: "Flood Risk Map",       onTap: () => _openPage(const FloodRiskMapPage())),
                  DrawerItem(icon: Icons.contact_phone_rounded, label: "Emergency Contacts",   onTap: () => _openPage(const EmergencyContactsPage())),
                  DrawerItem(
                    icon: Icons.history_rounded,
                    label: "Scan History",
                    badge: _history.isEmpty ? null : "${_history.length}",
                    onTap: () => _openPage(HistoryPage(history: _history, onClear: _clearHistory)),
                  ),
                  const Divider(color: Color(0xFF1E2A42), height: 28, indent: 20, endIndent: 20),
                  DrawerItem(icon: Icons.info_outline_rounded,  label: "About Projek Awaas",   onTap: () => _openPage(const AboutPage())),
                ],
              ),
            ),
            // Version
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "v1.0.0 · KitaHack 2026",
                style: TextStyle(color: textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentDim.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: accent.withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.water_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("PROJEK AWAAS",
                          style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
                      Text("Flood Safety Advisor",
                          style: TextStyle(color: textSecondary, fontSize: 11, letterSpacing: 0.5)),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.menu_rounded, color: accent, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Viewfinder ─────────────────────────────────────────────────────────────

  Widget _buildViewfinder() {
    Color borderColor = bgSurface;
    if (_isAnalyzing)                           borderColor = warn;
    else if (_result == AnalysisResult.proceed) borderColor = safe;
    else if (_result == AnalysisResult.turnBack) borderColor = danger;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            if (_result == AnalysisResult.proceed)
              BoxShadow(color: safe.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 2),
            if (_result == AnalysisResult.turnBack)
              BoxShadow(color: danger.withValues(alpha: 0.25), blurRadius: 24, spreadRadius: 2),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_capturedImagePath == null)
                CameraPreview(_controller)
              else
                Image.file(File(_capturedImagePath!), fit: BoxFit.cover),
              if (_capturedImagePath == null)
                CustomPaint(painter: BracketPainter(color: accent.withValues(alpha: 0.6))),
              if (_isAnalyzing)
                _buildScanningOverlay(),
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
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              warn.withValues(alpha: 0.0),
              warn.withValues(alpha: 0.08 * _pulseCtrl.value),
              warn.withValues(alpha: 0.0),
            ],
            stops: [0, _pulseCtrl.value, 1],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(color: warn, strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "ANALYZING FLOOD CONDITIONS",
                  style: TextStyle(color: warn, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultOverlay() {
    final isProceed = _result == AnalysisResult.proceed;
    final color = isProceed ? safe : danger;

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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isProceed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isProceed ? "PROCEED" : "TURN BACK",
                      style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _analysisReason,
                      style: const TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Info Bar ───────────────────────────────────────────────────────────────

  Widget _buildInfoBar() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey(_currentTipIndex),
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentDim.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded, color: warn, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                safetyTips[_currentTipIndex],
                style: const TextStyle(color: textSecondary, fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Panel ───────────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: _isAnalyzing
            ? const Center(
                child: Text(
                  "Gemini AI is analyzing your image…",
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              )
            : _result != AnalysisResult.none
                ? PrimaryButton(label: "SCAN AGAIN",     icon: Icons.refresh_rounded, color: accent, onTap: _resetState)
                : PrimaryButton(label: "ANALYZE FLOOD",  icon: Icons.water_rounded,   color: accent, onTap: _captureAndAnalyze),
      ),
    );
  }
}