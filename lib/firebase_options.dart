import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for ${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAXN9DhKr0TS6hZlL52ACHliXgCUTht1lA',
    appId: '1:901514457743:android:712da40c741c10f96236fa',
    messagingSenderId: '901514457743',
    projectId: 'camp-connect-4644c',
    storageBucket: 'camp-connect-4644c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCai8HpsRIdgx8SKob4j2zwomiRkV5rr_w',
    appId: '1:901514457743:ios:744e6ea03d5b81746236fa',
    messagingSenderId: '901514457743',
    projectId: 'camp-connect-4644c',
    storageBucket: 'camp-connect-4644c.firebasestorage.app',
    iosBundleId: 'com.campconnect.campConnect',
  );
}
