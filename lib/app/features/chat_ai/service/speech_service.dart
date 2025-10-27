// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:flutter_sound/flutter_sound.dart';
// import 'package:http/http.dart' as http;
// import 'package:path_provider/path_provider.dart';
// import 'package:googleapis_auth/googleapis_auth.dart';


// class SpeechService {
//   final recorder = FlutterSoundRecorder();
//   bool _isRecording = false;

//   Future<void> init() async {
//     await recorder.openRecorder();
//   }

//   /// Record for 5 seconds and transcribe speech → text
//   Future<String?> recordAndTranscribe() async {
//     if (_isRecording) return null;
//     _isRecording = true;

//     final dir = await getTemporaryDirectory();
//     final filePath = '${dir.path}/speech_input.wav';

//     await recorder.startRecorder(
//       toFile: filePath,
//       codec: Codec.wav,
//     );

//     await Future.delayed(const Duration(seconds: 5));
//     final recordedFile = await recorder.stopRecorder();
//     _isRecording = false;

//     if (recordedFile == null) return null;

//     // 🔐 Auth
//     final authClient = await _getAuthClient();

//     final audioBytes = File(recordedFile).readAsBytesSync();
//     final audioBase64 = base64Encode(audioBytes);

//     final requestBody = jsonEncode({
//       "config": {
//         "encoding": "LINEAR16",
//         "sampleRateHertz": 16000,
//         "languageCode": "en-US",
//         "enableAutomaticPunctuation": true
//       },
//       "audio": {"content": audioBase64}
//     });

//     final response = await authClient.post(
//       Uri.parse('https://speech.googleapis.com/v1/speech:recognize'),
//       headers: {"Content-Type": "application/json"},
//       body: requestBody,
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       return data['results']?[0]?['alternatives']?[0]?['transcript'] ?? "";
//     } else {
//       print('❌ Speech API Error: ${response.body}');
//       return null;
//     }
//   }

//   Future<http.Client> _getAuthClient() async {
//     final keyPath = dotenv.env['GOOGLE_SPEECH_KEY_PATH'];
//     if (keyPath == null) throw Exception("Missing GOOGLE_SPEECH_KEY_PATH in .env");

//     final jsonString = await rootBundle.loadString(keyPath);
//     final jsonData = jsonDecode(jsonString);
//     final credentials = ServiceAccountCredentials.fromJson(jsonData);
//     final scopes = ['https://www.googleapis.com/auth/cloud-platform'];

//     return clientViaServiceAccount(credentials, scopes);
//   }

//   Future<void> dispose() async {
//     await recorder.closeRecorder();
//   }
// }
