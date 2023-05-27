import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lionsmarket/webview_controller.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

void launchURL() async {
  const url = "lionsmarket://kr.sogeum.lionsmarket";
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url));
  } else {
    throw "Could not launch $url";
  }
}

Future<void> _requestLocationPermission() async {
  await Permission.location.request();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Firebase 연동 시 필히 import
  await Firebase.initializeApp(); // Firebase State 초기화
  bool data = await fetchData();

  if (kDebugMode) {
    print(data);
  }

  await _requestLocationPermission();

  // Throw & Catch Exception
  runZonedGuarded(
    () async {},
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack);
    },
  );

  runApp(MyApp());

  await SystemChrome.setPreferredOrientations(
    [
      // 어플리케이션 화면 세로 고정
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light,
  );
}

class MyApp extends StatelessWidget {
  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '라이온스홍보몰',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3A8BFF),
        ),
        primaryColor: const Color(0xFF3A8BFF),
      ),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [FirebaseAnalyticsObserver(analytics: analytics)],
      home: const WebviewController(),
    );
  }
}

Future<bool> fetchData() async {
  bool data = false;

  await Future.delayed(
      const Duration(
        seconds: 1,
      ), () {
    data = true;
  });

  return data;
}
