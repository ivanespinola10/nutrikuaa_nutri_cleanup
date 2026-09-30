import 'package:firebase_core/firebase_core.dart';

class TesterFirebaseOptions {
  static const apiKey = String.fromEnvironment('NUTRI_FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('NUTRI_FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment('NUTRI_FIREBASE_SENDER_ID');
  static const contact = String.fromEnvironment('NUTRI_PRIVACY_CONTACT');
  static const projectId = 'nutrikuaa-nutri';

  static bool get ready => apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      senderId.isNotEmpty &&
      contact.contains('@');

  static FirebaseOptions get web => const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        authDomain: 'nutrikuaa-nutri.firebaseapp.com',
      );
}
