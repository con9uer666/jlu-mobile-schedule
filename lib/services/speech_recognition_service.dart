import 'dart:io';

import 'package:flutter/services.dart';

class SpeechRecognitionService {
  const SpeechRecognitionService._();

  static const _channel = MethodChannel('com.jlu.schedule/speech');

  static Future<String> recognize() async {
    if (!Platform.isIOS) {
      throw PlatformException(code: 'unsupported', message: '语音输入目前仅支持 iPhone');
    }
    return (await _channel.invokeMethod<String>('recognize'))?.trim() ?? '';
  }

  static Future<void> stop() => _channel.invokeMethod<void>('stop');
}
