import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' show Random;
import 'package:PiliPlus/build_config.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/material.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import '../utils/storage.dart';
import '../utils/utils.dart';
import 'api.dart';
import 'constants.dart';
import 'interceptor.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as web;

class Request {
  static final Request _instance = Request._internal();
  static late CookieManager cookieManager;
  static late final Dio dio;
  factory Request() => _instance;
  late bool enableSystemProxy;
  late String systemProxyHost;
  late String systemProxyPort;
  static final RegExp spmPrefixExp =
      RegExp(r'<meta name="spm_prefix" content="([^"]+?)">');

  /// 设置cookie
  static setCookie() async {
    final String cookiePath = await Utils.getCookiePath();
    final PersistCookieJar cookieJar = PersistCookieJar(
      ignoreExpires: true,
      storage: FileStorage(cookiePath),
    );
    cookieManager = CookieManager(cookieJar);
    dio.interceptors.add(cookieManager);
    dio.interceptors.add(ApiInterceptor());
    final List<Cookie> cookies = await cookieManager.cookieJar
        .loadForRequest(Uri.parse(HttpString.baseUrl));
    for (Cookie item in cookies) {
      await web.CookieManager().setCookie(
        url: web.WebUri(item.domain ?? ''),
        name: item.name,
        value: item.value,
        path: item.path ?? '',
        domain: item.domain,
        isSecure: item.secure,
        isHttpOnly: item.httpOnly,
      );
    }
    final userInfo = GStorage.userInfo.get('userInfoCache');
    if (userInfo != null && userInfo.mid != null) {
      final List<Cookie> cookie2 = await cookieManager.cookieJar
          .loadForRequest(Uri.parse(HttpString.tUrl));
      if (cookie2.isEmpty) {
        try {
          await Request().get(HttpString.tUrl);
        } catch (e) {
          log("setCookie, ${e.toString()}");
        }
      }
    }
    setOptionsHeaders(userInfo, userInfo != null && userInfo.mid != null);

    try {
      await buvidActivate();
    } catch (e) {
      log("setCookie, ${e.toString()}");
    }

    // final String cookieString = cookies
    //     .map((Cookie cookie) => '${cookie.name}=${cookie.value}')
    //     .join('; ');
    // dio.options.headers['cookie'] = cookieString;
  }

  // 从cookie中获取 csrf token
  static Future<String> getCsrf() async {
    List<Cookie> cookies = await cookieManager.cookieJar
        .loadForRequest(Uri.parse(HttpString.apiBaseUrl));
    String token = '';
    if (cookies.where((e) => e.name == 'bili_jct').isNotEmpty) {
      token = cookies.firstWhere((e) => e.name == 'bili_jct').value;
    }
    return token;
  }

  static setOptionsHeaders(userInfo, bool status) {
    if (status) {
      dio.options.headers['x-bili-mid'] = userInfo.mid.toString();
      dio.options.headers['x-bili-aurora-eid'] =
          IdUtils.genAuroraEid(userInfo.mid);
    }
    dio.options.headers['env'] = 'prod';
    dio.options.headers['app-key'] = 'android64';
    dio.options.headers['x-bili-aurora-zone'] = 'sh001';
    dio.options.headers['referer'] = 'https://www.bilibili.com/';
  }

  static Future buvidActivate() async {
    var html = await Request().get(Api.dynamicSpmPrefix);
    String spmPrefix = spmPrefixExp.firstMatch(html.data)!.group(1)!;
    Random rand = Random();
    String randPngEnd = base64.encode(
        List<int>.generate(32, (_) => rand.nextInt(256)) +
            List<int>.filled(4, 0) +
            [73, 69, 78, 68] +
            List<int>.generate(4, (_) => rand.nextInt(256)));

    String jsonData = json.encode({
      '3064': 1,
      '39c8': '$spmPrefix.fp.risk',
      '3c43': {
        'adca': 'Linux',
        'bfe9': randPngEnd.substring(randPngEnd.length - 50),
      },
    });

    await Request().post(Api.activateBuvidApi,
        data: {'payload': jsonData},
        options: Options(contentType: 'application/json'));
  }

