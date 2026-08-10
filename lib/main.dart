import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travla_customer_app/app/travla_app.dart';
import 'package:travla_customer_app/core/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lets the background tracking service talk back to the UI.
  FlutterForegroundTask.initCommunicationPort();

  // Push is non-critical — never block app start if Firebase can't initialise
  // (e.g. missing native config in a given build).
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error) {
    debugPrint('Firebase init skipped: $error');
  }

  runApp(const ProviderScope(child: TravlaApp()));
}
