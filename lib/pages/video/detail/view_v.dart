import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/icon_button.dart';
import 'package:PiliPlus/common/widgets/list_sheet.dart';
import 'package:PiliPlus/common/widgets/segment_progress_bar.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/bangumi/info.dart';
import 'package:PiliPlus/models/common/reply_type.dart';
import 'package:PiliPlus/pages/bangumi/introduction/widgets/intro_detail.dart'
    as bangumi;
import 'package:PiliPlus/pages/video/detail/introduction/widgets/intro_detail.dart'
    as video;
import 'package:PiliPlus/pages/video/detail/introduction/widgets/page.dart';
import 'package:PiliPlus/pages/video/detail/introduction/widgets/season.dart';
import 'package:PiliPlus/pages/video/detail/member/horizontal_member_page.dart';
import 'package:PiliPlus/pages/video/detail/reply_reply/view.dart';
import 'package:PiliPlus/pages/video/detail/widgets/ai_detail.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:auto_orientation/auto_orientation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:floating/floating.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:PiliPlus/common/widgets/network_img_layer.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models/common/search_type.dart';
import 'package:PiliPlus/pages/bangumi/introduction/index.dart';
import 'package:PiliPlus/pages/danmaku/view.dart';
import 'package:PiliPlus/pages/video/detail/reply/index.dart';
import 'package:PiliPlus/pages/video/detail/controller.dart';
import 'package:PiliPlus/pages/video/detail/introduction/index.dart';
import 'package:PiliPlus/pages/video/detail/related/index.dart';
import 'package:PiliPlus/plugin/pl_player/index.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/models/bangumi/info.dart' as bangumi;
import 'package:PiliPlus/models/video_detail_res.dart' as video;
import 'package:screen_brightness/screen_brightness.dart';

import '../../../services/shutdown_timer_service.dart';
import 'widgets/header_control.dart';
import 'package:PiliPlus/common/widgets/spring_physics.dart';

class VideoDetailPageV extends StatefulWidget {
  const VideoDetailPageV({super.key});

  @override
  State<VideoDetailPageV> createState() => _VideoDetailPageVState();
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();
}

