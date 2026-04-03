import 'package:firebase_messaging/firebase_messaging.dart';

Future<String?> getFcmToken() => FirebaseMessaging.instance.getToken();
