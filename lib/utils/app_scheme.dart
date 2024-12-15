import 'dart:async';

import 'package:PiliPalaX/models/common/reply_type.dart';
import 'package:PiliPalaX/utils/extension.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import '../http/search.dart';
import '../pages/video/detail/reply_reply/view.dart';
import 'id_utils.dart';
import 'url_utils.dart';
import 'utils.dart';

class PiliScheme {
  static late AppLinks appLinks;
  static Future<void> init() async {
    // Register our protocol only on Windows platform
    // registerProtocolHandler('bilibili');
    appLinks = AppLinks();

    appLinks.uriLinkStream.listen((uri) {
      debugPrint('onAppLink: $uri');
      routePush(uri);
    });
  }

  /// 路由跳转
  static void routePush(Uri value) async {
    final String scheme = value.scheme;
    final String host = value.host;
    final String path = value.path;

    if (scheme == 'bilibili') {
      debugPrint('$value');
      if (host == 'root') {
        Navigator.popUntil(
            Get.context!, (Route<dynamic> route) => route.isFirst);
      } else if (host == 'space') {
        final String mid = path.split('/').last;
        Utils.toDupNamed(
          '/member?mid=$mid',
          arguments: <String, dynamic>{'face': null},
        );
      } else if (host == 'video') {
        String pathQuery = path.split('/').last;
        if (value.queryParameters['comment_root_id'] != null) {
          Get.to(
            () => Scaffold(
              resizeToAvoidBottomInset: false,
              appBar: AppBar(
                title: Text('评论详情'),
                actions: [
                  IconButton(
                    tooltip: '前往原视频',
                    onPressed: () {
                      String? enterUri = value.toString().split('?').first;
                      routePush(Uri.parse(enterUri));
                    },
                    icon: const Icon(Icons.open_in_new),
                  ),
                ],
              ),
              body: VideoReplyReplyPanel(
                oid: int.tryParse(pathQuery),
                rpid: int.tryParse(value.queryParameters['comment_root_id']!),
                source: 'routePush',
                replyType: ReplyType.video,
                firstFloor: null,
              ),
            ),
          );
          return;
        }
        final numericRegex = RegExp(r'^[0-9]+$');
        if (numericRegex.hasMatch(pathQuery)) {
          pathQuery = 'AV$pathQuery';
        }
        Map map = IdUtils.matchAvorBv(input: pathQuery);
        if (map.containsKey('AV')) {
          videoPush(map['AV'], null);
        } else if (map.containsKey('BV')) {
          videoPush(null, map['BV']);
        } else {
          SmartDialog.showToast('投稿匹配失败');
        }
      } else if (host == 'live') {
        final String roomId = path.split('/').last;
        Utils.toDupNamed('/liveRoom?roomid=$roomId',
            arguments: <String, String?>{'liveItem': null, 'heroTag': roomId});
      } else if (host == 'bangumi') {
        if (path.startsWith('/season')) {
          final String seasonId = path.split('/').last;
          bangumiPush(int.parse(seasonId), null);
        }
      } else if (host == 'opus') {
        if (path.startsWith('/detail')) {
          var opusId = path.split('/').last;
          Utils.toDupNamed(
            '/webviewnew',
            parameters: {
              'url': 'https://www.bilibili.com/opus/$opusId',
              'type': 'url',
              'pageTitle': '',
            },
          );
        }
      } else if (host == 'search') {
        Utils.toDupNamed('/searchResult', parameters: {'keyword': ''});
      } else if (host == 'article') {
        final String id = path.split('/').last.split('?').first;
        Utils.toDupNamed(
          '/htmlRender',
          parameters: {
            'url': 'www.bilibili.com/read/cv$id',
            'title': '',
            'id': 'cv$id',
            'dynamicType': 'read'
          },
        );
      } else if (host == 'comment' && path.startsWith("/detail/")) {
        //bilibili://comment/detail/17/832703053858603029/238686570016/?subType=0&anchor=238686628816&showEnter=1&extraIntentId=0&scene=1&enterName=%E6%9F%A5%E7%9C%8B%E5%8A%A8%E6%80%81%E8%AF%A6%E6%83%85&enterUri=bilibili://following/detail/832703053858603029
        //fmt.Sprintf("bilibili://comment/detail/%d/%d/%d/?subType=%d&anchor=%d&showEnter=1&extraIntentId=%d", rp.Type, rp.Oid, rootID, subType, rp.RpID, extraIntentID)
        debugPrint('${value.queryParameters}');
        List<String> pathParts = path.split('/');
        // int type = int.parse(pathParts[2]);
        int oid = int.parse(pathParts[3]);
        // int rootId = int.parse(pathParts[4]);
        // int subType = int.parse(value.queryParameters['subType'] ?? '0');
        int rpID = int.parse(value.queryParameters['anchor'] ?? '0');
        // int extraIntentId =
        // int.parse(value.queryParameters['extraIntentId'] ?? '0');
        Get.to(
          () => Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
              title: Text('评论详情'),
              actions: [
                IconButton(
                  tooltip: '前往',
                  onPressed: () {
                    String? enterUri = value.queryParameters['enterUri'];
                    if (enterUri != null) {
                      routePush(Uri.parse(enterUri));
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                ),
              ],
            ),
            body: VideoReplyReplyPanel(
                oid: oid,
                rpid: rpID,
                source: 'routePush',
                replyType: ReplyType.dynamics,
                firstFloor: null),
          ),
        );
      } else if (host == 'following' && path.startsWith("/detail/")) {
        void getToOpusWeb() {
          var opusId = path.split('/').last;
          Utils.toDupNamed(
            '/webviewnew',
            parameters: {
              'url': 'https://m.bilibili.com/dynamic/$opusId',
              'type': 'url',
              'pageTitle': '',
            },
          );
        }

        if (value.queryParameters['comment_root_id'] != null) {
          Get.to(
            () => Scaffold(
              resizeToAvoidBottomInset: false,
              appBar: AppBar(
                title: Text('评论详情'),
                actions: [
                  IconButton(
                    tooltip: '前往',
                    onPressed: () {
                      getToOpusWeb();
                    },
                    icon: const Icon(Icons.open_in_new),
                  ),
                ],
              ),
              body: VideoReplyReplyPanel(
                  oid: int.tryParse(path.split('/').last),
                  rpid: int.tryParse(value.queryParameters['comment_root_id']!),
                  source: 'routePush',
                  replyType: ReplyType.dynamics,
                  firstFloor: null),
            ),
          );
        } else {
          getToOpusWeb();
        }
      } else {
        debugPrint('$value');
        SmartDialog.showToast('未知路径:$value，请截图反馈给开发者');
        //Utils.toDupNamed(
        //   '/webviewnew',
        //   parameters: {
        //     'url': value.dataString ?? "",
        //     'type': 'url',
        //     'pageTitle': ''
        //   },
        // );
      }
    } else if (['http', 'https'].contains(scheme)) {
      fullPathPush(value);
    } else if (path.toLowerCase().startsWith('av')) {
      try {
        videoPush(int.parse(path.substring(2)), null);
      } catch (e) {
        debugPrint(e.toString());
      }
    } else if (path.toLowerCase().startsWith('bv')) {
      try {
        videoPush(null, path);
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  // 投稿跳转
  static Future<void> videoPush(int? aidVal, String? bvidVal) async {
    try {
      int? aid = aidVal;
      String? bvid = bvidVal;
      if (aidVal == null) {
        aid = IdUtils.bv2av(bvidVal!);
      }
      if (bvidVal == null) {
        bvid = IdUtils.av2bv(aidVal!);
      }
      SmartDialog.showLoading<dynamic>(msg: '获取中...');
      final int cid = await SearchHttp.ab2c(bvid: bvidVal, aid: aidVal);
      SmartDialog.dismiss();
      final String heroTag = Utils.makeHeroTag(aid);
      Utils.toDupNamed(
        '/video?bvid=$bvid&cid=$cid',
        arguments: <String, String?>{
          'pic': null,
          'heroTag': heroTag,
        },
      );
    } catch (e) {
      SmartDialog.dismiss();
      SmartDialog.showToast('video获取失败: $e');
    }
  }

  // 番剧跳转
  static Future<void> bangumiPush(int? seasonId, int? epId) async {
    debugPrint('seasonId: $seasonId, epId: $epId');
    // SmartDialog.showLoading<dynamic>(msg: '获取中...');
    try {
      Utils.viewBangumi(seasonId: seasonId, epId: epId);
      // var result = await SearchHttp.bangumiInfo(seasonId: seasonId, epId: epId);
      // if (result['status']) {
      //   var bangumiDetail = result['data'];
      //   EpisodeItem episode = result['data'].episodes.first;
      //   int? epId = result['data'].userStatus?.progress?.lastEpId;
      //   if (epId == null) {
      //     epId = episode.epId;
      //   } else {
      //     for (var item in result['data'].episodes) {
      //       if (item.epId == epId) {
      //         episode = item;
      //         break;
      //       }
      //     }
      //   }
      //   String bvid = episode.bvid!;
      //   int cid = episode.cid!;
      //   dynamic pic = episode.cover;
      //   final String heroTag = Utils.makeHeroTag(cid);
      //   SmartDialog.dismiss().then(
      //     (e) => Utils.toDupNamed(
      //       '/video?bvid=$bvid&cid=$cid&seasonId=${bangumiDetail.seasonId}&epId=$epId',
      //       arguments: <String, dynamic>{
      //         'pic': pic,
      //         'heroTag': heroTag,
      //         'videoType': SearchType.media_bangumi,
      //       },
      //     ),
      //   );
      // } else {
      //   SmartDialog.showToast(result['msg']);
      // }
    } catch (e) {
      SmartDialog.showToast('番剧获取失败：$e');
    }
  }

  static Future<void> fullPathPush(Uri value) async {
    // https://m.bilibili.com/bangumi/play/ss39708
    // https | m.bilibili.com | /bangumi/play/ss39708
    // final String scheme = value.scheme!;
    final String host = value.host;
    final String path = value.path;
    Map<String, String> query = value.queryParameters;
    RegExp regExp = RegExp(r'^((www\.)|(m\.))?bilibili\.com$');
    if (regExp.hasMatch(host)) {
      debugPrint('bilibili.com');
    } else if (host.contains('live')) {
      int roomId = int.parse(path.split('/').last);
      Utils.toDupNamed(
        '/liveRoom?roomid=$roomId',
        arguments: {'liveItem': null, 'heroTag': roomId.toString()},
      );
      return;
    } else if (host.contains('space')) {
      var mid = path.split('/').last;
      Utils.toDupNamed('/member?mid=$mid', arguments: {'face': ''});
      return;
    } else if (host == 'b23.tv') {
      final String fullPath = 'https://$host$path';
      final String redirectUrl = await UrlUtils.parseRedirectUrl(fullPath);
      final String pathSegment = Uri.parse(redirectUrl).path;
      final String lastPathSegment = pathSegment.split('/').last;
      final RegExp avRegex = RegExp(r'^[aA][vV]\d+', caseSensitive: false);
      if (avRegex.hasMatch(lastPathSegment)) {
        final Map<String, dynamic> map =
            IdUtils.matchAvorBv(input: lastPathSegment);
        if (map.containsKey('AV')) {
          videoPush(map['AV']! as int, null);
        } else if (map.containsKey('BV')) {
          videoPush(null, map['BV'] as String);
        } else {
          SmartDialog.showToast('投稿匹配失败');
        }
      } else if (lastPathSegment.startsWith('ep')) {
        handleEpisodePath(lastPathSegment, redirectUrl);
      } else if (lastPathSegment.startsWith('ss')) {
        handleSeasonPath(lastPathSegment, redirectUrl);
      } else if (lastPathSegment.startsWith('BV')) {
        UrlUtils.matchUrlPush(
          lastPathSegment,
          '',
          redirectUrl,
        );
      } else {
        Utils.toDupNamed(
          '/webviewnew',
          parameters: {'url': redirectUrl, 'type': 'url', 'pageTitle': ''},
        );
      }
      return;
    }

    List<String> pathPart = path.split('/');
    if (pathPart.length < 3) {
      Utils.toDupNamed(
        '/webviewnew',
        parameters: {'url': value.toString()},
      );
      return;
    }
    final String area = pathPart[1] == 'mobile' ? pathPart[2] : pathPart[1];
    switch (area) {
      case 'bangumi':
        debugPrint('番剧');
        for (var pathSegment in pathPart) {
          if (pathSegment.startsWith('ss')) {
            bangumiPush(matchNum(pathSegment).first, null);
            break;
          } else if (pathSegment.startsWith('ep')) {
            bangumiPush(null, matchNum(pathSegment).first);
            break;
          }
        }
        break;
      case 'video':
        debugPrint('投稿');
        final Map<String, dynamic> map = IdUtils.matchAvorBv(input: path);
        if (map.containsKey('AV')) {
          videoPush(map['AV']! as int, null);
        } else if (map.containsKey('BV')) {
          videoPush(null, map['BV'] as String);
        } else {
          SmartDialog.showToast('投稿匹配失败');
        }
        break;
      case 'read':
        debugPrint('专栏');
        late String id;
        if (query['id'] != null) {
          id = 'cv${matchNum(query['id']!).first}';
        } else {
          id = 'cv${matchNum(path).firstOrNull}';
        }
        Utils.toDupNamed('/htmlRender', parameters: {
          'url': value.toString(),
          'title': '',
          'id': id,
          'dynamicType': 'read'
        });
        break;
      case 'space':
        debugPrint('个人空间');
        Utils.toDupNamed(
            '/member?mid=${pathPart[1] == 'mobile' ? pathPart.getOrNull(3) : pathPart.getOrNull(2)}',
            arguments: {'face': ''});
        break;
      default:
        var res = IdUtils.matchAvorBv(input: area.split('?').first);
        if (res.containsKey('AV')) {
          videoPush(res['AV']! as int, null);
        } else if (res.containsKey('BV')) {
          videoPush(null, res['BV'] as String);
        } else {
          SmartDialog.showToast('未知路径或匹配错误:$value，先采用浏览器打开');
          Utils.toDupNamed(
            '/webviewnew',
            parameters: {
              'url': value.toString(),
              'type': 'url',
              'pageTitle': ''
            },
          );
        }
    }
  }

  static List<int> matchNum(String str) {
    final RegExp regExp = RegExp(r'\d+');
    final Iterable<Match> matches = regExp.allMatches(str);

    return matches.map((Match match) => int.parse(match.group(0)!)).toList();
  }

  static void handleEpisodePath(String lastPathSegment, String redirectUrl) {
    final String seasonId = extractIdFromPath(lastPathSegment);
    bangumiPush(null, matchNum(seasonId).first);
  }

  static void handleSeasonPath(String lastPathSegment, String redirectUrl) {
    final String seasonId = extractIdFromPath(lastPathSegment);
    bangumiPush(matchNum(seasonId).first, null);
  }

  static String extractIdFromPath(String lastPathSegment) {
    return lastPathSegment.split('/').last;
  }
}