  /*
   * config it and create
   */
  Request._internal() {
    //BaseOptions、Options、RequestOptions 都可以配置参数，优先级别依次递增，且可以根据优先级别覆盖参数
    BaseOptions options = BaseOptions(
      //请求基地址,可以包含子路径
      baseUrl: HttpString.apiBaseUrl,
      //连接服务器超时时间，单位是毫秒.
      connectTimeout: const Duration(milliseconds: 12000),
      //响应流上前后两次接受到数据的间隔，单位为毫秒。
      receiveTimeout: const Duration(milliseconds: 12000),
      //Http请求头.
      headers: {},
    );

    enableSystemProxy = GStorage.setting
        .get(SettingBoxKey.enableSystemProxy, defaultValue: false) as bool;
    systemProxyHost =
        GStorage.setting.get(SettingBoxKey.systemProxyHost, defaultValue: '');
    systemProxyPort =
        GStorage.setting.get(SettingBoxKey.systemProxyPort, defaultValue: '');

    dio = Dio(options);

    /// fix 第三方登录 302重定向 跟iOS代理问题冲突
    // ..httpClientAdapter = Http2Adapter(
    //   ConnectionManager(
    //     idleTimeout: const Duration(milliseconds: 10000),
    //     onClientCreate: (context, ClientSetting config) =>
    //         config.onBadCertificate = (_) => true,
    //   ),
    // );

    /// 设置代理
    if (enableSystemProxy) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final HttpClient client = HttpClient();
          // Config the client.
          client.findProxy = (Uri uri) {
            // return 'PROXY host:port';
            return 'PROXY $systemProxyHost:$systemProxyPort';
          };
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }

    // 日志拦截器 输出请求、响应内容
    if (BuildConfig.isDebug) {
      dio.interceptors.add(LogInterceptor(
        request: false,
        requestHeader: false,
        responseHeader: false,
      ));
    }

    dio.transformer = BackgroundTransformer();
    dio.options.validateStatus = (int? status) {
      return status! >= 200 && status < 300 ||
          HttpString.validateStatusCodes.contains(status);
    };
  }

  /*
   * get请求
   */
  Future<Response> get(url,
      {queryParameters, options, cancelToken, extra}) async {
    Response response;
    if (extra != null) {
      if (extra['ua'] != null) {
        options ??= Options();
        options.headers ??= <String, dynamic>{};
        options.headers!['user-agent'] = headerUa(type: extra['ua']);
      }
    }

    try {
      response = await dio.get(
        url,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      Response errResponse = Response(
        data: {
          'message': await ApiInterceptor.dioError(e)
        }, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: -1,
        requestOptions: RequestOptions(),
      );
      return errResponse;
    }
  }

  /*
   * post请求
   */
  Future<Response> post(url,
      {data, queryParameters, options, cancelToken, extra}) async {
    // debugPrint('post-data: $data');
    Response response;
    try {
      response = await dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      // debugPrint('post success: ${response.data}');
      return response;
    } on DioException catch (e) {
      Response errResponse = Response(
        data: {
          'message': await ApiInterceptor.dioError(e)
        }, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: -1,
        requestOptions: RequestOptions(),
      );
      return errResponse;
    }
  }

  /*
   * 下载文件
   */
  downloadFile(urlPath, savePath) async {
    Response response;
    try {
      response = await dio.download(urlPath, savePath,
          onReceiveProgress: (int count, int total) {
        //进度
        // debugPrint("$count $total");
      });
      debugPrint('downloadFile success: ${response.data}');

      return response.data;
    } on DioException catch (e) {
      debugPrint('downloadFile error: $e');
      return Future.error(ApiInterceptor.dioError(e));
    }
  }

  /*
   * 取消请求
   *
   * 同一个cancel token 可以用于多个请求，当一个cancel token取消时，所有使用该cancel token的请求都会被取消。
   * 所以参数可选
   */
  void cancelRequests(CancelToken token) {
    token.cancel("cancelled");
  }

  static String headerUa({type = 'mob'}) {
    String headerUa = '';
    if (type == 'mob') {
      if (Platform.isIOS) {
        headerUa =
            'Mozilla/5.0 (iPhone; CPU iPhone OS 14_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1 Mobile/15E148 Safari/604.1';
      } else {
        headerUa =
            'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Mobile Safari/537.36';
      }
    } else {
      headerUa =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.2 Safari/605.1.15';
    }
    return headerUa;
  }
}
