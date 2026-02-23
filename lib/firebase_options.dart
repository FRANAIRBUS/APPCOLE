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
    apiKey: 'AIzaSyAHDHHMITdUxz1hm7EZDH2DSLgad3pWGsk',
    appId: '1:593927143784:web:0bcdae3e14e091797956dd',
    messagingSenderId: '593927143784',
    projectId: 'redfamcole-488212',
    authDomain: 'redfamcole-488212.firebaseapp.com',
    storageBucket: 'redfamcole-488212.firebasestorage.app',
    measurementId: 'G-50H9JNEV83',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCG2Yq6QBpOweBk5-e9qmYi4O48QRNHc8w',
    appId: '1:593927143784:android:c2e78f618527803a7956dd',
    messagingSenderId: '593927143784',
    projectId: 'redfamcole-488212',
    storageBucket: 'redfamcole-488212.firebasestorage.app',
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