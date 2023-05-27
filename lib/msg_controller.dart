// Performing Firebase Messaging service CONTROLLER
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class MsgController extends GetxController {
  // Initialize : Service Entry point
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  @override
  void onInit() async {
    // Firebase 서버에 권한 요청
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    // Debugging Code
    if (kDebugMode) {
      print(settings.authorizationStatus);
    }
    getToken();
    onMessage();

    super.onInit();
  }

  // Android Push Alarm Setting: Channel only for performing messaging service
  final AndroidNotificationChannel channel = const AndroidNotificationChannel(
    'high_importance_channel', // id: AndroidManifest.xml (line 29) 참조
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.',
    // description
    importance: Importance.max,
  );

  final FlutterLocalNotificationsPlugin plugin =
  FlutterLocalNotificationsPlugin();

  // Firebase 서버에 등록된 유저의 고유 토큰값 Get
  Future<String?> getToken() async {
    String? token = await messaging.getToken();
    // Throw & Catch Exception
    try {
      if (kDebugMode) {
        print(token);
      }
      return token;
    } catch (e) {
      // Comment line
      throw Error();
    }
  }

  // Firebase Messaging Plugin setting
  Future<String?> onMessage() async {
    await plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings("@mipmap/ic_launcher"),

        /// IOS 초기화는 flutter_local_notifications 버전을 최신으로 유지할 경우 오류가 난다.
        /// 강제적으로 ^9.1.5 버전을 쓸 수밖에 없음...
        /// 심지어 DarwinInitializationSettings 역시 찾을 수 없다...
        iOS: IOSInitializationSettings(),
      ),
      onSelectNotification: (String? payload) async {},
    );

    // ★★★★★ onMessage Stream setting ★★★★★
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // 메시지가 전송 될때마다 listen() 내부에서 call-back 진행
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification!.android;
      AppleNotification? apple = message.notification!.apple;
      // android 일 때에만 flutterNotification 노출 조건 분기문
      if (notification != null && android != null) {
        plugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
            ),
          ),
        );
        // For Debugging Area
        if (kDebugMode) {
          print("Data Receive: ${message.data}");
        }

        // Check Notification whether is or not
        if (message.notification != null) {
          if (kDebugMode) {
            print(
                "Message also contained a notification: ${message.notification!.body}");
          }
        }
      } else if (notification != null && apple != null) {
        plugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          const NotificationDetails(
            iOS: IOSNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
              sound: "default",
            ),
          ),
          // [Data Transfer Debugging]
          // payload: message.data['argument']
        );
      }

      // For Debugging Area
      if (kDebugMode) {
        print("Data Receive: ${message.data}");
      }

      // Check Notification whether is or not
      if (message.notification != null) {
        if (kDebugMode) {
          print(
              "Message also contained a notification: ${message.notification!.body}");
        }
      }
    });
    return null;
  }
}
