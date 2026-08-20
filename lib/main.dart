import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


void main() {
  runApp(
    const PresentationCoachApp(),
  );
}


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
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}


class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
  });

  @override
  State<HomePage> createState() {
    return _HomePageState();
  }
}


class _HomePageState extends State<HomePage> {
  bool isLoading = false;

  String? errorMessage;


  Future<void> pickAndAnalyzeWav() async {
    setState(() {
      errorMessage = null;
    });

    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [
        'wav',
      ],
    );

    if (file == null) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final bytes =
          await file.xFile.readAsBytes();

      final request =
          http.MultipartRequest(
        'POST',
        Uri.parse(
          'http://127.0.0.1:8000/analyze',
        ),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: file.name,
        ),
      );

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode != 200) {
        String detail =
            '분석 중 오류가 발생했습니다.';

        try {
          final errorJson =
              jsonDecode(
            utf8.decode(
              response.bodyBytes,
            ),
          );

          if (
              errorJson is Map &&
              errorJson['detail'] != null
          ) {
            detail =
                errorJson['detail'].toString();
          }
        } catch (_) {}

        throw Exception(
          detail,
        );
      }

      final decoded =
          jsonDecode(
        utf8.decode(
          response.bodyBytes,
        ),
      );

      if (
          decoded is! Map<String, dynamic>
      ) {
        throw Exception(
          '서버 응답 형식이 올바르지 않습니다.',
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) {
            return ResultPage(
              result: decoded,
            );
          },
        ),
      );
    } catch (e) {
      setState(() {
        errorMessage =
            e
                .toString()
                .replaceFirst(
                  'Exception: ',
                  '',
                );
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(
        0xFFF5F6F8,
      ),
      body: Center(
        child: Container(
          width: double.infinity,
          constraints:
              const BoxConstraints(
            maxWidth: 430,
          ),
          color: Colors.white,
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Presentation Coach',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  const Text(
                    '발표를 녹음하고 AI 피드백을 받아보세요.',
                    style: TextStyle(
                      fontSize: 15,
                      color:
                          Colors.black54,
                    ),
                  ),

                  const Spacer(),

                  Center(
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration:
                          BoxDecoration(
                        shape:
                            BoxShape.circle,
                        color:
                            Colors.grey.shade100,
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        size: 80,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 32,
                  ),

                  const Center(
                    child: Text(
                      '발표 준비가 되셨나요?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  const Center(
                    child: Text(
                      '녹음하거나 WAV 파일을 업로드해\n발표 습관을 분석할 수 있습니다.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color:
                            Colors.black54,
                      ),
                    ),
                  ),

                  if (
                      errorMessage != null
                  ) ...[
                    const SizedBox(
                      height: 20,
                    ),

                    Container(
                      width:
                          double.infinity,
                      padding:
                          const EdgeInsets.all(
                        14,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.red.shade50,
                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),
                      child: Text(
                        errorMessage!,
                        style:
                            TextStyle(
                          color:
                              Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 56,
                    child:
                        FilledButton.icon(
                      onPressed:
                          isLoading
                              ? null
                              : () {},
                      icon:
                          const Icon(
                        Icons.mic,
                      ),
                      label:
                          const Text(
                        '발표 녹음 시작',
                        style:
                            TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    height: 52,
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          isLoading
                              ? null
                              : pickAndAnalyzeWav,
                      icon:
                          const Icon(
                        Icons.upload_file,
                      ),
                      label:
                          const Text(
                        'WAV 파일 업로드',
                        style:
                            TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),

                  if (
                      isLoading
                  ) ...[
                    const SizedBox(
                      height: 20,
                    ),

                    const Center(
                      child:
                          Column(
                        children: [
                          CircularProgressIndicator(),

                          SizedBox(
                            height: 12,
                          ),

                          Text(
                            '발표를 분석하고 있습니다...',
                            style:
                                TextStyle(
                              fontSize: 14,
                              color:
                                  Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class ResultPage extends StatelessWidget {
  final Map<String, dynamic> result;


  const ResultPage({
    super.key,
    required this.result,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final speech =
        Map<String, dynamic>.from(
      result['speech'] ?? {},
    );

    final risk =
        Map<String, dynamic>.from(
      result['risk'] ?? {},
    );

    final coaching =
        Map<String, dynamic>.from(
      result['coaching'] ?? {},
    );

    final fillers =
        List<Map<String, dynamic>>.from(
      (result['fillers'] ?? []).map(
        (item) =>
            Map<String, dynamic>.from(
          item,
        ),
      ),
    );

    final heatmap =
        List<Map<String, dynamic>>.from(
      (risk['heatmap'] ?? []).map(
        (item) =>
            Map<String, dynamic>.from(
          item,
        ),
      ),
    );

    final improvements =
        List<Map<String, dynamic>>.from(
      (coaching['improvements'] ?? [])
          .map(
        (item) =>
            Map<String, dynamic>.from(
          item,
        ),
      ),
    );

    final strengths =
        List<String>.from(
      coaching['strengths'] ?? [],
    );

    final practiceGoals =
        List<String>.from(
      coaching['practice_goals'] ?? [],
    );

    final fillerCount =
        fillers
            .where(
              (item) =>
                  item['type'] ==
                  'filler',
            )
            .length;

    final repetitionCount =
        fillers
            .where(
              (item) =>
                  item['type'] ==
                  'repetition',
            )
            .length;


    return Scaffold(
      backgroundColor:
          const Color(
        0xFFF5F6F8,
      ),
      body: Center(
        child: Container(
          width:
              double.infinity,
          constraints:
              const BoxConstraints(
            maxWidth: 430,
          ),
          color: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pop();
                        },
                        icon:
                            const Icon(
                          Icons.arrow_back,
                        ),
                      ),

                      const SizedBox(
                        width: 4,
                      ),

                      const Text(
                        '발표 분석 결과',
                        style:
                            TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      32,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        _SectionCard(
                          title:
                              'AI 종합 평가',
                          child:
                              Text(
                            coaching['summary']
                                    ?.toString() ??
                                '',
                            style:
                                const TextStyle(
                              fontSize: 15,
                              height: 1.55,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: '발표 속도',
                                value: _paceText(
                                  speech['pace_level']
                                      ?.toString(),
                                ),
                                unit: '',
                                subtitle:
                                    '${speech['presentation_rate'] ?? 0} 어절/분',
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(
                              child: _MetricCard(
                                title: '멈춤 비율',
                                value: _pausePercent(
                                  speech[
                                      'internal_pause_ratio'],
                                ),
                                unit: '%',
                                subtitle:
                                    '총 ${speech['internal_pause_time'] ?? 0}초',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: '추임새',
                                value: '$fillerCount',
                                unit: '회',
                                subtitle: '',
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(
                              child: _MetricCard(
                                title: '반복',
                                value: '$repetitionCount',
                                unit: '회',
                                subtitle: '',
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        _SectionCard(
                          title:
                              '구간별 분석',
                          child:
                              Column(
                            children:
                                heatmap.map(
                              (
                                window,
                              ) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(
                                    bottom: 12,
                                  ),
                                  child:
                                      _RiskWindowItem(
                                    window:
                                        window,
                                  ),
                                );
                              },
                            ).toList(),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        _SectionCard(
                          title:
                              '개선할 점',
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children:
                                improvements
                                    .asMap()
                                    .entries
                                    .map(
                              (
                                entry,
                              ) {
                                final index =
                                    entry.key;

                                final item =
                                    entry.value;

                                return Padding(
                                  padding:
                                      const EdgeInsets.only(
                                    bottom: 18,
                                  ),
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${index + 1}. ${item['title'] ?? ''}',
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              16,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),

                                      const SizedBox(
                                        height: 4,
                                      ),

                                      if ((item[
                                                  'time_range'] ??
                                              '')
                                          .toString()
                                          .isNotEmpty)
                                        Text(
                                          item[
                                                  'time_range']
                                              .toString(),
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                13,
                                            color:
                                                Colors.black45,
                                          ),
                                        ),

                                      const SizedBox(
                                        height: 6,
                                      ),

                                      Text(
                                        item[
                                                    'description']
                                                ?.toString() ??
                                            '',
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              14,
                                          height:
                                              1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ).toList(),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        _SectionCard(
                          title:
                              '다음 연습 목표',
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children:
                                practiceGoals
                                    .asMap()
                                    .entries
                                    .map(
                              (
                                entry,
                              ) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(
                                    bottom: 10,
                                  ),
                                  child:
                                      Text(
                                    '${entry.key + 1}. ${entry.value}',
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          14,
                                      height:
                                          1.45,
                                    ),
                                  ),
                                );
                              },
                            ).toList(),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        _SectionCard(
                          title:
                              '잘한 점',
                          child:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children:
                                strengths.map(
                              (
                                item,
                              ) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(
                                    bottom: 8,
                                  ),
                                  child:
                                      Text(
                                    '• $item',
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          14,
                                      height:
                                          1.45,
                                    ),
                                  ),
                                );
                              },
                            ).toList(),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        _SectionCard(
                          title:
                              '한 줄 코칭',
                          child:
                              Text(
                            coaching[
                                        'one_line_coaching']
                                    ?.toString() ??
                                '',
                            style:
                                const TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        _SectionCard(
                          title:
                              'STT 결과',
                          child:
                              Text(
                            result['transcript']
                                    ?.toString() ??
                                '',
                            style:
                                const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  static String _paceText(
    String? level,
  ) {
    switch (level) {
      case 'slow':
        return '느린 편';

      case 'fast':
        return '빠른 편';

      case 'normal':
        return '적정 범위';

      default:
        return '판정 없음';
    }
  }


  static String _pausePercent(
    dynamic ratio,
  ) {
    final value =
        ratio is num
            ? ratio.toDouble()
            : 0.0;

    return (
      value * 100
    ).toStringAsFixed(
      1,
    );
  }
}


class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final String subtitle;


  const _MetricCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 13,
              color:
                  Colors.black54,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Flexible(
                child:
                    Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize:
                        25,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(
                width: 4,
              ),

              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 3,
                ),
                child:
                    Text(
                  unit,
                  style:
                      const TextStyle(
                    fontSize:
                        12,
                    color:
                        Colors.black54,
                  ),
                ),
              ),
            ],
          ),

          if (subtitle.isNotEmpty) ...[
            const SizedBox(
              height: 4,
            ),

            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;


  const _SectionCard({
    required this.title,
    required this.child,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            offset:
                const Offset(
              0,
              2,
            ),
            color:
                Colors.black.withValues(
              alpha: 0.04,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          child,
        ],
      ),
    );
  }
}


class _RiskWindowItem extends StatelessWidget {
  final Map<String, dynamic> window;


  const _RiskWindowItem({
    required this.window,
  });


  @override
  Widget build(
    BuildContext context,
  ) {
    final start =
        window['start'] ?? 0;

    final end =
        window['end'] ?? 0;

    final level =
        window['level']
            ?.toString() ??
            'low';

    final score =
        window['score'] ?? 0;

    final reasons =
        List<String>.from(
      window['reasons'] ?? [],
    );

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text(
                  '${_formatSecond(start)} ~ ${_formatSecond(end)}',
                  style:
                      const TextStyle(
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),

              Text(
                '${level.toUpperCase()}  $score',
                style:
                    const TextStyle(
                  fontSize:
                      13,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),

          if (
              reasons.isNotEmpty
          ) ...[
            const SizedBox(
              height: 8,
            ),

            ...reasons.map(
              (
                reason,
              ) {
                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 3,
                  ),
                  child:
                      Text(
                    '• $reason',
                    style:
                        const TextStyle(
                      fontSize:
                          12,
                      color:
                          Colors.black54,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }


  static String _formatSecond(
    dynamic value,
  ) {
    final number =
        value is num
            ? value.toDouble()
            : 0.0;

    if (
        number ==
        number.roundToDouble()
    ) {
      return '${number.toInt()}초';
    }

    return '${number.toStringAsFixed(1)}초';
  }
}