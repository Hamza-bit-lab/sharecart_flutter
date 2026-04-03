import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sharecart/controllers/language_controller.dart';
import 'package:sharecart/services/auth_service.dart';
import 'package:sharecart/services/push_notification_service.dart';
import 'package:sharecart/theme/app_theme.dart';
import 'package:sharecart/translations/translations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/app_initializer.dart';

bool _firebaseInitialized = false;

Future<void> _initFcm() async {
  if (!_firebaseInitialized) return;
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await initializeLocalNotificationsPlugin();
    await FirebaseMessaging.instance.getToken();
    await AuthService.instance.loadStoredToken();
    if (AuthService.instance.isLoggedIn) {
      await AuthService.instance.registerFcmTokenWithBackend();
    }
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    _firebaseInitialized = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initFcm();
  } catch (_) {}
  final prefs = await SharedPreferences.getInstance();
  Get.put(LanguageController(prefs: prefs));
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<RemoteMessage>? _messageOpenedSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  void initState() {
    super.initState();
    _linkSub = AppLinks().uriLinkStream.listen(_onDeepLink);
    if (_firebaseInitialized) {
      FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _messageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationOpened);
      _foregroundMessageSub = FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        if (AuthService.instance.isLoggedIn) {
          AuthService.instance.registerFcmTokenWithBackend();
        }
      });
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _messageOpenedSub?.cancel();
    _foregroundMessageSub?.cancel();
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  void _onNotificationOpened(RemoteMessage message) {}

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final n = message.notification;
    final data = message.data;
    String? title = n?.title;
    String? body = n?.body;
    title ??= data['title'] as String? ?? data['subject'] as String? ?? data['gcm_title'] as String?;
    body ??= data['body'] as String? ??
        data['message'] as String? ??
        data['content'] as String? ??
        data['alert'] as String?;

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await showLocalPushFromMessage(
      id: message.hashCode,
      title: (title != null && title.isNotEmpty) ? title : 'Share Cart',
      body: body ?? '',
    );
  }

  Future<void> _onDeepLink(Uri uri) async {
    if (uri.scheme != 'sharecart') return;
    if (uri.host != 'add' && !uri.pathSegments.contains('add')) return;
    final listName = uri.queryParameters['list']?.trim();
    final itemName = uri.queryParameters['item']?.trim();
    if (listName == null || listName.isEmpty || itemName == null || itemName.isEmpty) return;
    if (!AuthService.instance.isLoggedIn) return;
    try {
      final result = await AuthService.instance.fetchLists();
      final matches = result.active.where((l) => l.name.toLowerCase().trim() == listName.toLowerCase()).toList();
      if (matches.isNotEmpty) {
        await AuthService.instance.storeListItem(matches.first.id, itemName, quantity: 1);
        if (mounted) {
          _scaffoldKey.currentState?.showSnackBar(
            SnackBar(content: Text('Added "$itemName" to $listName')),
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = Get.find<LanguageController>();
    return GetMaterialApp(
      scaffoldMessengerKey: _scaffoldKey,
      title: 'appTitle'.tr,
      theme: AppTheme.light,
      translations: AppTranslations(),
      locale: lang.locale.value,
      fallbackLocale: const Locale('en'),
      builder: (context, child) {
        return Directionality(
          textDirection: lang.isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: child!,
        );
      },
      home: const AppInitializer(),
    );
  }
}
