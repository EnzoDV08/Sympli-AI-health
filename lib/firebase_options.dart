import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions]
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA5I3AM1pFmM07KFeCfBukZcA6-auum_r4',
    appId: '1:526754016534:web:89a27dbe25836f17d43437',
    messagingSenderId: '526754016534',
    projectId: 'sympli-ai-health',
    authDomain: 'sympli-ai-health.firebaseapp.com',
    storageBucket: 'sympli-ai-health.firebasestorage.app',
    measurementId: 'G-38YK2CZRE0',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDofhiEdhTOzBEMlN2B_saVgBxFk_tEaEY',
    appId: '1:526754016534:android:1c1e0c10d9d4603ad43437',
    messagingSenderId: '526754016534',
    projectId: 'sympli-ai-health',
    storageBucket: 'sympli-ai-health.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD5210K-lzq1hyB1ryWsWtyhHeYul7ZwB8',
    appId: '1:526754016534:ios:1f60a78ce2c39abcd43437',
    messagingSenderId: '526754016534',
    projectId: 'sympli-ai-health',
    storageBucket: 'sympli-ai-health.firebasestorage.app',
    iosClientId: '526754016534-5t9cbnm8mgf6sqc3vst5ooh11gritnb8.apps.googleusercontent.com',
    iosBundleId: 'com.example.sympliAiHealth',
  );

}