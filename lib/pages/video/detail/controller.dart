import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:PiliPalaX/common/constants.dart';
import 'package:PiliPalaX/common/widgets/icon_button.dart';
import 'package:PiliPalaX/common/widgets/loading_widget.dart';
import 'package:PiliPalaX/common/widgets/pair.dart';
import 'package:PiliPalaX/common/widgets/segment_progress_bar.dart';
import 'package:PiliPalaX/http/danmaku.dart';
import 'package:PiliPalaX/http/init.dart';
import 'package:PiliPalaX/models/video/play/subtitle.dart';
import 'package:PiliPalaX/utils/extension.dart';
import 'package:canvas_danmaku/models/danmaku_content_item.dart';
import 'package:dio/dio.dart';
import 'package:floating/floating.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/http/constants.dart';
import 'package:PiliPalaX/http/video.dart';
import 'package:PiliPalaX/models/common/search_type.dart';
import 'package:PiliPalaX/models/video/play/quality.dart';
import 'package:PiliPalaX/models/video/play/url.dart';
import 'package:PiliPalaX/plugin/pl_player/index.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:PiliPalaX/utils/utils.dart';
import 'package:PiliPalaX/utils/video_utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../utils/id_utils.dart';
import 'widgets/header_control.dart';

enum SegmentType {
  sponsor,
  selfpromo,
  interaction,
  intro,
  outro,
  preview,
  music_offtopic,
  poi_highlight,
  filler,
  exclusive_access
}

extension SegmentTypeExt on SegmentType {
  /// from https://github.com/hanydd/BilibiliSponsorBlock/*/public/_locales/zh_CN/messages.json
  String get title => [
        '赞助广告', //sponsor
        '无偿/自我推广', //selfpromo
        '三连/订阅提醒', //interaction
        '过场/开场动画', //intro
        '鸣谢/结束画面', //outro
        '回顾/概要', //preview
        '音乐:非音乐部分', //music_offtopic
        '精彩时刻/重点', //poi_highlight
        '离题闲聊/玩笑', //filler
        '品牌合作', //exclusive_access
      ][index];

  String get shortTitle => [
        '赞助广告', //sponsor
        '推广', //selfpromo
        '订阅提醒', //interaction
        '开场', //intro
        '片尾', //outro
        '预览', //preview
        '非音乐', //music_offtopic
        '精彩时刻', //poi_highlight
        '闲聊', //filler
        '品牌合作', //exclusive_access
      ][index];

  String get description => [
        '付费推广、付费推荐和直接广告。不是自我推广或免费提及他们喜欢的商品/创作者/网站/产品。', //sponsor
        '类似于 “赞助广告” ，但无报酬或是自我推广。包括有关商品、捐赠的部分或合作者的信息。', //selfpromo
        '视频中间简短提醒观众来一键三连或关注。 如果片段较长，或是有具体内容，则应分类为自我推广。', //interaction
        '没有实际内容的间隔片段。可以是暂停、静态帧或重复动画。不适用于包含内容的过场。', //intro
        '致谢画面或片尾画面。不包含内容的结尾。', //outro
        '展示此视频或同系列视频将出现的画面集锦，片段中所有内容都将在之后的正片中再次出现。', //preview
        '仅用于音乐视频。此分类只能用于音乐视频中未包括于其他分类的部分。', //music_offtopic
        '大部分人都在寻找的空降时间。类似于“封面在12:34”的评论。', //poi_highlight
        "仅作为填充内容或增添趣味而添加的离题片段，这些内容对理解视频的主要内容并非必需。这不包括提供背景信息或上下文的片段。这是一个非常激进的分类，适用于当你不想看'娱乐性'内容的时候。", //filler
        '仅用于对整个视频进行标记。适用于展示UP主免费或获得补贴后使用的产品、服务或场地的视频。', //exclusive_access
      ][index];

  Color get color => [
        Color(0xFF00d400), //sponsor
        Color(0xFFffff00), //selfpromo
        Color(0xFFcc00ff), //interaction
        Color(0xFF00ffff), //intro
        Color(0xFF0202ed), //outro
        Color(0xFF008fd6), //preview
        Color(0xFFff9900), //music_offtopic
        Color(0xFFff1684), //poi_highlight
        Color(0xFF7300FF), //filler
        Color(0xFF008a5c), //exclusive_access
      ][index];
}

enum SkipType { alwaysSkip, skipOnce, showOnly, disable }

extension SkipTypeExt on SkipType {
  String get title => ['总是跳过', '跳过一次', '仅显示', '禁用'][index];
}

class SegmentModel {
  SegmentModel({
    // ignore: non_constant_identifier_names
    required this.UUID,
    required this.segmentType,
    required this.segment,
    required this.skipType,
    required this.hasSkipped,
  });
  // ignore: non_constant_identifier_names
  String UUID;
  SegmentType segmentType;
  Pair<int, int> segment;
  SkipType skipType;
  bool hasSkipped;
}

class PostSegmentModel {
  PostSegmentModel({
    required this.segment,
    required this.category,
    required this.actionType,
  });
  Pair<int, int> segment;
  SegmentType category;
  ActionType actionType;
}

enum ActionType { skip, mute, full, poi }

extension ActionTypeExt on ActionType {
  String get title => ['跳过', '静音', '整个视频', '精彩时刻'][index];
}

