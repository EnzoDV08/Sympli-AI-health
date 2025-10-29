import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TextToSpeechService {
  final String apiKey = dotenv.env['GOOGLE_TTS_API_KEY'] ?? '';
  final _player = AudioPlayer();

  Future<void> speak(String text) async {
    if (apiKey.isEmpty) {
      print('❌ GOOGLE_TTS_API_KEY missing');
      return;
    }

    final url = Uri.parse(
        'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey');

    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {'languageCode': 'en-US', 'name': 'en-US-Neural2-F'},
          'audioConfig': {'audioEncoding': 'MP3'}
        }));

    if (response.statusCode == 200) {
      final bytes =
          base64.decode(jsonDecode(response.body)['audioContent']);
      await _player.play(BytesSource(Uint8List.fromList(bytes)));
    } else {
      print('TTS error: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> stop() async => _player.stop();
}
