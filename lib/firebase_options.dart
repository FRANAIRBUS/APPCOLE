import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform. Run flutterfire configure.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'replace-with-web-api-key',
    appId: '1:1234567890:web:replace',
    messagingSenderId: '1234567890',
    projectId: 'replace-project-id',
    authDomain: 'replace-project-id.firebaseapp.com',
    storageBucket: 'replace-project-id.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'replace-with-android-api-key',
    appId: '1:1234567890:android:replace',
    messagingSenderId: '1234567890',
    projectId: 'replace-project-id',
    storageBucket: 'replace-project-id.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'replace-with-ios-api-key',
    appId: '1:1234567890:ios:replace',
    messagingSenderId: '1234567890',
    projectId: 'replace-project-id',
    storageBucket: 'replace-project-id.appspot.com',
    iosClientId: 'replace-ios-client-id',
    iosBundleId: 'com.example.coleconecta',
  );
}