class VideoDetailController extends GetxController
    with GetSingleTickerProviderStateMixin {
  /// 路由传参
  String bvid = Get.parameters['bvid']!;
  RxInt cid = int.parse(Get.parameters['cid']!).obs;
  RxInt danmakuCid = 0.obs;
  String heroTag = Get.arguments['heroTag'];
  // 视频详情
  RxMap videoItem = {}.obs;
  // 视频类型 默认投稿视频
  SearchType videoType = Get.arguments['videoType'] ?? SearchType.video;

  /// tabs相关配置
  int tabInitialIndex = 0;
  late TabController tabCtr;
  RxList<String> tabs = <String>['简介', '评论'].obs;

  // 请求返回的视频信息
  late PlayUrlModel data;
  // 请求状态
  RxBool isLoading = false.obs;

  /// 播放器配置 画质 音质 解码格式
  late VideoQuality currentVideoQa;
  AudioQuality? currentAudioQa;
  late VideoDecodeFormats currentDecodeFormats;
  // 是否开始自动播放 存在多p的情况下，第二p需要为true
  RxBool autoPlay = true.obs;
  // 视频资源是否有效
  RxBool isEffective = true.obs;
  // 封面图的展示
  RxBool isShowCover = true.obs;
  // 硬解
  RxBool enableHA = true.obs;
  RxString hwdec = 'auto-safe'.obs;

  /// 本地存储
  Box userInfoCache = GStorage.userInfo;
  Box localCache = GStorage.localCache;
  Box setting = GStorage.setting;

  RxInt oid = 0.obs;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final childKey = GlobalKey<ScaffoldState>();

  RxString bgCover = ''.obs;
  PlPlayerController plPlayerController = PlPlayerController.getInstance()
    ..setCurrBrightness(-1.0);

  late VideoItem firstVideo;
  late AudioItem firstAudio;
  String? videoUrl;
  String? audioUrl;
  late Duration defaultST;
  // 亮度
  double? brightness;
  // 默认记录历史记录
  bool enableHeart = true;
  dynamic userInfo;
  late bool isFirstTime = true;
  Floating? floating;
  late PreferredSizeWidget headerControl;

  // late bool enableCDN;
  late int? cacheVideoQa;
  late String cacheDecode;
  late String cacheSecondDecode;
  late int cacheAudioQa;

  late final bool enableSponsorBlock;
  PlayerStatus? playerStatus;
  StreamSubscription<Duration>? positionSubscription;

  PersistentBottomSheetController? bsController;

  bool imageStatus = false;

  void onViewImage() {
    imageStatus = true;
  }

  void onDismissed(value) {
    imageStatus = false;
  }

  @override
  void onInit() {
    super.onInit();
    final Map argMap = Get.arguments;
    userInfo = userInfoCache.get('userInfoCache');
    var keys = argMap.keys.toList();
    if (keys.isNotEmpty) {
      if (keys.contains('videoItem')) {
        var args = argMap['videoItem'];
        if (args.pic != null && args.pic != '') {
          videoItem['pic'] = args.pic;
        }
      }
      if (keys.contains('pic')) {
        videoItem['pic'] = argMap['pic'];
      }
    }
    bool defaultShowComment =
        setting.get(SettingBoxKey.defaultShowComment, defaultValue: false);
    tabCtr = TabController(
        length: 2, vsync: this, initialIndex: defaultShowComment ? 1 : 0);
    autoPlay.value =
        setting.get(SettingBoxKey.autoPlayEnable, defaultValue: false);
    if (autoPlay.value) isShowCover.value = false;
    enableHA.value = setting.get(SettingBoxKey.enableHA, defaultValue: true);
    hwdec.value = setting.get(SettingBoxKey.hardwareDecoding,
        defaultValue: Platform.isAndroid ? 'auto-safe' : 'auto');
    if (userInfo == null ||
        localCache.get(LocalCacheKey.historyPause) == true) {
      enableHeart = false;
    }
    danmakuCid.value = cid.value;

    ///
    if (Platform.isAndroid) {
      floating = Floating();
    }
    headerControl = HeaderControl(
      controller: plPlayerController,
      videoDetailCtr: this,
      floating: floating,
      heroTag: heroTag,
    );
    // CDN优化
    // enableCDN = setting.get(SettingBoxKey.enableCDN, defaultValue: true);

    // 预设的画质
    cacheVideoQa = setting.get(SettingBoxKey.defaultVideoQa,
        defaultValue: VideoQuality.values.last.code);
    // 预设的解码格式
    cacheDecode = setting.get(SettingBoxKey.defaultDecode,
        defaultValue: VideoDecodeFormats.values.last.code);
    cacheSecondDecode = setting.get(SettingBoxKey.secondDecode,
        defaultValue: VideoDecodeFormats.values[1].code);
    cacheAudioQa = setting.get(SettingBoxKey.defaultAudioQa,
        defaultValue: AudioQuality.hiRes.code);
    oid.value = IdUtils.bv2av(Get.parameters['bvid']!);
    enableSponsorBlock =
        setting.get(SettingBoxKey.enableSponsorBlock, defaultValue: false);
    if (enableSponsorBlock) {
      _blockLimit = GStorage.blockLimit;
      _blockSettings = GStorage.blockSettings;
      _blockColor = GStorage.blockColor;
    }
  }

  int? _lastPos;
  double? _blockLimit;
  List<Pair<SegmentType, SkipType>>? _blockSettings;
  List<Color>? _blockColor;
  RxList<SegmentModel> segmentList = <SegmentModel>[].obs;
  List<Segment> viewPointList = <Segment>[];
  List<Segment>? _segmentProgressList;
  Color _getColor(SegmentType segment) =>
      _blockColor?[segment.index] ?? segment.color;

  Future _vote(String uuid, int type) async {
    Request()
        .post(
      '${GStorage.blockServer}/api/voteOnSponsorTime',
      queryParameters: {
        'UUID': uuid,
        'userID': GStorage.blockUserID,
        'type': type,
      },
      options: _options,
    )
        .then((res) {
      SmartDialog.showToast(res.statusCode == 200 ? '投票成功' : '投票失败');
    });
  }

  void _showCategoryDialog(BuildContext context, SegmentModel segment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SegmentType.values
                .map((item) => ListTile(
                      dense: true,
                      onTap: () {
                        Get.back();
                        Request()
                            .post(
                          '${GStorage.blockServer}/api/voteOnSponsorTime',
                          queryParameters: {
                            'UUID': segment.UUID,
                            'userID': GStorage.blockUserID,
                            'category': item.name,
                          },
                          options: _options,
                        )
                            .then((res) {
                          SmartDialog.showToast(
                              '类别更改${res.statusCode == 200 ? '成功' : '失败'}');
                        });
                      },
                      title: Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Container(
                                height:
                                    MediaQuery.textScalerOf(context).scale(14),
                                width: 10,
                                alignment: Alignment.center,
                                child: Container(
                                  height: 10,
                                  width: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getColor(item),
                                  ),
                                ),
                              ),
                              style: TextStyle(fontSize: 14),
                            ),
                            TextSpan(
                              text: ' ${item.title}',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showVoteDialog(BuildContext context, SegmentModel segment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                title: Text(
                  '赞成票',
                  style: TextStyle(fontSize: 14),
                ),
                onTap: () {
                  Get.back();
                  _vote(segment.UUID, 1);
                },
              ),
              ListTile(
                dense: true,
                title: Text(
                  '反对票',
                  style: TextStyle(fontSize: 14),
                ),
                onTap: () {
                  Get.back();
                  _vote(segment.UUID, 0);
                },
              ),
              ListTile(
                dense: true,
                title: Text(
                  '更改类别',
                  style: TextStyle(fontSize: 14),
                ),
                onTap: () {
                  Get.back();
                  _showCategoryDialog(context, segment);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showSBDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: segmentList
                .map(
                  (item) => ListTile(
                    onTap: () {
                      Get.back();
                      _showVoteDialog(context, item);
                    },
                    dense: true,
                    title: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              height:
                                  MediaQuery.textScalerOf(context).scale(14),
                              width: 10,
                              alignment: Alignment.center,
                              child: Container(
                                height: 10,
                                width: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getColor(item.segmentType),
                                ),
                              ),
                            ),
                            style: TextStyle(fontSize: 14),
                          ),
                          TextSpan(
                            text: ' ${item.segmentType.title}',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    contentPadding: EdgeInsets.only(left: 16, right: 8),
                    subtitle: Text(
                      '${Utils.formatDuration(item.segment.first)} 至 ${Utils.formatDuration(item.segment.second)}',
                      style: TextStyle(fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.skipType.title,
                          style: TextStyle(fontSize: 13),
                        ),
                        if (item.skipType == SkipType.showOnly &&
                            item.segment.second != 0)
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              tooltip: '跳转至此片段',
                              onPressed: () async {
                                Get.back();
                                try {
                                  plPlayerController.danmakuController?.clear();
                                  await plPlayerController.videoPlayerController
                                      ?.seek(Duration(
                                          seconds: item.segment.first));
                                  if (GStorage.blockToast) {
                                    _showBlockToast(
                                        '已跳至${item.segmentType.shortTitle}');
                                  }
                                } catch (e) {
                                  _showBlockToast('跳转失败: $e');
                                }
                              },
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(
                                Icons.my_location,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 10),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showBlockToast(String msg) {
    SmartDialog.showToast(
      msg,
      alignment:
          plPlayerController.isFullScreen.value ? Alignment(-0.9, 0.5) : null,
    );
  }

  Options get _options => Options(
        headers: {
          'env': '',
          'app-key': '',
          'x-bili-mid': '',
          'x-bili-aurora-eid': '',
          'x-bili-aurora-zone': '',
          HttpHeaders.cookieHeader:
              'buvid3= ; SESSDATA= ; bili_jct= ; DedeUserID= ; DedeUserID__ckMd5= ; sid= ',
        },
      );

  Future _querySponsorBlock() async {
    dynamic result = await Request().get(
      '${GStorage.blockServer}/api/skipSegments',
      queryParameters: {
        'videoID': bvid,
        'cid': cid.value,
      },
      options: _options,
    );
    segmentList.clear();
    _segmentProgressList = null;
    _handleSBData(result);
  }

  void _handleSBData(result) {
    if (result.data is List && result.data.isNotEmpty) {
      try {
        List<String> list =
            SegmentType.values.map((item) => item.name).toList();
        List<String> enableList = _blockSettings!
            .where((item) => item.second != SkipType.disable)
            .toList()
            .map((item) => item.first.name)
            .toList();

        // segmentList
        segmentList.addAll((result.data as List)
            .where((item) =>
                enableList.contains(item['category']) &&
                item['segment'][1] >= item['segment'][0])
            .map(
          (item) {
            SegmentType segmentType =
                SegmentType.values[list.indexOf(item['category'])];
            SkipType skipType = _blockSettings![segmentType.index].second;
            if (skipType != SkipType.showOnly) {
              if (item['segment'][1] == item['segment'][0] ||
                  item['segment'][1] - item['segment'][0] < _blockLimit) {
                skipType = SkipType.showOnly;
              }
            }
            return SegmentModel(
              UUID: item['UUID'],
              segmentType: segmentType,
              segment: Pair(
                first: _convert(item['segment'][0]),
                second: _convert(item['segment'][1]),
              ),
              skipType: skipType,
              hasSkipped: false,
            );
          },
        ).toList());

        // _segmentProgressList
        _segmentProgressList ??= <Segment>[];
        _segmentProgressList!.addAll(segmentList.map((item) {
          double start = (item.segment.first / ((data.timeLength ?? 0) / 1000))
              .clamp(0.0, 1.0);
          double end = (item.segment.second / ((data.timeLength ?? 0) / 1000))
              .clamp(0.0, 1.0);
          return Segment(start, end, _getColor(item.segmentType));
        }).toList());
      } catch (e) {
        debugPrint('failed to parse sponsorblock: $e');
      }
    }
  }

  int _convert(value) {
    return value is double
        ? value.round()
        : value is int
            ? value
            : -1;
  }

  void _initSkip() {
    if (segmentList.isNotEmpty) {
      positionSubscription = plPlayerController
          .videoPlayerController?.stream.position
          .listen((position) async {
        int currentPos = position.inSeconds;
        if (currentPos != _lastPos) {
          _lastPos = currentPos;
          for (SegmentModel item in segmentList) {
            // debugPrint(
            //     '${position.inSeconds},,${item.segment.first},,${item.segment.second},,${item.skipType.name},,${item.hasSkipped}');
            if (item.segment.first == position.inSeconds) {
              if (item.skipType == SkipType.alwaysSkip ||
                  (item.skipType == SkipType.skipOnce && !item.hasSkipped)) {
                try {
                  plPlayerController.danmakuController?.clear();
                  await plPlayerController.videoPlayerController
                      ?.seek(Duration(seconds: item.segment.second));
                  item.hasSkipped = true;
                  if (GStorage.blockToast) {
                    _showBlockToast('已跳过${item.segmentType.shortTitle}片段');
                  }
                  if (GStorage.blockTrack) {
                    Request().post(
                      '${GStorage.blockServer}/api/viewedVideoSponsorTime',
                      queryParameters: {'UUID': item.UUID},
                      options: _options,
                    );
                  }
                } catch (e) {
                  debugPrint('failed to skip: $e');
                  _showBlockToast('${item.segmentType.shortTitle}片段跳过失败');
                }
              }
              break;
            }
          }
        }
      });
    }
  }

  /// 发送弹幕
  void showShootDanmakuSheet() {
    final TextEditingController textController = TextEditingController();
    bool isSending = false; // 追踪是否正在发送
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        // TODO: 支持更多类型和颜色的弹幕
        return AlertDialog(
          title: const Text('发送弹幕'),
          content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
            return TextField(
              controller: textController,
              autofocus: true,
            );
          }),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                '取消',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return TextButton(
                onPressed: isSending
                    ? null
                    : () async {
                        final String msg = textController.text;
                        if (msg.isEmpty) {
                          SmartDialog.showToast('弹幕内容不能为空');
                          return;
                        } else if (msg.length > 100) {
                          SmartDialog.showToast('弹幕内容不能超过100个字符');
                          return;
                        }
                        isSending = true; // 开始发送，更新状态
                        //修改按钮文字
                        // SmartDialog.showToast('弹幕发送中,\n$msg');
                        final dynamic res = await DanmakaHttp.shootDanmaku(
                          oid: cid.value,
                          msg: textController.text,
                          bvid: bvid,
                          progress:
                              plPlayerController.position.value.inMilliseconds,
                          type: 1,
                        );
                        isSending = false; // 发送结束，更新状态
                        if (res['status']) {
                          SmartDialog.showToast('发送成功');
                          // 发送成功，自动预览该弹幕，避免重新请求
                          // TODO: 暂停状态下预览弹幕仍会移动与计时，可考虑添加到dmSegList或其他方式实现
                          plPlayerController.danmakuController
                              ?.addDanmaku(DanmakuContentItem(
                            msg,
                            color: Colors.white,
                            type: DanmakuItemType.scroll,
                            selfSend: true,
                          ));
                          Get.back();
                        } else {
                          SmartDialog.showToast('发送失败，错误信息为${res['msg']}');
                        }
                      },
                child: Text(isSending ? '发送中...' : '发送'),
              );
            })
          ],
        );
      },
    );
  }

  /// 更新画质、音质
  /// TODO 继续进度播放
  updatePlayer() {
    isShowCover.value = false;
    defaultST = plPlayerController.position.value;
    plPlayerController.removeListeners();
    plPlayerController.isBuffering.value = false;
    plPlayerController.buffered.value = Duration.zero;

    /// 根据currentVideoQa和currentDecodeFormats 重新设置videoUrl
    List<VideoItem> videoList =
        data.dash!.video!.where((i) => i.id == currentVideoQa.code).toList();

    final List supportDecodeFormats = videoList.map((e) => e.codecs!).toList();
    VideoDecodeFormats defaultDecodeFormats =
        VideoDecodeFormatsCode.fromString(cacheDecode)!;
    VideoDecodeFormats secondDecodeFormats =
        VideoDecodeFormatsCode.fromString(cacheSecondDecode)!;
    try {
      // 当前视频没有对应格式返回第一个
      int flag = 0;
      for (var i in supportDecodeFormats) {
        if (i.startsWith(currentDecodeFormats.code)) {
          flag = 1;
          break;
        } else if (i.startsWith(defaultDecodeFormats.code)) {
          flag = 2;
        } else if (i.startsWith(secondDecodeFormats.code)) {
          if (flag == 0) {
            flag = 4;
          }
        }
      }
      if (flag == 1) {
        //currentDecodeFormats
        firstVideo = videoList.firstWhere(
            (i) => i.codecs!.startsWith(currentDecodeFormats.code),
            orElse: () => videoList.first);
      } else {
        if (currentVideoQa == VideoQuality.dolbyVision) {
          currentDecodeFormats =
              VideoDecodeFormatsCode.fromString(videoList.first.codecs!)!;
          firstVideo = videoList.first;
        } else if (flag == 2) {
          //defaultDecodeFormats
          currentDecodeFormats = defaultDecodeFormats;
          firstVideo = videoList.firstWhere(
            (i) => i.codecs!.startsWith(defaultDecodeFormats.code),
            orElse: () => videoList.first,
          );
        } else if (flag == 4) {
          //secondDecodeFormats
          currentDecodeFormats = secondDecodeFormats;
          firstVideo = videoList.firstWhere(
            (i) => i.codecs!.startsWith(secondDecodeFormats.code),
            orElse: () => videoList.first,
          );
        } else if (flag == 0) {
          currentDecodeFormats =
              VideoDecodeFormatsCode.fromString(supportDecodeFormats.first)!;
          firstVideo = videoList.first;
        }
      }
    } catch (err) {
      SmartDialog.showToast('DecodeFormats error: $err');
    }

    videoUrl = firstVideo.baseUrl!;

    /// 根据currentAudioQa 重新设置audioUrl
    if (currentAudioQa != null) {
      final AudioItem firstAudio = data.dash!.audio!.firstWhere(
        (AudioItem i) => i.id == currentAudioQa!.code,
        orElse: () => data.dash!.audio!.first,
      );
      audioUrl = firstAudio.baseUrl ?? '';
    }

    playerInit();
  }

  Future playerInit({
    video,
    audio,
    seekToTime,
    duration,
    bool? autoplay,
  }) async {
    await plPlayerController.setDataSource(
      DataSource(
        videoSource: video ?? videoUrl,
        audioSource: audio ?? audioUrl,
        type: DataSourceType.network,
        httpHeaders: {
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36',
          'referer': HttpString.baseUrl
        },
      ),
      segmentList: _segmentProgressList,
      viewPointList: viewPointList,
      vttSubtitles: _vttSubtitles,
      vttSubtitlesIndex: vttSubtitlesIndex,
      showVP: showVP,
      // 硬解
      enableHA: enableHA.value,
      hwdec: hwdec.value,
      seekTo: seekToTime ?? defaultST,
      duration: duration ?? data.timeLength == null
          ? null
          : Duration(milliseconds: data.timeLength!),
      // 宽>高 水平 否则 垂直
      direction: firstVideo.width != null && firstVideo.height != null
          ? ((firstVideo.width! - firstVideo.height!) > 0
              ? 'horizontal'
              : 'vertical')
          : null,
      bvid: bvid,
      cid: cid.value,
      enableHeart: enableHeart,
      autoplay: autoplay ?? autoPlay.value,
    );

    _initSkip();

    if (vttSubtitlesIndex == null) {
      _getSubtitle();
    }

    /// 开启自动全屏时，在player初始化完成后立即传入headerControl
    plPlayerController.headerControl = headerControl;
  }

  // 视频链接
  Future queryVideoUrl() async {
    var result = await VideoHttp.videoUrl(cid: cid.value, bvid: bvid);
    if (result['status']) {
      data = result['data'];
      if (enableSponsorBlock) {
        await _querySponsorBlock();
      }
      if (data.acceptDesc!.isNotEmpty && data.acceptDesc!.contains('试看')) {
        SmartDialog.showToast(
          '该视频为专属视频，仅提供试看',
          displayTime: const Duration(seconds: 3),
        );
      }
      if (data.dash == null && data.durl != null) {
        videoUrl = data.durl!.first.url!;
        audioUrl = '';
        defaultST = Duration.zero;
        // 实际为FLV/MP4格式，但已被淘汰，这里仅做兜底处理
        firstVideo = VideoItem(
            id: data.quality!,
            baseUrl: videoUrl,
            codecs: 'avc1',
            quality: VideoQualityCode.fromCode(data.quality!)!);
        currentDecodeFormats = VideoDecodeFormatsCode.fromString('avc1')!;
        currentVideoQa = VideoQualityCode.fromCode(data.quality!)!;
        if (autoPlay.value) {
          isShowCover.value = false;
          await playerInit();
        }
        return result;
      }
      if (data.dash == null) {
        SmartDialog.showToast('视频资源不存在');
        isShowCover.value = false;
        return result;
      }
      final List<VideoItem> allVideosList = data.dash!.video!;
      // debugPrint("allVideosList:${allVideosList}");
      // 当前可播放的最高质量视频
      int currentHighVideoQa = allVideosList.first.quality!.code;
      // 预设的画质为null，则当前可用的最高质量
      cacheVideoQa ??= currentHighVideoQa;
      int resVideoQa = currentHighVideoQa;
      if (cacheVideoQa! <= currentHighVideoQa) {
        // 如果预设的画质低于当前最高
        final List<int> numbers =
            data.acceptQuality!.where((e) => e <= currentHighVideoQa).toList();
        resVideoQa = Utils.findClosestNumber(cacheVideoQa!, numbers);
      }
      currentVideoQa = VideoQualityCode.fromCode(resVideoQa)!;

      /// 取出符合当前画质的videoList
      final List<VideoItem> videosList =
          allVideosList.where((e) => e.quality!.code == resVideoQa).toList();

      /// 优先顺序 设置中指定解码格式 -> 当前可选的首个解码格式
      final List<FormatItem> supportFormats = data.supportFormats!;
      // 根据画质选编码格式
      final List supportDecodeFormats = supportFormats
          .firstWhere((e) => e.quality == resVideoQa,
              orElse: () => supportFormats.first)
          .codecs!;
      // 默认从设置中取AV1
      currentDecodeFormats = VideoDecodeFormatsCode.fromString(cacheDecode)!;
      VideoDecodeFormats secondDecodeFormats =
          VideoDecodeFormatsCode.fromString(cacheSecondDecode)!;
      // 当前视频没有对应格式返回第一个
      int flag = 0;
      for (var i in supportDecodeFormats) {
        if (i.startsWith(currentDecodeFormats.code)) {
          flag = 1;
          break;
        } else if (i.startsWith(secondDecodeFormats.code)) {
          flag = 2;
        }
      }
      if (flag == 2) {
        currentDecodeFormats = secondDecodeFormats;
      } else if (flag == 0) {
        currentDecodeFormats =
            VideoDecodeFormatsCode.fromString(supportDecodeFormats.first)!;
      }

      /// 取出符合当前解码格式的videoItem
      firstVideo = videosList.firstWhere(
          (e) => e.codecs!.startsWith(currentDecodeFormats.code),
          orElse: () => videosList.first);

      // videoUrl = enableCDN
      //     ? VideoUtils.getCdnUrl(firstVideo)
      //     : (firstVideo.backupUrl ?? firstVideo.baseUrl!);
      videoUrl = VideoUtils.getCdnUrl(firstVideo);

      /// 优先顺序 设置中指定质量 -> 当前可选的最高质量
      late AudioItem? firstAudio;
      final List<AudioItem> audiosList = data.dash!.audio ?? <AudioItem>[];
      if (data.dash!.dolby?.audio != null &&
          data.dash!.dolby!.audio!.isNotEmpty) {
        // 杜比
        audiosList.insert(0, data.dash!.dolby!.audio!.first);
      }

      if (data.dash!.flac?.audio != null) {
        // 无损
        audiosList.insert(0, data.dash!.flac!.audio!);
      }

      if (audiosList.isNotEmpty) {
        final List<int> numbers = audiosList.map((map) => map.id!).toList();
        int closestNumber = Utils.findClosestNumber(cacheAudioQa, numbers);
        if (!numbers.contains(cacheAudioQa) &&
            numbers.any((e) => e > cacheAudioQa)) {
          closestNumber = 30280;
        }
        firstAudio = audiosList.firstWhere((e) => e.id == closestNumber,
            orElse: () => audiosList.first);
        // audioUrl = enableCDN
        //     ? VideoUtils.getCdnUrl(firstAudio)
        //     : (firstAudio.backupUrl ?? firstAudio.baseUrl!);
        audioUrl = VideoUtils.getCdnUrl(firstAudio);
        if (firstAudio.id != null) {
          currentAudioQa = AudioQualityCode.fromCode(firstAudio.id!)!;
        }
      } else {
        firstAudio = AudioItem();
        audioUrl = '';
      }
      //
      defaultST = Duration(milliseconds: data.lastPlayTime!);
      if (autoPlay.value) {
        isShowCover.value = false;
        await playerInit();
      }
    } else {
      if (result['code'] == -404) {
        isShowCover.value = false;
        SmartDialog.showToast('视频不存在或已被删除');
      }
      if (result['code'] == 87008) {
        SmartDialog.showToast("当前视频可能是专属视频，可能需包月充电观看(${result['msg']})");
      } else {
        SmartDialog.showToast("错误（${result['code']}）：${result['msg']}");
      }
    }
    return result;
  }

  List<PostSegmentModel>? list;

  void onBlock(BuildContext context) {
    list ??= <PostSegmentModel>[];
    if (list!.isEmpty) {
      list!.add(
        PostSegmentModel(
          segment: Pair(
            first: 0,
            second: plPlayerController.positionSeconds.value,
          ),
          category: SegmentType.sponsor,
          actionType: ActionType.skip,
        ),
      );
    }
    if (plPlayerController.isFullScreen.value) {
      bsController = scaffoldKey.currentState?.showBottomSheet(
        enableDrag: false,
        (context) => _postPanel(false),
      );
    } else {
      childKey.currentState?.showBottomSheet(
        enableDrag: false,
        (context) => _postPanel(),
      );
    }
  }

  Widget _postPanel([bool isChild = true]) => StatefulBuilder(
        builder: (context, setState) {
          void updateSegment({
            required bool isFirst,
            required int index,
            required int value,
          }) {
            if (isFirst) {
              list![index].segment.first = value;
            } else {
              list![index].segment.second = value;
            }
            if (list![index].category == SegmentType.poi_highlight ||
                list![index].actionType == ActionType.full) {
              list![index].segment.second = value;
            }
          }

          List<Widget> segmentWidget({
            required int index,
            required bool isFirst,
          }) {
            String value = Utils.timeFormat(isFirst
                ? list![index].segment.first
                : list![index].segment.second);
            return [
              Text(
                '${isFirst ? '开始' : '结束'}: $value',
              ),
              const SizedBox(width: 5),
              iconButton(
                context: context,
                size: 26,
                tooltip: '使用当前位置时间',
                icon: Icons.my_location,
                onPressed: () {
                  setState(() {
                    updateSegment(
                      isFirst: isFirst,
                      index: index,
                      value: plPlayerController.positionSeconds.value,
                    );
                  });
                },
              ),
              const SizedBox(width: 5),
              iconButton(
                context: context,
                size: 26,
                tooltip: '编辑',
                icon: Icons.edit,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      String initV = value;
                      return AlertDialog(
                        content: TextFormField(
                          initialValue: value,
                          autofocus: true,
                          onChanged: (value) {
                            initV = value;
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\d:]+'),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: Get.back,
                            child: Text(
                              '取消',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.outline),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Get.back(result: initV),
                            child: Text('确定'),
                          ),
                        ],
                      );
                    },
                  ).then((res) {
                    if (res != null) {
                      try {
                        List<int> split = (res as String)
                            .split(':')
                            .toList()
                            .reversed
                            .toList()
                            .map((e) => int.parse(e))
                            .toList();
                        int duration = 0;
                        for (int i = 0; i < split.length; i++) {
                          duration += split[i] * pow(60, i).toInt();
                        }
                        if (duration <=
                            plPlayerController.durationSeconds.value) {
                          setState(() {
                            updateSegment(
                              isFirst: isFirst,
                              index: index,
                              value: duration,
                            );
                          });
                        }
                      } catch (e) {
                        debugPrint(e.toString());
                      }
                    }
                  });
                },
              ),
            ];
          }

          return SizedBox(
            height: isChild ? null : Utils.getSheetHeight(context),
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                titleSpacing: 16,
                title: const Text('提交片段'),
                actions: [
                  iconButton(
                    context: context,
                    tooltip: '添加片段',
                    onPressed: () {
                      setState(() {
                        list?.insert(
                          0,
                          PostSegmentModel(
                            segment: Pair(
                              first: 0,
                              second: plPlayerController.positionSeconds.value,
                            ),
                            category: SegmentType.sponsor,
                            actionType: ActionType.skip,
                          ),
                        );
                      });
                    },
                    icon: Icons.add,
                  ),
                  const SizedBox(width: 10),
                  iconButton(
                    context: context,
                    tooltip: '关闭',
                    onPressed: () {
                      if (bsController != null) {
                        bsController!.close();
                        bsController = null;
                      } else {
                        Get.back();
                      }
                    },
                    icon: Icons.close,
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: list?.isNotEmpty == true
                  ? Stack(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              ...List.generate(
                                list!.length,
                                (index) => Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 5,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onInverseSurface,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (list![index].actionType !=
                                              ActionType.full) ...[
                                            Row(
                                              children: [
                                                ...segmentWidget(
                                                  isFirst: true,
                                                  index: index,
                                                ),
                                                if (list![index].category !=
                                                    SegmentType
                                                        .poi_highlight) ...[
                                                  const SizedBox(width: 16),
                                                  ...segmentWidget(
                                                    isFirst: false,
                                                    index: index,
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          Row(
                                            children: [
                                              const Text('分类: '),
                                              PopupMenuButton(
                                                initialValue:
                                                    list![index].category,
                                                onSelected: (item) async {
                                                  list![index].category = item;
                                                  List<ActionType>
                                                      constraintList =
                                                      _segmentType2ActionType(
                                                          item);
                                                  if (constraintList
                                                      .contains(list![index]
                                                          .actionType)
                                                      .not) {
                                                    list![index].actionType =
                                                        constraintList.first;
                                                  }
                                                  switch (item) {
                                                    case SegmentType
                                                          .poi_highlight:
                                                      updateSegment(
                                                        isFirst: false,
                                                        index: index,
                                                        value: list![index]
                                                            .segment
                                                            .first,
                                                      );
                                                      break;
                                                    case SegmentType
                                                          .exclusive_access:
                                                      updateSegment(
                                                        isFirst: true,
                                                        index: index,
                                                        value: 0,
                                                      );
                                                      break;
                                                    case _:
                                                  }
                                                  setState(() {});
                                                },
                                                itemBuilder: (context) =>
                                                    SegmentType.values
                                                        .map((item) =>
                                                            PopupMenuItem<
                                                                SegmentType>(
                                                              value: item,
                                                              child: Text(
                                                                  item.title),
                                                            ))
                                                        .toList(),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      list![index]
                                                          .category
                                                          .title,
                                                      style: TextStyle(
                                                        height: 1,
                                                        fontSize: 14,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                      strutStyle: StrutStyle(
                                                        height: 1,
                                                        leading: 0,
                                                      ),
                                                    ),
                                                    Icon(
                                                      MdiIcons
                                                          .unfoldMoreHorizontal,
                                                      size: MediaQuery
                                                              .textScalerOf(
                                                                  context)
                                                          .scale(14),
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              const Text('行为类别: '),
                                              PopupMenuButton(
                                                initialValue:
                                                    list![index].actionType,
                                                onSelected: (item) async {
                                                  list![index].actionType =
                                                      item;
                                                  if (item == ActionType.full) {
                                                    updateSegment(
                                                      isFirst: true,
                                                      index: index,
                                                      value: 0,
                                                    );
                                                  }
                                                  setState(() {});
                                                },
                                                itemBuilder: (context) =>
                                                    ActionType.values
                                                        .map(
                                                          (item) =>
                                                              PopupMenuItem<
                                                                  ActionType>(
                                                            enabled: _segmentType2ActionType(
                                                                    list![index]
                                                                        .category)
                                                                .contains(item),
                                                            value: item,
                                                            child: Text(
                                                                item.title),
                                                          ),
                                                        )
                                                        .toList(),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      list![index]
                                                          .actionType
                                                          .title,
                                                      style: TextStyle(
                                                        height: 1,
                                                        fontSize: 14,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                      strutStyle: StrutStyle(
                                                        height: 1,
                                                        leading: 0,
                                                      ),
                                                    ),
                                                    Icon(
                                                      MdiIcons
                                                          .unfoldMoreHorizontal,
                                                      size: MediaQuery
                                                              .textScalerOf(
                                                                  context)
                                                          .scale(14),
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 21,
                                      child: iconButton(
                                        context: context,
                                        size: 26,
                                        tooltip: '移除',
                                        icon: Icons.clear,
                                        onPressed: () {
                                          setState(() {
                                            list!.removeAt(index);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height:
                                    88 + MediaQuery.paddingOf(context).bottom,
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          right: 16,
                          bottom: 16 + MediaQuery.paddingOf(context).bottom,
                          child: FloatingActionButton(
                            tooltip: '提交',
                            onPressed: () {
                              Request()
                                  .post(
                                '${GStorage.blockServer}/api/skipSegments',
                                queryParameters: {
                                  'videoID': bvid,
                                  'cid': cid.value,
                                  'userID': GStorage.blockUserID,
                                  'userAgent': Constants.userAgent,
                                  'videoDuration':
                                      plPlayerController.durationSeconds.value,
                                },
                                data: {
                                  'segments': list!
                                      .map(
                                        (item) => {
                                          'segment': [
                                            item.segment.first,
                                            item.segment.second,
                                          ],
                                          'category': item.category.name,
                                          'actionType': item.actionType.name,
                                        },
                                      )
                                      .toList(),
                                },
                                options: _options,
                              )
                                  .then(
                                (res) {
                                  if (res.statusCode == 200) {
                                    Get.back();
                                    SmartDialog.showToast('提交成功');
                                    list?.clear();
                                    _handleSBData(res);
                                    plPlayerController.segmentList.value =
                                        _segmentProgressList ?? <Segment>[];
                                    if (positionSubscription == null) {
                                      _initSkip();
                                    }
                                  } else {
                                    SmartDialog.showToast(
                                      '提交失败: ${{
                                        400: '参数错误',
                                        403: '被自动审核机制拒绝',
                                        429: '重复提交太快',
                                        409: '重复提交'
                                      }[res.statusCode]}',
                                    );
                                  }
                                },
                              );
                            },
                            child: Icon(Icons.check),
                          ),
                        )
                      ],
                    )
                  : errorWidget(),
            ),
          );
        },
      );

  // List<SegmentType> _actionType2SegmentType(ActionType actionType) {
  //   return switch (actionType) {
  //     ActionType.skip => [
  //         SegmentType.sponsor,
  //         SegmentType.selfpromo,
  //         SegmentType.interaction,
  //         SegmentType.intro,
  //         SegmentType.outro,
  //         SegmentType.preview,
  //         SegmentType.filler,
  //       ],
  //     ActionType.mute => [
  //         SegmentType.sponsor,
  //         SegmentType.selfpromo,
  //         SegmentType.interaction,
  //         SegmentType.intro,
  //         SegmentType.outro,
  //         SegmentType.preview,
  //         SegmentType.music_offtopic,
  //         SegmentType.filler,
  //       ],
  //     ActionType.full => [
  //         SegmentType.sponsor,
  //         SegmentType.selfpromo,
  //         SegmentType.exclusive_access,
  //       ],
  //     ActionType.poi => [
  //         SegmentType.poi_highlight,
  //       ],
  //   };
  // }

  List<ActionType> _segmentType2ActionType(SegmentType segmentType) {
    return switch (segmentType) {
      SegmentType.sponsor => [
          ActionType.skip,
          ActionType.mute,
          ActionType.full
        ],
      SegmentType.selfpromo => [
          ActionType.skip,
          ActionType.mute,
          ActionType.full
        ],
      SegmentType.interaction => [
          ActionType.skip,
          ActionType.mute,
        ],
      SegmentType.intro => [
          ActionType.skip,
          ActionType.mute,
        ],
      SegmentType.outro => [
          ActionType.skip,
          ActionType.mute,
        ],
      SegmentType.preview => [
          ActionType.skip,
          ActionType.mute,
        ],
      SegmentType.music_offtopic => [
          ActionType.skip,
        ],
      SegmentType.poi_highlight => [ActionType.poi],
      SegmentType.filler => [
          ActionType.skip,
          ActionType.mute,
        ],
      SegmentType.exclusive_access => [ActionType.full],
    };
  }

  List<Map<String, String>> _vttSubtitles = <Map<String, String>>[];
  int? vttSubtitlesIndex;
  bool showVP = true;

  void _getSubtitle() {
    _vttSubtitles.clear();
    viewPointList.clear();
    _querySubtitles().then((value) {
      if (_vttSubtitles.isNotEmpty) {
        String preference = setting.get(
          SettingBoxKey.subtitlePreference,
          defaultValue: SubtitlePreference.values.first.code,
        );
        if (preference == 'on') {
          vttSubtitlesIndex = 1;
        } else if (preference == 'withoutAi') {
          for (int i = 1; i < _vttSubtitles.length; i++) {
            if (_vttSubtitles[i]['language']!.startsWith('ai')) {
              continue;
            }
            vttSubtitlesIndex = i;
            break;
          }
        }
        if (plPlayerController.vttSubtitles.isEmpty) {
          plPlayerController.vttSubtitles.value = _vttSubtitles;
          plPlayerController.vttSubtitlesIndex.value = vttSubtitlesIndex!;
          if (vttSubtitlesIndex != 0) {
            plPlayerController.setSubtitle(vttSubtitlesIndex!);
          }
        }
      }
    });
  }

  Future _querySubtitles() async {
    Map res = await VideoHttp.subtitlesJson(bvid: bvid, cid: cid.value);
    // if (!res["status"]) {
    //   SmartDialog.showToast('查询字幕错误，${res["msg"]}');
    // }

    if (res['status']) {
      vttSubtitlesIndex = 0;
      if (res["data"] is List && res["data"].isNotEmpty) {
        var result = await VideoHttp.vttSubtitles(res["data"]);
        if (result != null) {
          _vttSubtitles = result;
        }
        // if (_vttSubtitles.isEmpty) {
        //   SmartDialog.showToast('字幕均加载失败');
        // }
      }
      if (GStorage.showViewPoints &&
          res["view_points"] is List &&
          res["view_points"].isNotEmpty) {
        viewPointList = (res["view_points"] as List).map((item) {
          double start =
              (item['to'] / ((data.timeLength ?? 0) / 1000)).clamp(0.0, 1.0);
          return Segment(
            start,
            start,
            Colors.black87,
            item?['content'],
            item?['imgUrl'],
            item?['from'],
            item?['to'],
          );
        }).toList();
        if (plPlayerController.viewPointList.isEmpty) {
          plPlayerController.viewPointList.value = viewPointList;
          plPlayerController.showVP.value = showVP = true;
        }
      }
    }
  }
}
