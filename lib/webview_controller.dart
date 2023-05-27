import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_pro/webview_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:lionsmarket/msg_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class WebviewController extends StatefulWidget {
  const WebviewController({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _WebviewControllerState();
  }
}

class _WebviewControllerState extends State<WebviewController> {
  // Initialize URL
  final String url = "https://lionsmarket.co.kr/";
  bool isInMainPage = true;

  // Initialize Webview Controller
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();
  WebViewController? _viewController;

  final MsgController _msgController = Get.put(MsgController());

  // Initialize GPS
  Position? _position;

  @override
  void initState() {
    super.initState();

    if (Platform.isAndroid) WebView.platform = AndroidWebView();

    _requestPermission();
    _requestStoragePermission();
  }

  /*
  Future<void> _clearCache() async {
    if (_viewController != null) {
      await _viewController!.clearCache();
    }
  }
  */

  // 위치 권한 요청
  Future<void> _requestPermission() async {
    final status = await Geolocator.checkPermission();

    if (status == LocationPermission.denied) {
      await Geolocator.requestPermission();
    } else if (status == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("위치 권한 요청이 거부되었습니다.")));
      return;
    }

    await _updatePosition();
  }

  Future<void> _updatePosition() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _position = position;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("위치 정보를 받아오는 데 실패했습니다.")));
    }
  }

  void _requestStoragePermission() async {
    PermissionStatus status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      PermissionStatus result =
          await Permission.manageExternalStorage.request();
      if (!result.isGranted) {
        if (kDebugMode) {
          print('저장소 접근 권한이 승인되었습니다.');
        }
      } else {
        if (kDebugMode) {
          print('저장소 접근 권한이 거부되었습니다.');
        }
      }
    }
  }

  Future<String> _getCookies(WebViewController controller) async {
    final String cookies =
        await controller.runJavascriptReturningResult('document.cookie;');
    return cookies;
  }

  Future<void> _setCookies(WebViewController controller, String cookies) async {
    await controller
        .runJavascriptReturningResult('document.cookie="$cookies";');
  }

  Future<void> _saveCookies(String cookies) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('cookies', cookies);
  }

  Future<String?> _loadCookies() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('cookies');
  }

  JavascriptChannel _flutterWebviewProJavascriptChannel(BuildContext context) {
    return JavascriptChannel(
      name: 'flutter_webview_pro',
      onMessageReceived: (JavascriptMessage message) async {
        Map<String, dynamic> jsonData = jsonDecode(message.message);
        if (jsonData['handler'] == 'webviewJavaScriptHandler') {
          if (jsonData['action'] == 'setUserId') {
            String userId = jsonData['data']['userId'];
            GetStorage().write('userId', userId);

            if (kDebugMode) {
              print('@addJavaScriptHandler userId $userId');
            }

            String? token = await _getPushToken();
            _viewController?.runJavascript('tokenUpdate("$token")');
          }
        }
        setState(() {});
      },
    );
  }

  Future<String?> _getPushToken() async {
    return await _msgController.getToken();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        dragStartBehavior: DragStartBehavior.start,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          child: WillPopScope(
            onWillPop: () async {
              if (_viewController == null) {
                return false;
              }

              final currentUrl = await _viewController?.currentUrl();

              if (currentUrl == url) {
                if (!mounted) return false;
                return showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("앱을 종료하시겠습니까?"),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(true);
                            if (kDebugMode) {
                              print("앱이 포그라운드에서 종료되었습니다.");
                            }
                          },
                          child: const Text("확인"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(false);
                            if (kDebugMode) {
                              print("앱이 종료되지 않았습니다.");
                            }
                          },
                          child: const Text("취소"),
                        ),
                      ],
                    );
                  },
                ).then((value) => value ?? false);
              } else if (await _viewController!.canGoBack() &&
                  _viewController != null) {
                _viewController!.goBack();
                if (kDebugMode) {
                  print("이전 페이지로 이동하였습니다.");
                }
                isInMainPage = false;
                return false;
              }
              return false;
            },
            child: SafeArea(
              child: WebView(
                initialUrl: url,
                javascriptMode: JavascriptMode.unrestricted,
                // ignore: prefer_collection_literals
                javascriptChannels: <JavascriptChannel>[
                  _flutterWebviewProJavascriptChannel(context),
                ].toSet(),
                userAgent:
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36",
                onWebResourceError: (error) {
                  if (kDebugMode) {
                    print("Error Code: ${error.errorCode}");
                    print("Error Description: ${error.description}");
                  }
                },
                onWebViewCreated: (WebViewController webViewController) async {
                  _controller.complete(webViewController);
                  _viewController = webViewController;
                  //_clearCache(); // Invalidate Cache
                  webViewController.currentUrl().then((url) {
                    if (url == "https://lionsmarket.co.kr/") {
                      setState(() {
                        isInMainPage = true;
                      });
                    } else {
                      setState(() {
                        isInMainPage = false;
                      });
                    }
                  });
                },
                onPageStarted: (String url) async {
                  if (kDebugMode) {
                    print("Current Page: $url");
                  }
                },
                onPageFinished: (String url) async {
                  if (url.contains("https://lionsmarket.co.kr/") &&
                      _viewController != null) {
                    await _viewController!.runJavascript("""
                          (function() {
                            function scrollToFocusedInput(event) {
                              const focusedElement = document.activeElement;
                              if (focusedElement.tagName.toLowerCase() === 'input' || focusedElement.tagName.toLowerCase() === 'textarea') {
                                setTimeout(() => {
                                  focusedElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
                                }, 500);
                              }
                            }
                  
                            document.addEventListener('focus', scrollToFocusedInput, true);
                          })();
                        """);
                  }

                  if (url.contains("https://lionsmarket.co.kr/bbs/login.php") &&
                      _viewController != null) {
                    await _viewController!.runJavascript("""
                          async function loadScript() {
                              return new Promise((resolve, reject) => {
                                  const script = document.createElement('script');
                                  script.type = 'text/javascript';
                                  script.src = 'https://dapi.kakao.com/v2/maps/sdk.js?appkey=e3fa10c5c3f32ff65a8f50b5b7da847b&libraries=services';
                                  script.onload = () => resolve();
                                  script.onerror = () => reject(new Error('Failed to load the script'));
                                  document.head.appendChild(script);
                              });
                          }
                          
                          var map;
                          var geocoder = new kakao.maps.services.Geocoder();
                          
                          function getCurrentPosition() {
                              return new Promise((resolve, reject) => {
                                  navigator.geolocation.getCurrentPosition(resolve, reject);
                              });
                          }
                          
                          async function initMap() {
                              try {
                                  const position = await getCurrentPosition();
                                  var lat = position.coords.latitude;
                                  var lon = position.coords.longitude;
                                  var locPosition = new kakao.maps.LatLng(lat, lon);
                          
                                  var mapContainer = document.getElementById('map'),
                                      mapOption = {
                                          center: locPosition,
                                          level: 4
                                      };
                          
                                  map = new kakao.maps.Map(mapContainer, mapOption);
                              } catch (error) {
                                  console.error("Error in initMap:", error);
                              }
                          }
                          
                          function getDistrict(address) {
                              var district = "";
                              var splitAddr = address.split(' ');
                          
                              if (splitAddr.length > 1) {
                                  district = splitAddr[1];
                              }
                          
                              return district;
                          }
                          
                          async function storeLocation() {
                              try {
                                  const position = await getCurrentPosition();
                                  var lat = position.coords.latitude;
                                  var lon = position.coords.longitude;
                                  var locPosition = new kakao.maps.LatLng(lat, lon);
                          
                                  var marker = new kakao.maps.Marker({
                                      map: map,
                                      position: locPosition
                                  });
                          
                                  map.setCenter(locPosition);
                          
                                  geocoder.coord2Address(locPosition.getLng(), locPosition.getLat(), function (result, status) {
                                      if (status === kakao.maps.services.Status.OK) {
                                          var detailAddr = result[0].address.address_name;
                                          var district = getDistrict(detailAddr);
                                          setLocation(locPosition.getLat(), locPosition.getLng(), detailAddr, district);
                                      }
                                  });
                              } catch (error) {
                                  console.error("Error in storeLocation:", error);
                              }
                          }
                          
                          function setLocation(lat, lon, addr, district) {
                              document.getElementById('latitude').value = lat;
                              document.getElementById('longitude').value = lon;
                              document.getElementById('addr').value = addr;
                              document.getElementById('district').value = district;
                          }
                          
                          async function initApp() {
                              await initMap();
                              storeLocation();
                          }
                          
                          async function runApp() {
                              try {
                                  await loadScript();
                                  initApp();
                              } catch (error) {
                                  console.error("Error in runApp:", error);
                              }
                          }
                          
                          runApp();
                        """);

                    final cookies = await _getCookies(_viewController!);
                    await _saveCookies(cookies);
                  } else {
                    final cookies = await _loadCookies();
                    if (cookies != null) {
                      await _setCookies(_viewController!, cookies);
                    }
                  }
                },
                geolocationEnabled: true,
                zoomEnabled: false,
                gestureNavigationEnabled: true,
                // ignore: prefer_collection_literals
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>[
                  Factory<EagerGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                  ),
                ].toSet(),
                navigationDelegate: (NavigationRequest request) async {
                  if (request.url.startsWith("tel:")) {
                    if (await canLaunchUrl(Uri.parse(request.url))) {
                      await launchUrl(Uri.parse(request.url));
                    }
                    return NavigationDecision.prevent;
                  }
                  return NavigationDecision.navigate;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
