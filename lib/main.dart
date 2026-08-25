import 'dart:convert';
import 'dart:typed_data';

import 'dart:ui' show PointerDeviceKind;

import 'dart:async';
import 'package:record/record.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_models.dart';
import 'screens/analysis_detail.dart';
import 'screens/analysis_summary.dart';
import 'screens/history_list.dart';
import 'screens/home_loading.dart';
import 'screens/home_recording.dart';
import 'screens/home_start.dart';
import 'screens/my_page.dart';
import 'theme/app_colors.dart';
import 'utils/result_mapper.dart' as mapper;
import 'widgets/bottom_nav.dart';

void main() {
  runApp(
    const PresentationCoachApp(),
  );
}


// ============================================================
// APP
// ============================================================

class PresentationCoachApp extends StatelessWidget {
  const PresentationCoachApp({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Presentation Coach',

      scrollBehavior:
          const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),

      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.gray50,
      ),

      home: const AppShell(),
    );
  }
}


// ============================================================
// APP SHELL
// ============================================================

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final AudioRecorder _audioRecorder = AudioRecorder();

  AppTab currentTab = AppTab.home;
  HomeScreen homeScreen = HomeScreen.start;
  RecordMode mode = RecordMode.voice;

  bool isRecording = false;
  bool _isStartingRecording = false;
  int recordingSeconds = 0;
  Timer? _recordingTimer;

  bool isAnalyzing = false;
  String? errorMessage;

  Map<String, dynamic>? currentResult;
  bool viewingFromHistory = false;

  List<Map<String, dynamic>> rawHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ============================================================
  // RECORDING
  // ============================================================

  Future<void> _startRecording() async {
    if (isAnalyzing || isRecording || _isStartingRecording) {
      return;
    }

    // await 구간 동안 중복 탭으로 재진입하는 것을 막기 위해
    // 동기적으로 즉시 가드를 세운다 (isRecording은 start() 완료 후에나 true가 됨).
    _isStartingRecording = true;

    try {
      setState(() {
        errorMessage = null;
      });

      final hasPermission = await _audioRecorder.hasPermission();

      if (!hasPermission) {
        setState(() {
          errorMessage = '마이크 권한을 허용해주세요.';
        });
        return;
      }

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ),
        path: 'presentation.wav',
      );

      setState(() {
        isRecording = true;
        recordingSeconds = 0;
        homeScreen = HomeScreen.recording;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          recordingSeconds++;
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = '녹음을 시작할 수 없습니다: $e';
      });
    } finally {
      _isStartingRecording = false;
    }
  }

  Future<void> _stopRecording() async {
    if (!isRecording) {
      return;
    }

    try {
      _recordingTimer?.cancel();

      final path = await _audioRecorder.stop();

      if (!mounted) return;

      setState(() {
        isRecording = false;
      });

      if (path == null) {
        throw Exception('녹음 파일을 생성하지 못했습니다.');
      }

      // Flutter Web에서는 녹음 파일이 blob:http://localhost:5173/... 형태로 반환됨
      final blobResponse = await http.get(Uri.parse(path));

      if (blobResponse.statusCode != 200) {
        throw Exception('녹음 파일을 불러오지 못했습니다.');
      }

      final bytes = blobResponse.bodyBytes;

      if (bytes.isEmpty) {
        throw Exception('녹음된 오디오가 비어 있습니다.');
      }

      await _analyzeWavBytes(bytes, filename: 'recorded_presentation.wav');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isRecording = false;
        homeScreen = HomeScreen.start;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // ANALYZE / UPLOAD
  // ============================================================

  Future<void> _analyzeWavBytes(
    Uint8List bytes, {
    String filename = 'presentation.wav',
  }) async {
    setState(() {
      isAnalyzing = true;
      errorMessage = null;
      homeScreen = HomeScreen.loading;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/analyze'),
      );

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        String detail = '분석 중 오류가 발생했습니다.';

        try {
          final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorJson is Map && errorJson['detail'] != null) {
            detail = errorJson['detail'].toString();
          }
        } catch (_) {}

        throw Exception(detail);
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        throw Exception('서버 응답 형식이 올바르지 않습니다.');
      }

      if (!mounted) return;

      await _saveAnalysisHistory(decoded);

      if (!mounted) return;

      setState(() {
        currentResult = decoded;
        viewingFromHistory = false;
        homeScreen = HomeScreen.summary;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        homeScreen = HomeScreen.start;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _pickAndAnalyzeWav() async {
    setState(() {
      errorMessage = null;
    });

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['wav', 'm4a'],
    );

    if (file == null) {
      return;
    }

    try {
      final bytes = await file.xFile.readAsBytes();
      await _analyzeWavBytes(bytes, filename: file.name);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // HISTORY (SharedPreferences)
  // ============================================================

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedHistory = prefs.getStringList('analysis_history') ?? [];

    final items = <Map<String, dynamic>>[];

    for (final item in savedHistory) {
      try {
        final decoded = jsonDecode(item);
        if (decoded is Map<String, dynamic>) {
          items.add(decoded);
        }
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      rawHistory = items;
    });
  }

  Future<void> _saveAnalysisHistory(Map<String, dynamic> result) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList('analysis_history') ?? [];

    final item = {
      'saved_at': DateTime.now().toIso8601String(),
      'result': result,
    };

    history.insert(0, jsonEncode(item));

    // MVP에서는 최근 20개만 저장
    if (history.length > 20) {
      history.removeRange(20, history.length);
    }

    await prefs.setStringList('analysis_history', history);
    await _loadHistory();
  }

  Future<void> _deleteHistoryItem(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final savedHistory = prefs.getStringList('analysis_history') ?? [];

    if (index < 0 || index >= savedHistory.length) {
      return;
    }

    savedHistory.removeAt(index);
    await prefs.setStringList('analysis_history', savedHistory);
    await _loadHistory();
  }

  List<HistoryItem> get _historyDisplayItems {
    return rawHistory.map((entry) {
      final result = entry['result'];
      final resultMap =
          result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
      final savedAt = DateTime.tryParse(entry['saved_at']?.toString() ?? '');
      return mapper.buildHistoryItem(resultMap, savedAt);
    }).toList();
  }

  void _openHistoryItem(int index) {
    final result = rawHistory[index]['result'];
    if (result is! Map) return;

    setState(() {
      currentResult = Map<String, dynamic>.from(result);
      viewingFromHistory = true;
      homeScreen = HomeScreen.summary;
    });
  }

  // ============================================================
  // NAVIGATION HELPERS
  // ============================================================

  void _handleSummaryBack() {
    setState(() {
      homeScreen = HomeScreen.start;
      if (viewingFromHistory) {
        currentTab = AppTab.history;
      }
      viewingFromHistory = false;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final showNav = homeScreen == HomeScreen.start;

    return Scaffold(
      body: Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 430),
          color: AppColors.white,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(child: _buildBody()),
                if (showNav)
                  BottomNav(
                    tab: currentTab,
                    onTab: (tab) => setState(() => currentTab = tab),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (homeScreen == HomeScreen.summary || homeScreen == HomeScreen.detail) {
      return _buildResultScreen();
    }

    switch (currentTab) {
      case AppTab.home:
        return _buildHomeScreen();
      case AppTab.history:
        return rawHistory.isEmpty
            ? HistoryEmpty(
                onStart: () => setState(() => currentTab = AppTab.home),
              )
            : HistoryList(
                items: _historyDisplayItems,
                onDelete: _deleteHistoryItem,
                onTap: _openHistoryItem,
              );
      case AppTab.mypage:
        return const MyPage();
    }
  }

  Widget _buildHomeScreen() {
    switch (homeScreen) {
      case HomeScreen.start:
        return HomeStart(
          mode: mode,
          onModeChanged: (m) => setState(() => mode = m),
          onRecord: _startRecording,
          onUpload: _pickAndAnalyzeWav,
          errorMessage: errorMessage,
        );
      case HomeScreen.recording:
        return HomeRecording(
          mode: mode,
          seconds: recordingSeconds,
          onStop: _stopRecording,
        );
      case HomeScreen.loading:
        return HomeLoading(mode: mode);
      case HomeScreen.summary:
      case HomeScreen.detail:
        return const SizedBox.shrink();
    }
  }

  Widget _buildResultScreen() {
    final result = currentResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final overall = mapper.buildOverall(result);
    final metrics = mapper.buildMetrics(result);

    if (homeScreen == HomeScreen.detail) {
      return AnalysisDetail(
        summary: overall.summary,
        level: overall.level,
        metrics: metrics,
        segments: mapper.buildSegments(result),
        strengths: mapper.buildStrengths(result),
        oneLineCoaching: mapper.buildOneLineCoaching(result),
        improvements: mapper.buildImprovements(result),
        practiceGoals: mapper.buildPracticeGoals(result),
        fullScript: mapper.buildFullScript(result),
        onBack: () => setState(() => homeScreen = HomeScreen.summary),
      );
    }

    return AnalysisSummary(
      summary: overall.summary,
      level: overall.level,
      metrics: metrics,
      onBack: _handleSummaryBack,
      onDetail: () => setState(() => homeScreen = HomeScreen.detail),
    );
  }
}
