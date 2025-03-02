import 'package:PiliPlus/common/widgets/custom_sliver_persistent_header_delegate.dart';
import 'package:PiliPlus/common/widgets/loading_widget.dart';
import 'package:PiliPlus/common/widgets/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/http_error.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/reply_sort_type.dart';
import 'package:PiliPlus/pages/video/detail/reply/widgets/reply_item.dart';
import 'package:PiliPlus/pages/video/detail/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/common/skeleton/video_reply.dart';
import 'package:PiliPlus/models/common/reply_type.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'controller.dart';

class VideoReplyPanel extends StatefulWidget {
  final String? bvid;
  final int oid;
  final int rpid;
  final String? replyLevel;
  final String heroTag;
  final Function replyReply;
  final VoidCallback? onViewImage;
  final ValueChanged<int>? onDismissed;
  final Function(List<String>, int)? callback;
  final bool? needController;

  const VideoReplyPanel({
    super.key,
    this.bvid,
    required this.oid,
    this.rpid = 0,
    this.replyLevel,
    required this.heroTag,
    required this.replyReply,
    this.onViewImage,
    this.onDismissed,
    this.callback,
    this.needController,
  });

  @override
  State<VideoReplyPanel> createState() => _VideoReplyPanelState();
}

class _VideoReplyPanelState extends State<VideoReplyPanel>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late VideoReplyController _videoReplyController;

  String replyLevel = '1';
  late String heroTag;

  // 添加页面缓存
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // int oid = widget.bvid != null ? IdUtils.bv2av(widget.bvid!) : 0;
    // heroTag = Get.arguments['heroTag'];
    heroTag = widget.heroTag;
    replyLevel = widget.replyLevel ?? '1';
    _videoReplyController = Get.find<VideoReplyController>(tag: heroTag);

    if (widget.needController != false) {
      _videoReplyController.scrollController.addListener(listener);
      _videoReplyController.fabAnimationCtr.forward();
    }
  }

  @override
  void didUpdateWidget(VideoReplyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (GStorage.collapsibleVideoPage) {
      _videoReplyController.showFab();
      if (widget.needController != false) {
        _videoReplyController.scrollController.addListener(listener);
      } else {
        _videoReplyController.scrollController.removeListener(listener);
      }
    }
  }

  @override
  void dispose() {
    if (widget.needController != false) {
      _videoReplyController.scrollController.removeListener(listener);
    }
    super.dispose();
  }

  void listener() {
    final ScrollDirection direction =
        _videoReplyController.scrollController.position.userScrollDirection;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return refreshIndicator(
      onRefresh: () async {
        await _videoReplyController.onRefresh();
      },
      child: widget.needController == false
          ? _buildPage
          : Stack(
              children: [
                _buildPage,
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 14,
                  right: 14,
                  child: SlideTransition(
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
              ],
            ),
    );
  }

  Widget get _buildPage => CustomScrollView(
        controller: widget.needController == false
            ? null
            : _videoReplyController.scrollController,
        physics: widget.needController == false
            ? const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              )
            : const AlwaysScrollableScrollPhysics(),
        key: const PageStorageKey<String>('评论'),
        slivers: <Widget>[
          SliverPersistentHeader(
            pinned: false,
            floating: true,
            delegate: CustomSliverPersistentHeaderDelegate(
              extent: 40,
              bgColor: Theme.of(context).colorScheme.surface,
              child: Container(
                height: 40,
                padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Obx(
                      () => Text(
                        _videoReplyController.sortType.value.title,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    SizedBox(
                      height: 35,
                      child: TextButton.icon(
                        onPressed: () => _videoReplyController.queryBySort(),
                        icon: Icon(
                          Icons.sort,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        label: Obx(
                          () => Text(
                            _videoReplyController.sortType.value.label,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          Obx(() => _buildBody(_videoReplyController.loadingState.value)),
        ],
      );

  Widget _buildBody(LoadingState loadingState) {
    return switch (loadingState) {
      Loading() => SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, index) {
              return const VideoReplySkeleton();
            },
            childCount: 5,
          ),
        ),
      Success() => (loadingState.response.replies as List?)?.isNotEmpty == true
          ? SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, index) {
                  double bottom = MediaQuery.of(context).padding.bottom;
                  if (index == loadingState.response.replies.length) {
                    _videoReplyController.onLoadMore();
                    return Container(
                      alignment: Alignment.center,
                      padding: EdgeInsets.only(bottom: bottom),
                      height: bottom + 100,
                      child: Text(
                        _videoReplyController.isEnd.not
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
                            replyLevel: replyLevel,
                            replyReply: widget.replyReply,
                            replyType: ReplyType.video,
                            onReply: () {
                              _videoReplyController.onReply(
                                context,
                                replyItem: loadingState.response.replies[index],
                                index: index,
                              );
                            },
                            onDelete: _videoReplyController.onMDelete,
                            isTop: _videoReplyController.hasUpTop && index == 0,
                            upMid: loadingState.response.subjectControl.upMid,
                            getTag: () => heroTag,
                            onViewImage: widget.onViewImage,
                            onDismissed: widget.onDismissed,
                            callback: widget.callback,
                          )
                        : ReplyItem(
                            replyItem: loadingState.response.replies[index],
                            showReplyRow: true,
                            replyLevel: replyLevel,
                            replyReply: widget.replyReply,
                            replyType: ReplyType.video,
                            onReply: () {
                              _videoReplyController.onReply(
                                context,
                                replyItem: loadingState.response.replies[index],
                                index: index,
                              );
                            },
                            onDelete: _videoReplyController.onMDelete,
                            onViewImage: widget.onViewImage,
                            onDismissed: widget.onDismissed,
                            getTag: () => heroTag,
                            callback: widget.callback,
                          );
                  }
                },
                childCount: loadingState.response.replies.length + 1,
              ),
            )
          : HttpError(
              errMsg: '还没有评论',
              callback: _videoReplyController.onReload,
            ),
      Error() => replyErrorWidget(
          context,
          true,
          loadingState.errMsg,
          _videoReplyController.onReload,
        ),
      LoadingState() => throw UnimplementedError(),
    };
  }
}