class _VideoDetailPageVState extends State<VideoDetailPageV>
    with TickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  late VideoDetailController videoDetailController;
  late VideoReplyController _videoReplyController;
  PlPlayerController? plPlayerController;
  late StreamController<double> appbarStream;
  late VideoIntroController videoIntroController;
  late BangumiIntroController bangumiIntroController;
  late final _introController = ScrollController();
  late String heroTag;

  double doubleOffset = 0;

  // 自动退出全屏
  late bool autoExitFullscreen;
  late bool autoPlayEnable;
  late bool horizontalScreen;
  late bool enableVerticalExpand;
  late bool autoPiP;
  late bool pipNoDanmaku;
  late bool removeSafeArea;
  // late bool showStatusBarBackgroundColor;
  // final Floating floating = Floating();
  // 生命周期监听
  // late final AppLifecycleListener _lifecycleListener;
  bool isShowing = true;
  // StreamSubscription<Duration>? _bufferedListener;
  bool get isFullScreen => plPlayerController?.isFullScreen.value ?? false;

  bool get _shouldShowSeasonPanel =>
      (videoIntroController.videoDetail.value.ugcSeason != null ||
          ((videoIntroController.videoDetail.value.pages?.length ?? 0) > 1)) &&
      context.orientation == Orientation.landscape &&
      videoDetailController.horizontalSeasonPanel;

  bool get _horizontalPreview =>
      context.orientation == Orientation.landscape &&
      videoDetailController.horizontalPreview;

  StreamSubscription? _listenerDetail;
  StreamSubscription? _listenerLoadingState;
  StreamSubscription? _listenerCid;
  StreamSubscription? _listenerFS;

  Box get setting => GStorage.setting;

  final GlobalKey relatedVideoPanelKey = GlobalKey();
  final GlobalKey videoPlayerKey = GlobalKey();
  final GlobalKey videoReplyPanelKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    PlPlayerController.setPlayCallBack(playCallBack);
    if (Get.arguments != null && Get.arguments['heroTag'] != null) {
      heroTag = Get.arguments['heroTag'];
    }
    videoDetailController = Get.put(VideoDetailController(), tag: heroTag);

    if (videoDetailController.showReply) {
      _videoReplyController = Get.put(
        VideoReplyController(aid: videoDetailController.oid.value),
        tag: heroTag,
      );
    }
    videoIntroController = Get.put(VideoIntroController(), tag: heroTag);
    _listenerDetail = videoIntroController.videoDetail.listen((value) {
      if (!context.mounted) return;
      videoPlayerServiceHandler.onVideoDetailChange(
          value, videoDetailController.cid.value, heroTag);
    });
    if (videoDetailController.videoType == SearchType.media_bangumi) {
      bangumiIntroController = Get.put(BangumiIntroController(), tag: heroTag);
      _listenerLoadingState =
          bangumiIntroController.loadingState.listen((value) {
        if (!context.mounted) return;
        if (value is Success) {
          videoPlayerServiceHandler.onVideoDetailChange(
              value.response, videoDetailController.cid.value, heroTag);
        }
      });
      _listenerCid = videoDetailController.cid.listen((p0) {
        if (!context.mounted) return;
        if (bangumiIntroController.loadingState.value is Success) {
          videoPlayerServiceHandler.onVideoDetailChange(
              (bangumiIntroController.loadingState.value as Success).response,
              p0,
              heroTag);
        }
      });
    }
    autoExitFullscreen =
        setting.get(SettingBoxKey.enableAutoExit, defaultValue: true);
    horizontalScreen =
        setting.get(SettingBoxKey.horizontalScreen, defaultValue: false);
    autoPlayEnable =
        setting.get(SettingBoxKey.autoPlayEnable, defaultValue: false);
    autoPiP = setting.get(SettingBoxKey.autoPiP, defaultValue: false);
    pipNoDanmaku = setting.get(SettingBoxKey.pipNoDanmaku, defaultValue: false);
    enableVerticalExpand =
        setting.get(SettingBoxKey.enableVerticalExpand, defaultValue: false);
    removeSafeArea = setting.get(SettingBoxKey.videoPlayerRemoveSafeArea,
        defaultValue: false);
    // showStatusBarBackgroundColor = setting.get(
    //     SettingBoxKey.videoPlayerShowStatusBarBackgroundColor,
    //     defaultValue: false);
    if (removeSafeArea) hideStatusBar();
    videoSourceInit();
    appbarStreamListen();
    // lifecycleListener();
    autoScreen();
    if (Platform.isAndroid) {
      Utils.channel.setMethodCallHandler((call) async {
        if (call.method == 'onUserLeaveHint') {
          if (autoPiP &&
              plPlayerController?.playerStatus.status.value ==
                  PlayerStatus.playing) {
            enterPip();
          }
        }
      });
    }

    if (videoDetailController.showReply) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        videoDetailController.scrollKey.currentState?.innerController
            .addListener(innerScrollListener);
      });
      videoDetailController.tabCtr.addListener(tabCtrListener);
    }

    videoDetailController.animationController.addListener(animListener);

    _listenerFS =
        videoDetailController.plPlayerController.isFullScreen.listen((value) {
      refreshPage();
    });

    WidgetsBinding.instance.addObserver(this);
  }

  // 获取视频资源，初始化播放器
  Future<void> videoSourceInit() async {
    videoDetailController.queryVideoUrl();
    if (videoDetailController.showReply) {
      _videoReplyController.queryData();
    }
    if (videoDetailController.autoPlay.value) {
      plPlayerController = videoDetailController.plPlayerController;
      plPlayerController!.addStatusLister(playerListener);
      plPlayerController!.addPositionListener(positionListener);
      await plPlayerController!.autoEnterFullscreen();
    }
  }

  void positionListener(Duration position) {
    videoDetailController.playedTime = position;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      videoIntroController.startTimer();
      videoDetailController.plPlayerController.showDanmaku = true;
    } else if (state == AppLifecycleState.paused) {
      videoIntroController.canelTimer();
      videoDetailController.plPlayerController.showDanmaku = false;
    }
  }

  void playCallBack() {
    plPlayerController?.play();
  }

  // 流
  appbarStreamListen() {
    appbarStream = StreamController<double>();
  }

  // 播放器状态监听
  void playerListener(PlayerStatus? status) async {
    try {
      if (videoDetailController.scrollCtr.hasClients) {
        bool isPlaying = status == PlayerStatus.playing;
        if (isPlaying) {
          if (videoDetailController.isExpanding.not &&
              videoDetailController.scrollCtr.offset != 0 &&
              videoDetailController.animationController.isAnimating.not) {
            videoDetailController.isExpanding = true;
            videoDetailController.animationController.forward(
                from: 1 -
                    videoDetailController.scrollCtr.offset /
                        videoDetailController.videoHeight);
          } else {
            refreshPage();
          }
        } else {
          refreshPage();
        }
      }
    } catch (e) {
      debugPrint('handle playe status: $e');
    }

    if (status == PlayerStatus.completed) {
      try {
        if ((videoDetailController.steinEdgeInfo?['edges']['questions'][0]
                    ['choices'] as List?)
                ?.isNotEmpty ==
            true) {
          videoDetailController.showSteinEdgeInfo.value = true;
          return;
        }
      } catch (_) {}
      shutdownTimerService.handleWaitingFinished();
      bool notExitFlag = false;

      /// 顺序播放 列表循环
      if (videoDetailController.isPlayAll) {
        notExitFlag = videoIntroController.nextPlay();
      } else if (plPlayerController!.playRepeat != PlayRepeat.pause &&
          plPlayerController!.playRepeat != PlayRepeat.singleCycle) {
        if (videoDetailController.videoType == SearchType.video) {
          notExitFlag = videoIntroController.nextPlay();
        } else if (videoDetailController.videoType ==
            SearchType.media_bangumi) {
          notExitFlag = bangumiIntroController.nextPlay();
        }
      }

      /// 单个循环
      if (plPlayerController!.playRepeat == PlayRepeat.singleCycle) {
        notExitFlag = true;
        plPlayerController!.play(repeat: true);
      }

      // 结束播放退出全屏
      if (!notExitFlag && autoExitFullscreen) {
        plPlayerController!.triggerFullScreen(status: false);
        if (plPlayerController!.doubleSpeedStatus.value) {
          plPlayerController!.setDoubleSpeedStatus(false);
        }
        if (plPlayerController!.controlsLock.value) {
          plPlayerController!.onLockControl(false);
        }
      }
      // 播放完展示控制栏
      if (videoDetailController.floating != null && !notExitFlag) {
        PiPStatus currentStatus =
            await videoDetailController.floating!.pipStatus;
        if (currentStatus == PiPStatus.disabled) {
          plPlayerController!.onLockControl(false);
        }
      }
    }
  }

  // 继续播放或重新播放
  void continuePlay() async {
    plPlayerController!.play();
  }

  /// 未开启自动播放时触发播放
  Future<void> handlePlay() async {
    if (videoDetailController.isQuerying) {
      debugPrint('handlePlay: querying');
      return;
    }
    if (videoDetailController.videoUrl == null ||
        videoDetailController.audioUrl == null) {
      debugPrint('handlePlay: videoUrl/audioUrl not initialized');
      videoDetailController.queryVideoUrl();
      return;
    }
    plPlayerController = videoDetailController.plPlayerController;
    videoDetailController.isShowCover.value = false;
    videoDetailController.autoPlay.value = true;
    if (videoDetailController.preInitPlayer) {
      await plPlayerController!.play();
    } else {
      await videoDetailController.playerInit(autoplay: true);
    }
    plPlayerController!.addStatusLister(playerListener);
    plPlayerController!.addPositionListener(positionListener);
    await plPlayerController!.autoEnterFullscreen();
  }

  // // 生命周期监听
  // void lifecycleListener() {
  //   _lifecycleListener = AppLifecycleListener(
  //     onResume: () => _handleTransition('resume'),
  //     // 后台
  //     onInactive: () => _handleTransition('inactive'),
  //     // 在Android和iOS端不生效
  //     onHide: () => _handleTransition('hide'),
  //     onShow: () => _handleTransition('show'),
  //     onPause: () => _handleTransition('pause'),
  //     onRestart: () => _handleTransition('restart'),
  //     onDetach: () => _handleTransition('detach'),
  //     // 只作用于桌面端
  //     onExitRequested: () {
  //       ScaffoldMessenger.maybeOf(context)
  //           ?.showSnackBar(const SnackBar(content: Text("拦截应用退出")));
  //       return Future.value(AppExitResponse.cancel);
  //     },
  //   );
  // }

  @override
  void dispose() {
    _listenerDetail?.cancel();
    _listenerLoadingState?.cancel();
    _listenerCid?.cancel();
    _listenerFS?.cancel();

    videoDetailController.skipTimer?.cancel();
    videoDetailController.skipTimer = null;

    try {
      videoDetailController.tabCtr.removeListener(tabCtrListener);
      videoDetailController.animationController.removeListener(animListener);
      if (videoDetailController.showReply) {
        videoDetailController.scrollKey.currentState?.innerController
            .removeListener(innerScrollListener);
      }
    } catch (_) {}

    WidgetsBinding.instance.removeObserver(this);
    if (!Get.previousRoute.startsWith('/video')) {
      ScreenBrightness().resetApplicationScreenBrightness();
      PlPlayerController.setPlayCallBack(null);
    }
    videoDetailController.positionSubscription?.cancel();
    videoIntroController.canelTimer();
    appbarStream.close();
    // floating.dispose();
    // videoDetailController.floating?.dispose();
    videoIntroController.videoDetail.close();
    videoDetailController.cid.close();
    if (!horizontalScreen) {
      AutoOrientation.portraitUpMode();
    }
    shutdownTimerService.handleWaitingFinished();
    // _bufferedListener?.cancel();
    if (videoDetailController.backToHome != true) {
      videoPlayerServiceHandler.onVideoDetailDispose(heroTag);
    }
    if (plPlayerController != null) {
      videoDetailController.makeHeartBeat();
      plPlayerController!.removeStatusLister(playerListener);
      plPlayerController!.removePositionListener(positionListener);
      plPlayerController!.dispose();
    } else {
      PlPlayerController.updatePlayCount();
    }
    VideoDetailPageV.routeObserver.unsubscribe(this);
    // _lifecycleListener.dispose();
    showStatusBar();
    // _animationController.dispose();
    super.dispose();
  }

  @override
  // 离开当前页面时
  void didPushNext() async {
    // _bufferedListener?.cancel();
    if (videoDetailController.imageStatus) {
      return;
    }

    WidgetsBinding.instance.removeObserver(this);

    ScreenBrightness().resetApplicationScreenBrightness();

    videoDetailController.positionSubscription?.cancel();
    videoIntroController.canelTimer();

    videoDetailController.playerStatus =
        plPlayerController?.playerStatus.status.value;

    /// 开启
    // if (setting.get(SettingBoxKey.enableAutoBrightness, defaultValue: true)
    //     as bool) {
    videoDetailController.brightness = plPlayerController?.brightness.value;
    // }
    if (plPlayerController != null) {
      videoDetailController.makeHeartBeat();
      videoDetailController.vttSubtitlesIndex =
          plPlayerController!.vttSubtitlesIndex.value;
      videoDetailController.showVP = plPlayerController!.showVP.value;
      plPlayerController!.removeStatusLister(playerListener);
      plPlayerController!.removePositionListener(positionListener);
      plPlayerController!.pause();
    }
    isShowing = false;
    super.didPushNext();
  }

  @override
  // 返回当前页面时
  void didPopNext() async {
    if (videoDetailController.imageStatus) {
      return;
    }

    WidgetsBinding.instance.addObserver(this);

    if (videoDetailController.plPlayerController.playerStatus.status.value ==
            PlayerStatus.playing &&
        videoDetailController.playerStatus != PlayerStatus.playing) {
      videoDetailController.plPlayerController.pause();
    }

    isShowing = true;
    PlPlayerController.setPlayCallBack(playCallBack);
    videoIntroController.startTimer();
    if (mounted) {
      if (videoDetailController.brightness != null) {
        plPlayerController
            ?.setCurrBrightness(videoDetailController.brightness!);
        if (videoDetailController.brightness != -1.0) {
          ScreenBrightness().setApplicationScreenBrightness(
              videoDetailController.brightness!);
        } else {
          ScreenBrightness().resetApplicationScreenBrightness();
        }
      } else {
        ScreenBrightness().resetApplicationScreenBrightness();
      }
    }
    super.didPopNext();
    // final bool autoplay = autoPlayEnable;
    videoDetailController.autoPlay.value =
        !videoDetailController.isShowCover.value;
    if (videoDetailController.isShowCover.value.not) {
      await videoDetailController.playerInit(
        autoplay: videoDetailController.playerStatus == PlayerStatus.playing,
      );
    } else if (videoDetailController.preInitPlayer &&
        videoDetailController.isQuerying.not &&
        videoDetailController.videoState.value is! Error) {
      await videoDetailController.playerInit();
    }

    // if (videoDetailController.playerStatus == PlayerStatus.playing) {
    //   plPlayerController?.play();
    // }

    /// 未开启自动播放时，未播放跳转下一页返回/播放后跳转下一页返回
    // if (autoplay) {
    //   // await Future.delayed(const Duration(milliseconds: 300));
    //   debugPrint(plPlayerController);
    //   if (plPlayerController?.buffered.value == Duration.zero) {
    //     _bufferedListener = plPlayerController?.buffered.listen((p0) {
    //       debugPrint("p0");
    //       debugPrint(p0);
    //       if (p0 > Duration.zero) {
    //         _bufferedListener!.cancel();
    //         plPlayerController?.seekTo(videoDetailController.defaultST);
    //         plPlayerController?.play();
    //       }
    //     });
    //   } else {
    //     plPlayerController?.seekTo(videoDetailController.defaultST);
    //     plPlayerController?.play();
    //   }
    // }
    Future.delayed(const Duration(milliseconds: 600), () {
      AutoOrientation.fullAutoMode();
    });
    plPlayerController?.addStatusLister(playerListener);
    plPlayerController?.addPositionListener(positionListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    VideoDetailPageV.routeObserver
        .subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  // void _handleTransition(String name) {
  //   switch (name) {
  //     case 'inactive':
  //       if (plPlayerController != null &&
  //           playerStatus == PlayerStatus.playing) {
  //         autoEnterPip();
  //       }
  //       break;
  //   }
  // }

  void enterPip() {
    if (Get.currentRoute.startsWith('/video')) {
      videoDetailController.floating?.enable(
        EnableManual(
          aspectRatio: Rational(
            videoDetailController.data.dash!.video!.first.width!,
            videoDetailController.data.dash!.video!.first.height!,
          ),
        ),
      );
    }
  }

  void animListener() {
    if (videoDetailController.animationController.isForwardOrCompleted) {
      cal();
      refreshPage();
    }
  }

  late double animHeight;
  void cal() {
    if (videoDetailController.isExpanding) {
      animHeight = clampDouble(
          videoDetailController.videoHeight *
              videoDetailController.animationController.value,
          kToolbarHeight,
          videoDetailController.videoHeight);
    } else if (videoDetailController.isCollapsing) {
      animHeight = clampDouble(
          videoDetailController.maxVideoHeight -
              (videoDetailController.maxVideoHeight -
                      videoDetailController.minVideoHeight) *
                  videoDetailController.animationController.value,
          videoDetailController.minVideoHeight,
          videoDetailController.maxVideoHeight);
    }
  }

  void innerScrollListener() {
    final ScrollDirection? direction = videoDetailController
        .scrollKey
        .currentState
        ?.innerController
        .positions
        .firstOrNull
        ?.userScrollDirection;
    if (direction == ScrollDirection.forward) {
      if (mounted) {
        _videoReplyController.showFab();
      }
    } else if (direction == ScrollDirection.reverse) {
      if (mounted) {
        _videoReplyController.hideFab();
      }
    }
  }

  void tabCtrListener() {
    if (videoDetailController.scrollCtr.hasClients) {
      if (videoDetailController.tabCtr.index != 1) {
        _videoReplyController.hideFab();
      } else {
        _videoReplyController.showFab();
      }
    }
  }

  void refreshPage() {
    if (videoDetailController.scrollKey.currentState?.mounted == true) {
      videoDetailController.scrollKey.currentState?.setState(() {});
    }
  }

  Widget get childWhenDisabled => SafeArea(
        top: !removeSafeArea &&
            MediaQuery.of(context).orientation == Orientation.portrait &&
            isFullScreen,
        bottom: !removeSafeArea &&
            MediaQuery.of(context).orientation == Orientation.portrait &&
            isFullScreen,
        left: false, //!isFullScreen,
        right: false, //!isFullScreen,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          key: videoDetailController.scaffoldKey,
          // backgroundColor: Colors.black,
          appBar: removeSafeArea
              ? null
              : PreferredSize(
                  preferredSize: Size.fromHeight(0),
                  child: Obx(
                    () => Stack(
                      children: [
                        AppBar(
                          backgroundColor: Colors.black,
                          toolbarHeight: 0,
                        ),
                        if (videoDetailController.scrollRatio.value != 0 &&
                            videoDetailController.scrollCtr.offset != 0 &&
                            context.orientation == Orientation.portrait)
                          AppBar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surface
                                .withOpacity(
                                    videoDetailController.scrollRatio.value),
                            toolbarHeight: 0,
                          ),
                      ],
                    ),
                  ),
                ),
          body: ExtendedNestedScrollView(
            key: videoDetailController.scrollKey,
            physics: const NeverScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            controller: videoDetailController.scrollCtr,
            onlyOneScrollInBody: true,
            pinnedHeaderSliverHeightBuilder: () {
              double height = isFullScreen ||
                      context.orientation == Orientation.landscape
                  ? MediaQuery.sizeOf(context).height
                  : videoDetailController.isExpanding ||
                          videoDetailController.isCollapsing
                      ? animHeight
                      : videoDetailController.isCollapsing ||
                              plPlayerController?.playerStatus.status.value ==
                                  PlayerStatus.playing
                          ? videoDetailController.minVideoHeight
                          : kToolbarHeight;
              if (videoDetailController.isExpanding &&
                  videoDetailController.animationController.value == 1) {
                videoDetailController.isExpanding = false;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  videoDetailController.scrollRatio.value = 0;
                  refreshPage();
                });
              } else if (videoDetailController.isCollapsing &&
                  videoDetailController.animationController.value == 1) {
                videoDetailController.isCollapsing = false;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  refreshPage();
                });
              }
              return height;
            },
            headerSliverBuilder:
                (BuildContext context, bool innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  primary: false,
                  automaticallyImplyLeading: false,
                  pinned: true,
                  expandedHeight: isFullScreen ||
                          context.orientation == Orientation.landscape
                      ? MediaQuery.sizeOf(context).height
                      : videoDetailController.isExpanding ||
                              videoDetailController.isCollapsing
                          ? animHeight
                          : videoDetailController.videoHeight,
                  flexibleSpace: Stack(
                    children: [
                      Builder(
                        builder: (context) {
                          final double videoWidth = context.width;
                          if (MediaQuery.of(context).orientation ==
                                  Orientation.landscape &&
                              !horizontalScreen &&
                              !isFullScreen &&
                              isShowing &&
                              mounted) {
                            hideStatusBar();
                          }
                          if (MediaQuery.of(context).orientation ==
                                  Orientation.portrait &&
                              !isFullScreen &&
                              isShowing &&
                              mounted) {
                            if (videoDetailController.imageStatus.not &&
                                removeSafeArea.not) {
                              showStatusBar();
                            }
                          }
                          return Container(
                            color: Colors.black,
                            // showStatusBarBackgroundColor ? null : Colors.black,
                            height: MediaQuery.of(context).orientation ==
                                        Orientation.landscape ||
                                    isFullScreen
                                ? MediaQuery.sizeOf(context).height -
                                    (MediaQuery.of(context).orientation ==
                                                Orientation.landscape ||
                                            removeSafeArea
                                        ? 0
                                        : MediaQuery.of(this.context)
                                            .padding
                                            .top)
                                : videoDetailController.isExpanding ||
                                        videoDetailController.isCollapsing
                                    ? animHeight
                                    : videoDetailController.videoHeight,
                            width: context.width,
                            child: PopScope(
                              canPop: !isFullScreen &&
                                  (horizontalScreen ||
                                      MediaQuery.of(context).orientation ==
                                          Orientation.portrait),
                              onPopInvokedWithResult: _onPopInvokedWithResult,
                              child: videoPlayer(
                                videoWidth,
                                context.orientation == Orientation.landscape ||
                                        isFullScreen
                                    ? context.height
                                    : videoDetailController.isExpanding ||
                                            videoDetailController.isCollapsing
                                        ? animHeight
                                        : videoDetailController.videoHeight,
                              ),
                            ),
                          );
                        },
                      ),
                      Obx(
                        () {
                          Widget toolbar() => Opacity(
                                opacity:
                                    videoDetailController.scrollRatio.value,
                                child: Container(
                                  color: Theme.of(context).colorScheme.surface,
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    height: kToolbarHeight,
                                    child: Stack(
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 42,
                                                height: 34,
                                                child: IconButton(
                                                  tooltip: '返回',
                                                  icon: Icon(
                                                    FontAwesomeIcons.arrowLeft,
                                                    size: 15,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                  onPressed: Get.back,
                                                ),
                                              ),
                                              SizedBox(
                                                width: 42,
                                                height: 34,
                                                child: IconButton(
                                                  tooltip: '返回主页',
                                                  icon: Icon(
                                                    FontAwesomeIcons.house,
                                                    size: 15,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface,
                                                  ),
                                                  onPressed: () {
                                                    videoDetailController
                                                        .backToHome = true;
                                                    Get.until((route) =>
                                                        route.isFirst);
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.play_arrow_rounded,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                              ),
                                              Text(
                                                '${videoDetailController.playedTime == null ? '立即' : plPlayerController!.playerStatus.status.value == PlayerStatus.completed ? '重新' : '继续'}播放',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                          return videoDetailController.scrollRatio.value == 0 ||
                                  videoDetailController.scrollCtr.offset == 0 ||
                                  context.orientation != Orientation.portrait
                              ? const SizedBox.shrink()
                              : Positioned.fill(
                                  bottom: -2,
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (videoDetailController.isQuerying) {
                                        debugPrint('handlePlay: querying');
                                        return;
                                      }
                                      if (videoDetailController.videoUrl ==
                                              null ||
                                          videoDetailController.audioUrl ==
                                              null) {
                                        debugPrint(
                                            'handlePlay: videoUrl/audioUrl not initialized');
                                        videoDetailController.queryVideoUrl();
                                        return;
                                      }
                                      videoDetailController.scrollRatio.value =
                                          0;
                                      if (plPlayerController == null ||
                                          videoDetailController.playedTime ==
                                              null) {
                                        handlePlay();
                                      } else {
                                        if (plPlayerController!
                                            .videoPlayerController!
                                            .state
                                            .completed) {
                                          await plPlayerController!
                                              .videoPlayerController!
                                              .seek(Duration.zero);
                                          plPlayerController!
                                              .videoPlayerController!
                                              .play();
                                        } else {
                                          plPlayerController!
                                              .videoPlayerController!
                                              .playOrPause();
                                        }
                                      }
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: toolbar(),
                                  ),
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ];
            },
            body: Scaffold(
              key: videoDetailController.childKey,
              resizeToAvoidBottomInset: false,
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  buildTabbar(
                    showReply: videoDetailController.showReply,
                    onTap: () {
                      videoDetailController
                          .scrollKey.currentState?.outerController
                          .animToTop();
                    },
                  ),
                  Expanded(
                    child: videoTabBarView(
                      controller: videoDetailController.tabCtr,
                      children: [
                        videoIntro(true, false),
                        if (videoDetailController.showReply)
                          videoReplyPanel(false),
                        if (_shouldShowSeasonPanel) seasonPanel,
                      ],
                    ),
                  ),
                ],
              ),
              floatingActionButton: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 2),
                  end: const Offset(0, 0),
                ).animate(CurvedAnimation(
                  parent: _videoReplyController.fabAnimationCtr,
                  curve: Curves.easeInOut,
                )),
                child: FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    feedBack();
                    _videoReplyController.onReply(
                      context,
                      oid: _videoReplyController.aid,
                      replyType: ReplyType.video,
                    );
                  },
                  tooltip: '发表评论',
                  child: const Icon(Icons.reply),
                ),
              ),
            ),
          ),
        ),
      );

  Widget get childWhenDisabledAlmostSquareInner => Obx(
        () {
          if (enableVerticalExpand &&
              videoDetailController.direction.value == 'vertical') {
            final double videoHeight = context.height -
                (removeSafeArea
                    ? 0
                    : (MediaQuery.of(context).padding.top +
                        MediaQuery.of(context).padding.bottom));
            final double videoWidth = videoHeight * 9 / 16;
            return Row(
              children: [
                SizedBox(
                  height: videoHeight,
                  width: isFullScreen ? context.width : videoWidth,
                  child: PopScope(
                    canPop: !isFullScreen,
                    onPopInvokedWithResult: _onPopInvokedWithResult,
                    child: videoPlayer(videoWidth, videoHeight),
                  ),
                ),
                Expanded(
                  child: Scaffold(
                    key: videoDetailController.childKey,
                    resizeToAvoidBottomInset: false,
                    backgroundColor: Colors.transparent,
                    body: Column(
                      children: [
                        buildTabbar(showReply: videoDetailController.showReply),
                        Expanded(
                          child: videoTabBarView(
                            controller: videoDetailController.tabCtr,
                            children: [
                              videoIntro(),
                              if (videoDetailController.showReply)
                                videoReplyPanel(),
                              if (_shouldShowSeasonPanel) seasonPanel,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          final double videoHeight = context.height / 2.5;
          final double videoWidth = context.width;
          return Column(
            children: [
              SizedBox(
                width: videoWidth,
                height: isFullScreen
                    ? context.height -
                        (removeSafeArea
                            ? 0
                            : (MediaQuery.of(context).padding.top +
                                MediaQuery.of(context).padding.bottom))
                    : videoHeight,
                child: PopScope(
                  canPop: !isFullScreen,
                  onPopInvokedWithResult: _onPopInvokedWithResult,
                  child: videoPlayer(videoWidth, videoHeight),
                ),
              ),
              Expanded(
                child: Scaffold(
                  key: videoDetailController.childKey,
                  resizeToAvoidBottomInset: false,
                  backgroundColor: Colors.transparent,
                  body: Column(
                    children: [
                      buildTabbar(
                        needIndicator: false,
                        showReply: videoDetailController.showReply,
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: videoIntro()),
                            if (videoDetailController.showReply)
                              Expanded(child: videoReplyPanel()),
                            if (_shouldShowSeasonPanel)
                              Expanded(child: seasonPanel),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );

  Widget get childWhenDisabledLandscapeInner => Obx(
        () {
          if (enableVerticalExpand &&
              videoDetailController.direction.value == 'vertical') {
            final double videoHeight = context.height -
                (removeSafeArea ? 0 : MediaQuery.of(context).padding.top);
            final double videoWidth = videoHeight * 9 / 16;
            return Row(
              children: [
                Expanded(
                    child:
                        isFullScreen ? const SizedBox.shrink() : videoIntro()),
                SizedBox(
                  height: videoHeight,
                  width: isFullScreen ? context.width : videoWidth,
                  child: PopScope(
                    canPop: !isFullScreen,
                    onPopInvokedWithResult: _onPopInvokedWithResult,
                    child: videoPlayer(videoWidth, videoHeight),
                  ),
                ),
                Expanded(
                  child: Expanded(
                    child: Scaffold(
                      key: videoDetailController.childKey,
                      resizeToAvoidBottomInset: false,
                      backgroundColor: Colors.transparent,
                      body: Column(
                        children: [
                          buildTabbar(
                            showIntro: false,
                            showReply: videoDetailController.showReply,
                          ),
                          Expanded(
                            child: videoTabBarView(
                              controller: videoDetailController.tabCtr,
                              children: [
                                if (videoDetailController.showReply)
                                  videoReplyPanel(),
                                if (_shouldShowSeasonPanel) seasonPanel,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Expanded(
                //   child: TabBarView(
                //     physics: const ClampingScrollPhysics(),
                //     controller: videoDetailController.tabCtr,
                //     children: [
                //       CustomScrollView(
                //         key: const PageStorageKey<String>('简介'),
                //         slivers: [
                //           if (videoDetailController.videoType ==
                //               SearchType.video) ...[
                //             const VideoIntroPanel(),
                //           ] else if (videoDetailController.videoType ==
                //               SearchType.media_bangumi) ...[
                //             Obx(() => BangumiIntroPanel(
                //                 cid: videoDetailController.cid.value)),
                //           ],
                //           SliverToBoxAdapter(
                //             child: Divider(
                //               indent: 12,
                //               endIndent: 12,
                //               color: Theme.of(context).dividerColor.withOpacity(0.06),
                //             ),
                //           ),
                //           const RelatedVideoPanel(),
                //         ],
                //       ),
                //       Obx(
                //             () => VideoReplyPanel(
                //           bvid: videoDetailController.bvid,
                //           oid: videoDetailController.oid.value,
                //         ),
                //       )
                //     ],
                //   ),
                // ),
              ],
            );
          }
          double videoWidth =
              max(context.height / context.width * 1.04, 1 / 2) * context.width;
          if (context.width >= 560) {
            videoWidth = min(videoWidth, context.width - 280);
          }
          final double videoHeight = videoWidth * 9 / 16;
          return Row(
            children: [
              Column(
                children: [
                  SizedBox(
                    width: isFullScreen ? context.width : videoWidth,
                    height: isFullScreen ? context.height : videoHeight,
                    child: PopScope(
                      canPop: !isFullScreen,
                      onPopInvokedWithResult: _onPopInvokedWithResult,
                      child: videoPlayer(videoWidth, videoHeight),
                    ),
                  ),
                  Offstage(
                    offstage: isFullScreen,
                    child: SizedBox(
                      width: videoWidth,
                      height: context.height -
                          videoHeight -
                          (removeSafeArea
                              ? 0
                              : MediaQuery.of(context).padding.top),
                      child: videoIntro(false, false),
                    ),
                  ),
                ],
              ),
              Offstage(
                offstage: isFullScreen,
                child: SizedBox(
                  width: (context.width -
                      videoWidth -
                      (removeSafeArea
                          ? 0
                          : (MediaQuery.of(context).padding.left +
                              MediaQuery.of(context).padding.right))),
                  height: context.height -
                      (removeSafeArea ? 0 : MediaQuery.of(context).padding.top),
                  child: Scaffold(
                    key: videoDetailController.childKey,
                    resizeToAvoidBottomInset: false,
                    backgroundColor: Colors.transparent,
                    body: Column(
                      children: [
                        buildTabbar(
                          introText: '相关视频',
                          showIntro: videoDetailController.videoType ==
                                  SearchType.video &&
                              videoDetailController.showRelatedVideo,
                          showReply: videoDetailController.showReply,
                        ),
                        Expanded(
                          child: videoTabBarView(
                            controller: videoDetailController.tabCtr,
                            children: [
                              if (videoDetailController.videoType ==
                                      SearchType.video &&
                                  videoDetailController.showRelatedVideo)
                                CustomScrollView(
                                  controller: _introController,
                                  slivers: [
                                    RelatedVideoPanel(
                                        key: relatedVideoPanelKey,
                                        heroTag: heroTag),
                                  ],
                                ),
                              if (videoDetailController.showReply)
                                videoReplyPanel(),
                              if (_shouldShowSeasonPanel) seasonPanel,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            ],
          );
        },
      );

  Widget get childWhenDisabledLandscape => Stack(
        children: [
          Scaffold(
            resizeToAvoidBottomInset: false,
            key: videoDetailController.scaffoldKey,
            // backgroundColor: Colors.black,
            appBar: removeSafeArea
                ? null
                : AppBar(
                    backgroundColor: Colors.black,
                    // showStatusBarBackgroundColor ? null : Colors.black,
                    toolbarHeight: 0,
                    // systemOverlayStyle: SystemUiOverlayStyle(
                    //   statusBarIconBrightness:
                    //       Theme.of(context).brightness == Brightness.dark ||
                    //               !showStatusBarBackgroundColor
                    //           ? Brightness.light
                    //           : Brightness.dark,
                    //   systemNavigationBarColor: Colors.transparent,
                    // ),
                  ),
            body: Container(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                  left: !removeSafeArea && !isFullScreen,
                  right: !removeSafeArea && !isFullScreen,
                  top: !removeSafeArea,
                  bottom: false, //!removeSafeArea,
                  child: childWhenDisabledLandscapeInner),
            ),
          ),
        ],
      );

  Widget get childWhenDisabledAlmostSquare => Stack(children: [
        Scaffold(
            resizeToAvoidBottomInset: false,
            key: videoDetailController.scaffoldKey,
            // backgroundColor: Colors.black,
            appBar: removeSafeArea
                ? null
                : AppBar(
                    backgroundColor: Colors.black,
                    // showStatusBarBackgroundColor ? null : Colors.black,
                    toolbarHeight: 0,
                    // systemOverlayStyle: SystemUiOverlayStyle(
                    //   statusBarIconBrightness:
                    //       Theme.of(context).brightness == Brightness.dark ||
                    //               !showStatusBarBackgroundColor
                    //           ? Brightness.light
                    //           : Brightness.dark,
                    //   systemNavigationBarColor: Colors.transparent,
                    // ),
                  ),
            body: Container(
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                    left: !removeSafeArea && !isFullScreen,
                    right: !removeSafeArea && !isFullScreen,
                    top: !removeSafeArea,
                    bottom: false, //!removeSafeArea,
                    child: childWhenDisabledAlmostSquareInner)))
      ]);

  Widget get childWhenEnabled => Obx(
        () => !videoDetailController.autoPlay.value
            ? const SizedBox()
            : PLVideoPlayer(
                key: Key(heroTag),
                plPlayerController: plPlayerController!,
                videoIntroController:
                    videoDetailController.videoType == SearchType.video
                        ? videoIntroController
                        : null,
                bangumiIntroController:
                    videoDetailController.videoType == SearchType.media_bangumi
                        ? bangumiIntroController
                        : null,
                headerControl: HeaderControl(
                  controller: plPlayerController!,
                  videoDetailCtr: videoDetailController,
                  heroTag: heroTag,
                ),
                danmuWidget: pipNoDanmaku
                    ? null
                    : Obx(
                        () => PlDanmaku(
                          key: Key(videoDetailController.danmakuCid.value
                              .toString()),
                          isPipMode: true,
                          cid: videoDetailController.danmakuCid.value,
                          playerController: plPlayerController!,
                        ),
                      ),
                showEpisodes: showEpisodes,
                showViewPoints: showViewPoints,
              ),
      );

  Widget get manualPlayerWidget => Obx(
        () => Visibility(
          visible: videoDetailController.isShowCover.value,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppBar(
                  primary: false,
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  title: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        height: 34,
                        child: IconButton(
                          tooltip: '返回',
                          icon: const Icon(
                            FontAwesomeIcons.arrowLeft,
                            size: 15,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 1.5,
                                color: Colors.black,
                              ),
                            ],
                          ),
                          onPressed: Get.back,
                        ),
                      ),
                      SizedBox(
                        width: 42,
                        height: 34,
                        child: IconButton(
                          tooltip: '返回主页',
                          icon: const Icon(
                            FontAwesomeIcons.house,
                            size: 15,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 1.5,
                                color: Colors.black,
                              ),
                            ],
                          ),
                          onPressed: () {
                            videoDetailController.backToHome = true;
                            Get.until((route) => route.isFirst);
                          },
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 1.5,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      onSelected: (String type) async {
                        switch (type) {
                          case 'later':
                            var res = await UserHttp.toViewLater(
                                bvid: videoDetailController.bvid);
                            SmartDialog.showToast(res['msg']);
                            break;
                          case 'report':
                            if (videoDetailController.userInfo == null) {
                              SmartDialog.showToast('账号未登录');
                            } else {
                              Get.toNamed('/webview', parameters: {
                                'url':
                                    'https://www.bilibili.com/appeal/?avid=${IdUtils.bv2av(videoDetailController.bvid)}&bvid=${videoDetailController.bvid}'
                              });
                            }
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'later',
                          child: Text('稍后再看'),
                        ),
                        const PopupMenuItem<String>(
                          value: 'report',
                          child: Text('举报'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 10,
                child: IconButton(
                  tooltip: '播放',
                  onPressed: handlePlay,
                  icon: Image.asset(
                    'assets/images/play.png',
                    width: 60,
                    height: 60,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget get plPlayer => Obx(
        key: videoPlayerKey,
        () => videoDetailController.videoState.value is! Success
            ? const SizedBox.shrink()
            : !videoDetailController.autoPlay.value ||
                    plPlayerController?.videoController == null
                ? const SizedBox.shrink()
                : PLVideoPlayer(
                    key: Key(heroTag),
                    plPlayerController: plPlayerController!,
                    videoIntroController:
                        videoDetailController.videoType == SearchType.video
                            ? videoIntroController
                            : null,
                    bangumiIntroController: videoDetailController.videoType ==
                            SearchType.media_bangumi
                        ? bangumiIntroController
                        : null,
                    headerControl: videoDetailController.headerControl,
                    danmuWidget: Obx(
                      () => PlDanmaku(
                        key: Key(
                            videoDetailController.danmakuCid.value.toString()),
                        cid: videoDetailController.danmakuCid.value,
                        playerController: plPlayerController!,
                      ),
                    ),
                    showEpisodes: showEpisodes,
                    showViewPoints: showViewPoints,
                  ),
      );

  Widget autoChoose(Widget childWhenDisabled) {
    if (Platform.isAndroid) {
      return PiPSwitcher(
        getChildWhenDisabled: () => childWhenDisabled,
        getChildWhenEnabled: () => childWhenEnabled,
        floating: videoDetailController.floating,
      );
    }
    return childWhenDisabled;
  }

  @override
  Widget build(BuildContext context) {
    if (!horizontalScreen) {
      return autoChoose(childWhenDisabled);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // if (!isShowing) {
        //   return ColoredBox(color: Theme.of(context).colorScheme.surface);
        // }
        if (constraints.maxWidth > constraints.maxHeight * 1.25) {
//             hideStatusBar();
//             videoDetailController.hiddenReplyReplyPanel();
          return autoChoose(childWhenDisabledLandscape);
        } else if (constraints.maxWidth * (9 / 16) <
            (2 / 5) * constraints.maxHeight) {
          // if (!isFullScreen) {
          //   if (!removeSafeArea) showStatusBar();
          // }
          return autoChoose(childWhenDisabled);
        } else {
          // if (!isFullScreen) {
          //   if (!removeSafeArea) showStatusBar();
          // }
          return autoChoose(childWhenDisabledAlmostSquare);
        }
        //
        // final Orientation orientation =
        //     constraints.maxWidth > constraints.maxHeight * 1.25
        //         ? Orientation.landscape
        //         : Orientation.portrait;
        // if (orientation == Orientation.landscape) {
        //   if (!horizontalScreen) {
        //     hideStatusBar();
        //     videoDetailController.hiddenReplyReplyPanel();
        //   }
        // } else {
        //   if (!isFullScreen) {
        //     showStatusBar();
        //   }
        // }
        // if (Platform.isAndroid) {
        //   return PiPSwitcher(
        //     childWhenDisabled:
        //         !horizontalScreen || orientation == Orientation.portrait
        //             ? childWhenDisabled
        //             : childWhenDisabledLandscape,
        //     childWhenEnabled: childWhenEnabled,
        //     floating: floating,
        //   );
        // }
        // return !horizontalScreen || orientation == Orientation.portrait
        //     ? childWhenDisabled
        //     : childWhenDisabledLandscape;
      },
    );
  }

  Widget buildTabbar({
    bool needIndicator = true,
    String introText = '简介',
    bool showIntro = true,
    bool showReply = true,
    VoidCallback? onTap,
  }) {
    List<String> tabs = [
      if (showIntro) introText,
      if (showReply) '评论',
      if (_shouldShowSeasonPanel) '播放列表',
    ];
    if (videoDetailController.tabCtr.length != tabs.length) {
      videoDetailController.tabCtr = TabController(
        vsync: this,
        length: tabs.length,
        initialIndex:
            videoDetailController.tabCtr.index.clamp(0, tabs.length - 1),
      );
    }

    Widget tabbar() => TabBar(
          labelColor: needIndicator.not || tabs.length == 1
              ? Theme.of(context).colorScheme.onSurface
              : null,
          indicatorColor:
              needIndicator.not || tabs.length == 1 ? Colors.transparent : null,
          padding: EdgeInsets.zero,
          controller: videoDetailController.tabCtr,
          labelStyle: const TextStyle(fontSize: 13),
          labelPadding:
              const EdgeInsets.symmetric(horizontal: 10.0), // 设置每个标签的宽度
          dividerColor: Colors.transparent,
          onTap: (value) {
            void animToTop() {
              if (onTap != null) {
                onTap();
                return;
              }
              String text = tabs[value];
              if (text == '简介' || text == '相关视频') {
                _introController.animToTop();
              } else if (text.startsWith('评论')) {
                _videoReplyController.animateToTop();
              }
            }

            if (needIndicator.not || tabs.length == 1) {
              animToTop();
            } else if (videoDetailController.tabCtr.indexIsChanging.not) {
              animToTop();
            }
          },
          tabs: tabs.map((text) {
            if (text == '评论') {
              return Tab(
                text:
                    '评论${_videoReplyController.count.value == -1 ? '' : ' ${Utils.numFormat(_videoReplyController.count.value)}'}',
              );
            } else {
              return Tab(text: text);
            }
          }).toList(),
        );

    return Container(
      width: double.infinity,
      height: 45,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          if (tabs.isEmpty)
            const Spacer()
          else
            Flexible(
              flex: tabs.length == 3 ? 2 : 1,
              child: showReply ? Obx(() => tabbar()) : tabbar(),
            ),
          Flexible(
            flex: 1,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 32,
                    child: TextButton(
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                      ),
                      onPressed: videoDetailController.showShootDanmakuSheet,
                      child: Text(
                        '发弹幕',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: Obx(
                      () => IconButton(
                        onPressed: () {
                          videoDetailController
                                  .plPlayerController.isOpenDanmu.value =
                              !videoDetailController
                                  .plPlayerController.isOpenDanmu.value;
                          setting.put(
                              SettingBoxKey.enableShowDanmaku,
                              videoDetailController
                                  .plPlayerController.isOpenDanmu.value);
                        },
                        icon: SvgPicture.asset(
                          videoDetailController
                                  .plPlayerController.isOpenDanmu.value
                              ? 'assets/images/video/danmu_open.svg'
                              : 'assets/images/video/danmu_close.svg',
                          // ignore: deprecated_member_use
                          color: videoDetailController
                                  .plPlayerController.isOpenDanmu.value
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget videoPlayer(double videoWidth, double videoHeight) {
    return Stack(
      children: [
        if (isShowing) plPlayer,

        if (!videoDetailController.autoPlay.value) ...[
          Obx(
            () => videoDetailController.isShowCover.value
                ? Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: handlePlay,
                      child: Obx(
                        () => CachedNetworkImage(
                          imageUrl:
                              videoDetailController.videoItem['pic'] != null
                                  ? (videoDetailController.videoItem['pic']
                                          as String)
                                      .http2https
                                  : '',
                          width: videoWidth,
                          height: videoHeight,
                          fit: BoxFit.cover,
                          fadeOutDuration: const Duration(milliseconds: 120),
                          fadeInDuration: const Duration(milliseconds: 120),
                          memCacheWidth: videoWidth.cacheSize(context),
                          placeholder: (context, url) => Center(
                            child: Image.asset('assets/images/loading.png'),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          manualPlayerWidget,
        ],

        if (videoDetailController.enableSponsorBlock ||
            videoDetailController.continuePlayingPart)
          Positioned(
            left: 16,
            bottom: isFullScreen ? max(75, Get.height * 0.25) : 75,
            child: SizedBox(
              width: MediaQuery.textScalerOf(context).scale(120),
              child: AnimatedList(
                padding: EdgeInsets.zero,
                key: videoDetailController.listKey,
                reverse: true,
                shrinkWrap: true,
                initialItemCount: videoDetailController.listData.length,
                itemBuilder: (context, index, animation) {
                  return videoDetailController.buildItem(
                    videoDetailController.listData[index],
                    animation,
                  );
                },
              ),
            ),
          ),

        // for debug
        // Positioned(
        //   right: 16,
        //   bottom: 75,
        //   child: FilledButton.tonal(
        //     onPressed: () {
        //       videoDetailController.onAddItem(
        //         SegmentModel(
        //           UUID: '',
        //           segmentType: SegmentType.sponsor,
        //           segment: Pair(first: 0, second: 0),
        //           skipType: SkipType.alwaysSkip,
        //         ),
        //       );
        //     },
        //     child: Text('skip'),
        //   ),
        // ),
        // Positioned(
        //   right: 16,
        //   bottom: 120,
        //   child: FilledButton.tonal(
        //     onPressed: () {
        //       videoDetailController.onAddItem(2);
        //     },
        //     child: Text('index'),
        //   ),
        // ),

        Obx(
          () {
            if (videoDetailController.showSteinEdgeInfo.value) {
              try {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: plPlayerController?.showControls.value == true
                          ? 75
                          : 16,
                    ),
                    child: Wrap(
                      spacing: 25,
                      runSpacing: 10,
                      children: (videoDetailController.steinEdgeInfo!['edges']
                              ['questions'][0]['choices'] as List)
                          .map((item) {
                        return FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withOpacity(0.8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 10,
                            ),
                            visualDensity:
                                VisualDensity(horizontal: -2, vertical: -2),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            videoIntroController.changeSeasonOrbangu(
                              null,
                              videoDetailController.bvid,
                              item['cid'],
                              IdUtils.bv2av(videoDetailController.bvid),
                              null,
                              true,
                            );
                            videoDetailController.getSteinEdgeInfo(item['id']);
                          },
                          child: Text(item['option']),
                        );
                      }).toList(),
                    ),
                  ),
                );
              } catch (e) {
                debugPrint('build stein edges: $e');
                return const SizedBox.shrink();
              }
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget videoIntro([bool needRelated = true, bool needCtr = true]) {
    Widget introPanel() => Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            key: const PageStorageKey<String>('简介'),
            controller: needCtr ? _introController : null,
            physics: needCtr.not
                ? const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  )
                : null,
            slivers: [
              if (videoDetailController.videoType == SearchType.video) ...[
                VideoIntroPanel(
                  heroTag: heroTag,
                  showAiBottomSheet: showAiBottomSheet,
                  showIntroDetail: showIntroDetail,
                  showEpisodes: showEpisodes,
                  onShowMemberPage: onShowMemberPage,
                ),
                if (needRelated && videoDetailController.showRelatedVideo) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.only(top: StyleString.safeSpace),
                      child: Divider(
                        height: 1,
                        indent: 12,
                        endIndent: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.08),
                      ),
                    ),
                  ),
                  RelatedVideoPanel(
                      key: relatedVideoPanelKey, heroTag: heroTag),
                ] else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.paddingOf(context).bottom +
                          StyleString.safeSpace,
                    ),
                  ),
              ] else if (videoDetailController.videoType ==
                  SearchType.media_bangumi)
                Obx(
                  () => BangumiIntroPanel(
                    heroTag: heroTag,
                    cid: videoDetailController.cid.value,
                    showEpisodes: showEpisodes,
                    showIntroDetail: showIntroDetail,
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom +
                      (videoDetailController.isPlayAll &&
                              MediaQuery.orientationOf(context) ==
                                  Orientation.landscape
                          ? 75
                          : 0),
                ),
              )
            ],
          ),
        );
    if (videoDetailController.isPlayAll) {
      return Stack(
        children: [
          introPanel(),
          Positioned(
            left: 12,
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => videoDetailController.showMediaListPanel(context),
                borderRadius: const BorderRadius.all(Radius.circular(14)),
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withOpacity(0.95),
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_play, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        videoDetailController.watchLaterTitle,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.keyboard_arrow_up_rounded, size: 26),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return introPanel();
    }
  }

  Widget get seasonPanel => Column(
        children: [
          if ((videoIntroController.videoDetail.value.pages?.length ?? 0) > 1)
            if (videoIntroController.videoDetail.value.ugcSeason != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: PagesPanel(
                  heroTag: heroTag,
                  videoIntroController: videoIntroController,
                  bvid: videoIntroController.bvid,
                  changeFuc: videoIntroController.changeSeasonOrbangu,
                  showEpisodes: showEpisodes,
                ),
              )
            else
              Expanded(
                child: Obx(
                  () => ListSheetContent(
                    episodes: videoIntroController.videoDetail.value.pages,
                    bvid: videoDetailController.bvid,
                    aid: IdUtils.bv2av(videoDetailController.bvid),
                    currentCid: videoDetailController.cid.value,
                    isReversed:
                        videoIntroController.videoDetail.value.isPageReversed,
                    changeFucCall: videoDetailController.videoType ==
                            SearchType.media_bangumi
                        ? bangumiIntroController.changeSeasonOrbangu
                        : videoIntroController.changeSeasonOrbangu,
                    showTitle: false,
                    isSupportReverse: videoDetailController.videoType !=
                        SearchType.media_bangumi,
                    onReverse: () {
                      onReversePlay(
                        bvid: videoDetailController.bvid,
                        aid: IdUtils.bv2av(videoDetailController.bvid),
                        isSeason: false,
                      );
                    },
                  ),
                ),
              ),
          if (videoIntroController.videoDetail.value.ugcSeason != null) ...[
            if ((videoIntroController.videoDetail.value.pages?.length ?? 0) >
                1) ...[
              const SizedBox(height: 8),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SeasonPanel(
                heroTag: heroTag,
                onTap: false,
                ugcSeason: videoIntroController.videoDetail.value.ugcSeason!,
                changeFuc: videoIntroController.changeSeasonOrbangu,
                showEpisodes: showEpisodes,
                pages: videoIntroController.videoDetail.value.pages,
                videoIntroController: videoIntroController,
              ),
            ),
            Expanded(
              child: Obx(
                () => ListSheetContent(
                  index: videoDetailController.seasonIndex.value,
                  season: videoIntroController.videoDetail.value.ugcSeason,
                  bvid: videoDetailController.bvid,
                  aid: IdUtils.bv2av(videoDetailController.bvid),
                  currentCid: videoDetailController.seasonCid ?? 0,
                  isReversed:
                      videoIntroController.videoDetail.value.isSeasonReversed,
                  changeFucCall: videoDetailController.videoType ==
                          SearchType.media_bangumi
                      ? bangumiIntroController.changeSeasonOrbangu
                      : videoIntroController.changeSeasonOrbangu,
                  showTitle: false,
                  isSupportReverse: videoDetailController.videoType !=
                      SearchType.media_bangumi,
                  onReverse: () {
                    onReversePlay(
                      bvid: videoDetailController.bvid,
                      aid: IdUtils.bv2av(videoDetailController.bvid),
                      isSeason: true,
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      );

  Widget videoReplyPanel([bool needCtr = true]) => Obx(
        () => VideoReplyPanel(
          key: videoReplyPanelKey,
          needController: needCtr,
          bvid: videoDetailController.bvid,
          oid: videoDetailController.oid.value,
          heroTag: heroTag,
          replyReply: replyReply,
          onViewImage: videoDetailController.onViewImage,
          onDismissed: videoDetailController.onDismissed,
          callback: _horizontalPreview
              ? (imgList, index) {
                  final ctr = AnimationController(
                    vsync: this,
                    duration: const Duration(milliseconds: 200),
                  )..forward();
                  Utils.onHorizontalPreview(
                    videoDetailController.childKey,
                    AnimationController(
                      vsync: this,
                      duration: Duration.zero,
                    ),
                    ctr,
                    imgList,
                    index,
                    (value) async {
                      if (value == false) {
                        await ctr.reverse();
                      }
                      try {
                        ctr.dispose();
                      } catch (_) {}
                      if (value == false) {
                        Get.back();
                      }
                    },
                  );
                }
              : null,
        ),
      );

  // 展示二级回复
  void replyReply(replyItem, id, isTop) {
    EasyThrottle.throttle('replyReply', const Duration(milliseconds: 500), () {
      int oid = replyItem.oid.toInt();
      int rpid = GlobalData().grpcReply ? replyItem.id.toInt() : replyItem.rpid;
      videoDetailController.childKey.currentState?.showBottomSheet(
        backgroundColor: Colors.transparent,
        (context) => VideoReplyReplyPanel(
          id: id,
          oid: oid,
          rpid: rpid,
          firstFloor: replyItem,
          replyType: ReplyType.video,
          source: 'videoDetail',
          isTop: isTop ?? false,
          onViewImage: videoDetailController.onViewImage,
          onDismissed: videoDetailController.onDismissed,
        ),
      );
    });
  }

  // ai总结
  showAiBottomSheet() {
    videoDetailController.childKey.currentState?.showBottomSheet(
      enableDrag: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      (context) => AiDetail(modelResult: videoIntroController.modelResult),
    );
  }

  showIntroDetail(videoDetail, videoTags) {
    videoDetailController.childKey.currentState?.showBottomSheet(
      enableDrag: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      (context) => videoDetail is BangumiInfoModel
          ? bangumi.IntroDetail(
              bangumiDetail: videoDetail,
              videoTags: videoTags,
            )
          : video.IntroDetail(
              videoDetail: videoDetail,
              videoTags: videoTags,
            ),
    );
  }

  showEpisodes(index, season, episodes, bvid, aid, cid) {
    Widget listSheetContent() => ListSheetContent(
          index: index,
          season: season,
          bvid: bvid,
          aid: aid,
          currentCid: cid,
          episodes: episodes,
          isReversed:
              videoDetailController.videoType == SearchType.media_bangumi
                  ? null
                  : season != null
                      ? videoIntroController.videoDetail.value.isSeasonReversed
                      : videoIntroController.videoDetail.value.isPageReversed,
          isSupportReverse:
              videoDetailController.videoType != SearchType.media_bangumi,
          changeFucCall:
              videoDetailController.videoType == SearchType.media_bangumi
                  ? bangumiIntroController.changeSeasonOrbangu
                  : videoIntroController.changeSeasonOrbangu,
          onClose: Get.back,
          onReverse: () {
            Get.back();
            onReversePlay(
              bvid: bvid,
              aid: aid,
              isSeason: season != null,
            );
          },
        );
    if (isFullScreen) {
      Utils.showFSSheet(
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          child: listSheetContent(),
        ),
        isFullScreen: isFullScreen,
      );
    } else {
      videoDetailController.childKey.currentState?.showBottomSheet(
        backgroundColor: Theme.of(context).colorScheme.surface,
        (context) => listSheetContent(),
      );
    }
  }

  void onReversePlay({
    required dynamic bvid,
    required dynamic aid,
    required bool isSeason,
  }) {
    void changeEpisode(episode) {
      videoIntroController.changeSeasonOrbangu(
        episode is bangumi.EpisodeItem ? episode.epId : null,
        episode.runtimeType.toString() == "EpisodeItem" ? episode.bvid : bvid,
        episode.cid,
        episode.runtimeType.toString() == "EpisodeItem" ? episode.aid : aid,
        episode is video.EpisodeItem
            ? episode.arc?.pic
            : episode is bangumi.EpisodeItem
                ? episode.cover
                : null,
      );
    }

    if (isSeason) {
      // reverse season
      videoIntroController.videoDetail.value.isSeasonReversed =
          !videoIntroController.videoDetail.value.isSeasonReversed;
      videoIntroController.videoDetail.value.ugcSeason!
              .sections![videoDetailController.seasonIndex.value].episodes =
          videoIntroController
              .videoDetail
              .value
              .ugcSeason!
              .sections![videoDetailController.seasonIndex.value]
              .episodes!
              .reversed
              .toList();

      if (videoDetailController.reverseFromFirst.not) {
        // keep current episode
        videoDetailController.seasonIndex.refresh();
        videoDetailController.cid.refresh();
      } else {
        // switch to first episode
        dynamic episode = videoIntroController.videoDetail.value.ugcSeason!
            .sections![videoDetailController.seasonIndex.value].episodes!.first;
        if (episode.cid != videoDetailController.cid.value) {
          changeEpisode(episode);
        } else {
          videoDetailController.seasonIndex.refresh();
          videoDetailController.cid.refresh();
        }
      }
    } else {
      // reverse part
      videoIntroController.videoDetail.value.isPageReversed =
          !videoIntroController.videoDetail.value.isPageReversed;
      videoIntroController.videoDetail.value.pages =
          videoIntroController.videoDetail.value.pages!.reversed.toList();
      if (videoDetailController.reverseFromFirst.not) {
        // keep current episode
        videoDetailController.cid.refresh();
      } else {
        // switch to first episode
        dynamic episode = videoIntroController.videoDetail.value.pages!.first;
        if (episode.cid != videoDetailController.cid.value) {
          changeEpisode(episode);
        } else {
          videoDetailController.cid.refresh();
        }
      }
    }
  }

  void showViewPoints() {
    Widget listSheetContent() {
      int currentIndex = -1;
      return StatefulBuilder(
        builder: (context, setState) => Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: const Text('分段信息'),
            actions: [
              Text(
                '分段进度条',
                style: TextStyle(fontSize: 16),
              ),
              Obx(
                () => Transform.scale(
                  alignment: Alignment.centerLeft,
                  scale: 0.8,
                  child: Switch(
                    thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
                      if (states.isNotEmpty &&
                          states.first == WidgetState.selected) {
                        return const Icon(Icons.done);
                      }
                      return null;
                    }),
                    value:
                        videoDetailController.plPlayerController.showVP.value,
                    onChanged: (value) {
                      videoDetailController.plPlayerController.showVP.value =
                          value;
                    },
                  ),
                ),
              ),
              iconButton(
                context: context,
                size: 30,
                icon: Icons.clear,
                tooltip: '关闭',
                onPressed: Get.back,
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: SingleChildScrollView(
            controller: ScrollController(),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                ...List.generate(
                    videoDetailController.viewPointList.length * 2 - 1,
                    (rawIndex) {
                  if (rawIndex % 2 == 1) {
                    return Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    );
                  }
                  int index = rawIndex ~/ 2;
                  Segment segment = videoDetailController.viewPointList[index];
                  if (currentIndex == -1 &&
                      segment.from != null &&
                      segment.to != null) {
                    if (videoDetailController
                                .plPlayerController.positionSeconds.value >=
                            segment.from! &&
                        videoDetailController
                                .plPlayerController.positionSeconds.value <
                            segment.to!) {
                      currentIndex = index;
                    }
                  }
                  return ListTile(
                    dense: true,
                    onTap: segment.from != null
                        ? () {
                            currentIndex = index;
                            plPlayerController?.danmakuController?.clear();
                            plPlayerController?.videoPlayerController
                                ?.seek(Duration(seconds: segment.from!));
                            Get.back();
                          }
                        : null,
                    leading: segment.url?.isNotEmpty == true
                        ? Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: currentIndex == index
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      width: 1.8,
                                      strokeAlign:
                                          BorderSide.strokeAlignOutside,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  )
                                : null,
                            child: LayoutBuilder(
                              builder: (context, constraints) =>
                                  NetworkImgLayer(
                                radius: 6,
                                src: segment.url,
                                width: constraints.maxHeight *
                                    StyleString.aspectRatio,
                                height: constraints.maxHeight,
                              ),
                            ),
                          )
                        : null,
                    title: Text(
                      segment.title ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            currentIndex == index ? FontWeight.bold : null,
                        color: currentIndex == index
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      '${segment.from != null ? Utils.timeFormat(segment.from) : ''} - ${segment.to != null ? Utils.timeFormat(segment.to) : ''}',
                      style: TextStyle(
                        fontSize: 13,
                        color: currentIndex == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  );
                }),
                SizedBox(height: 25 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ),
      );
    }

    if (isFullScreen) {
      Utils.showFSSheet(child: listSheetContent(), isFullScreen: isFullScreen);
    } else {
      videoDetailController.childKey.currentState?.showBottomSheet(
        backgroundColor: Colors.transparent,
        (context) => GStorage.collapsibleVideoPage
            ? ViewPointsPage(
                child: listSheetContent(),
              )
            : listSheetContent(),
      );
    }
  }

  void _onPopInvokedWithResult(didPop, result) {
    if (plPlayerController?.controlsLock.value == true) {
      plPlayerController?.onLockControl(false);
      return;
    }
    if (isFullScreen) {
      plPlayerController!.triggerFullScreen(status: false);
    }
    if (MediaQuery.of(context).orientation == Orientation.landscape &&
        !horizontalScreen) {
      verticalScreenForTwoSeconds();
    }
  }

  void onShowMemberPage(mid) {
    videoDetailController.childKey.currentState?.showBottomSheet(
      backgroundColor: Theme.of(context).colorScheme.surface,
      (context) {
        return HorizontalMemberPage(
          mid: mid,
          videoDetailController: videoDetailController,
          videoIntroController: videoIntroController,
        );
      },
      enableDrag: true,
    );
  }
}

class ViewPointsPage extends StatefulWidget {
  const ViewPointsPage({super.key, required this.child});

  final Widget child;

  @override
  State<ViewPointsPage> createState() => _ViewPointsPageState();
}

class _ViewPointsPageState extends State<ViewPointsPage> {
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInit = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isInit
        ? CustomScrollView(
            physics: const NeverScrollableScrollPhysics(),
          )
        : widget.child;
  }
}
