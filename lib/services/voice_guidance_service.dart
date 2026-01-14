import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// 음성 안내 서비스 (TTS)
class VoiceGuidanceService {
  static final VoiceGuidanceService _instance = VoiceGuidanceService._internal();
  factory VoiceGuidanceService() => _instance;
  VoiceGuidanceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  /// 서비스 초기화
  Future<void> init() async {
    if (_isInitialized) return;

    // 한국어 설정
    await _flutterTts.setLanguage("ko-KR");
    
    // 말하기 속도 및 피치 설정
    await _flutterTts.setSpeechRate(0.5); // iOS 기준 (0.0 ~ 1.0)
    await _flutterTts.setPitch(1.0);
    
    // 오디오 덕킹 설정 (안내 방송 시 배경 음악 볼륨 낮춤)
    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)) {
      await _flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
      ]);
    }

    _isInitialized = true;
    debugPrint('🎙️ VoiceGuidanceService initialized');
  }

  /// 텍스트 읽기
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    
    debugPrint('🗣️ Speaking: $text');
    await _flutterTts.speak(text);
  }

  /// 중지
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
