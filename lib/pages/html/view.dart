import 'dart:math';

import 'package:PiliPalaX/common/widgets/article_content.dart';
import 'package:PiliPalaX/common/widgets/http_error.dart';
import 'package:PiliPalaX/http/loading_state.dart';
import 'package:PiliPalaX/pages/video/detail/reply/widgets/reply_item.dart';
import 'package:PiliPalaX/pages/video/detail/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPalaX/utils/extension.dart';
import 'package:PiliPalaX/utils/global_data.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/skeleton/video_reply.dart';
import 'package:PiliPalaX/common/widgets/html_render.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/models/common/reply_type.dart';
import 'package:PiliPalaX/pages/video/detail/reply_reply/index.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/grid.dart';
import 'controller.dart';

class HtmlRenderPage extends StatefulWidget {
  const HtmlRenderPage({super.key});

  @override
  State<HtmlRenderPage> createState() => _HtmlRenderPageState();
}

class _HtmlRenderPageState extends State<HtmlRenderPage>
    with TickerProviderStateMixin {
  final HtmlRenderController _htmlRenderCtr = Get.put(HtmlRenderController());
  late String title;
  late String id;
  late String url;
  late String dynamicType;
  late int type;
  bool _isFabVisible = true;
  late AnimationController fabAnimationCtr;

  late final List<double> _ratio = GStorage.dynamicDetailRatio;

  @override
  void initState() {
    super.initState();
    title = Get.parameters['title']!;
    id = Get.parameters['id']!;
    url = Get.parameters['url']!;
    dynamicType = Get.parameters['dynamicType']!;
    type = dynamicType == 'picture' ? 11 : 12;
    fabAnimationCtr = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    fabAnimationCtr.forward();
    scrollListener();
  }

  @override
  void dispose() {
    fabAnimationCtr.dispose();
    _htmlRenderCtr.scrollController.removeListener(() {});
    super.dispose();
  }

  void scrollListener() {
    _htmlRenderCtr.scrollController.addListener(
      () {
        // 标题
        // if (scrollController.offset > 55 && !_visibleTitle) {
        //   _visibleTitle = true;
        //   titleStreamC.add(true);
        // } else if (scrollController.offset <= 55 && _visibleTitle) {
        //   _visibleTitle = false;
        //   titleStreamC.add(false);
        // }

        // fab按钮
        final ScrollDirection direction =
            _htmlRenderCtr.scrollController.position.userScrollDirection;
        if (direction == ScrollDirection.forward) {
          _showFab();
        } else if (direction == ScrollDirection.reverse) {
          _hideFab();
        }
      },
    );
  }

  void _showFab() {
    if (!_isFabVisible) {
      _isFabVisible = true;
      fabAnimationCtr.forward();
    }
  }

  void _hideFab() {
    if (_isFabVisible) {
      _isFabVisible = false;
      fabAnimationCtr.reverse();
    }
  }

  void replyReply(replyItem, id, isTop) {
    EasyThrottle.throttle('replyReply', const Duration(milliseconds: 500), () {
      int oid = replyItem.oid.toInt();
      int rpid = GlobalData().grpcReply ? replyItem.id.toInt() : replyItem.rpid;
      Get.to(
        () => Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: Text('评论详情'),
          ),
          body: VideoReplyReplyPanel(
            id: id,
            oid: oid,
            rpid: rpid,
            source: 'dynamic',
            replyType: ReplyType.values[type],
            firstFloor: replyItem,
            isTop: isTop ?? false,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(title),
        actions: [
          const SizedBox(width: 4),
          if (context.orientation == Orientation.landscape)
            IconButton(
              tooltip: '页面比例调节',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: EdgeInsets.only(
                        top: 56,
                        right: 16,
                      ),
                      width: context.width / 4,
                      height: 32,
                      child: Builder(
                        builder: (context) => Slider(
                          min: 1,
                          max: 100,
                          value: _ratio.first,
                          onChanged: (value) async {
                            if (value >= 10 && value <= 90) {
                              _ratio[0] = value;
                              _ratio[1] = 100 - value;
                              await GStorage.setting.put(
                                SettingBoxKey.dynamicDetailRatio,
                                _ratio,
                              );
                              (context as Element).markNeedsBuild();
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
              icon: Transform.rotate(
                angle: pi / 2,
                child: Icon(Icons.splitscreen),
              ),
            ),
          IconButton(
            tooltip: '用内置浏览器打开',
            onPressed: () {
              Get.toNamed('/webviewnew', parameters: {
                'url': url.startsWith('http') ? url : 'https:$url',
                'type': 'url',
                'pageTitle': title,
              });
            },
            icon: const Icon(Icons.open_in_browser_outlined, size: 19),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) => <PopupMenuEntry>[
              PopupMenuItem(
                onTap: () => {
                  _htmlRenderCtr.reqHtml(),
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: 19),
                    SizedBox(width: 10),
                    Text('刷新'),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => {
                  Get.toNamed('/webviewnew', parameters: {
                    'url': url.startsWith('http') ? url : 'https:$url',
                    'type': 'url',
                    'pageTitle': title,
                  }),
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new, size: 19),
                    SizedBox(width: 10),
                    Text('内置浏览器打开'),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => {
                  Clipboard.setData(ClipboardData(text: url)),
                  SmartDialog.showToast('已复制'),
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, size: 19),
                    SizedBox(width: 10),
                    Text('复制链接'),
                  ],
                ),
              ),
              PopupMenuItem(
                onTap: () => Share.share(url),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share_outlined, size: 19),
                    SizedBox(width: 10),
                    Text('分享'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6)
        ],
      ),
      body: Stack(
        children: [
          OrientationBuilder(
            builder: (context, orientation) {
              double padding = max(context.width / 2 - Grid.maxRowWidth, 0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: _ratio[0].toInt(),
                    child: CustomScrollView(
                      controller: orientation == Orientation.portrait
                          ? _htmlRenderCtr.scrollController
                          : ScrollController(),
                      slivers: [
                        SliverPadding(
                          padding: orientation == Orientation.portrait
                              ? EdgeInsets.symmetric(horizontal: padding)
                              : EdgeInsets.only(left: padding / 4),
                          sliver: SliverToBoxAdapter(
                            child: Obx(
                              () => _htmlRenderCtr.loaded.value
                                  ? _buildHeader
                                  : const SizedBox(),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: orientation == Orientation.portrait
                              ? EdgeInsets.symmetric(horizontal: padding)
                              : EdgeInsets.only(left: padding / 4),
                          sliver: _buildContent,
                        ),
                        if (orientation == Orientation.portrait) ...[
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: padding),
                            sliver: SliverToBoxAdapter(
                              child: Divider(
                                thickness: 8,
                                color: Theme.of(context)
                                    .dividerColor
                                    .withOpacity(0.05),
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: padding),
                            sliver: SliverToBoxAdapter(child: replyHeader()),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: padding),
                            sliver: Obx(
                              () =>
                                  replyList(_htmlRenderCtr.loadingState.value),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (orientation == Orientation.landscape) ...[
                    VerticalDivider(
                        thickness: 8,
                        color: Theme.of(context)
                            .dividerColor
                            .withOpacity(0.05)),
                    Expanded(
                      flex: _ratio[1].toInt(),
                      child: CustomScrollView(
                        controller: _htmlRenderCtr.scrollController,
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.only(right: padding / 4),
                            sliver: SliverToBoxAdapter(
                              child: replyHeader(),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.only(right: padding / 4),
                            sliver: Obx(
                              () =>
                                  replyList(_htmlRenderCtr.loadingState.value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 14,
            right: 14,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 2),
                end: const Offset(0, 0),
              ).animate(CurvedAnimation(
                parent: fabAnimationCtr,
                curve: Curves.easeInOut,
              )),
              child: FloatingActionButton(
                heroTag: null,
                onPressed: () {
                  feedBack();
                  _htmlRenderCtr.onReply(
                    context,
                    oid: _htmlRenderCtr.oid.value,
                    replyType: ReplyType.values[type],
                  );
                },
                tooltip: '评论动态',
                child: const Icon(Icons.reply),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget replyList(LoadingState loadingState) {
    return switch (loadingState) {
      Loading() => SliverList.builder(
          itemCount: 5,
          itemBuilder: (context, index) {
            return const VideoReplySkeleton();
          },
        ),
      Success() => (loadingState.response.replies as List?)?.isNotEmpty == true
          ? SliverList.builder(
              itemCount: loadingState.response.replies.length + 1,
              itemBuilder: (context, index) {
                if (index == loadingState.response.replies.length) {
                  _htmlRenderCtr.onLoadMore();
                  return Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).padding.bottom),
                    height: MediaQuery.of(context).padding.bottom + 100,
                    child: Text(
                      _htmlRenderCtr.isEnd.not
                          ? '加载中...'
                          : loadingState.response.replies.isEmpty
                              ? '还没有评论'
                              : '没有更多了',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  );
                } else {
                  return GlobalData().grpcReply
                      ? ReplyItemGrpc(
                          replyItem: loadingState.response.replies[index],
                          showReplyRow: true,
                          replyLevel: '1',
                          replyReply: replyReply,
                          replyType: ReplyType.values[type],
                          onReply: () {
                            _htmlRenderCtr.onReply(
                              context,
                              replyItem: loadingState.response.replies[index],
                              index: index,
                            );
                          },
                          onDelete: _htmlRenderCtr.onMDelete,
                          isTop: _htmlRenderCtr.hasUpTop && index == 0,
                          upMid: loadingState.response.subjectControl.upMid,
                        )
                      : ReplyItem(
                          replyItem: loadingState.response.replies[index],
                          showReplyRow: true,
                          replyLevel: '1',
                          replyReply: replyReply,
                          replyType: ReplyType.values[type],
                          onReply: () {
                            _htmlRenderCtr.onReply(
                              context,
                              replyItem: loadingState.response.replies[index],
                              index: index,
                            );
                          },
                          onDelete: _htmlRenderCtr.onMDelete,
                        );
                }
              },
            )
          : HttpError(
              callback: _htmlRenderCtr.onReload,
            ),
      Error() => HttpError(
          errMsg: loadingState.errMsg,
          callback: _htmlRenderCtr.onReload,
        ),
      LoadingState() => throw UnimplementedError(),
    };
  }

  Container replyHeader() {
    return Container(
      height: 45,
      padding: const EdgeInsets.only(left: 12, right: 6),
      child: Row(
        children: [
          const Text('回复'),
          const Spacer(),
          SizedBox(
            height: 35,
            child: TextButton.icon(
              onPressed: () => _htmlRenderCtr.queryBySort(),
              icon: const Icon(Icons.sort, size: 16),
              label: Obx(
                () => Text(
                  _htmlRenderCtr.sortTypeLabel.value,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget get _buildHeader => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(
          children: [
            NetworkImgLayer(
              width: 40,
              height: 40,
              type: 'avatar',
              src: _htmlRenderCtr.response['avatar']!,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_htmlRenderCtr.response['uname'],
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.titleSmall!.fontSize,
                    )),
                Text(
                  _htmlRenderCtr.response['updateTime'],
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: Theme.of(context).textTheme.labelSmall!.fontSize,
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      );

  Widget get _buildContent => SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        sliver: Obx(
          () => _htmlRenderCtr.loaded.value
              ? _htmlRenderCtr.response['isJsonContent'] == true
                  ? articleContent(
                      context: context,
                      list: _htmlRenderCtr.response['content'],
                    )
                  : SliverToBoxAdapter(
                      child: LayoutBuilder(
                        builder: (context, constraints) => htmlRender(
                          context: context,
                          htmlContent: _htmlRenderCtr.response['content'],
                          constrainedWidth: constraints.maxWidth,
                        ),
                      ),
                    )
              : SliverToBoxAdapter(
                  child: const SizedBox(),
                ),
        ),
      );
}
