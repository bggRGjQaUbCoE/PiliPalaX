import 'dart:async';

import 'package:PiliPalaX/common/constants.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/http/video.dart';
import 'package:PiliPalaX/models/bangumi/info.dart' as bangumi;
import 'package:PiliPalaX/models/video_detail_res.dart' as video;
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../utils/storage.dart';
import '../../utils/utils.dart';

class ListSheetContent extends StatefulWidget {
  const ListSheetContent({
    super.key,
    this.index,
    this.season,
    required this.episodes,
    this.bvid,
    this.aid,
    required this.currentCid,
    required this.changeFucCall,
    required this.onClose,
  });

  final dynamic index;
  final dynamic season;
  final dynamic episodes;
  final String? bvid;
  final int? aid;
  final int currentCid;
  final Function changeFucCall;
  final VoidCallback onClose;

  @override
  State<ListSheetContent> createState() => _ListSheetContentState();
}

class _ListSheetContentState extends State<ListSheetContent>
    with TickerProviderStateMixin {
  late List<ItemScrollController> itemScrollController = [];
  late final int currentIndex =
      widget.episodes!.indexWhere((dynamic e) => e.cid == widget.currentCid) ??
          0;
  late List<bool> reverse;

  int get _index => widget.index ?? 0;
  bool get _isList =>
      widget.season != null &&
      widget.season?.sections is List &&
      widget.season.sections.length > 1;
  TabController? _ctr;
  StreamController? _indexStream;
  int? _seasonFav;
  StreamController? _favStream;

  @override
  void initState() {
    super.initState();
    if (_isList) {
      _indexStream = StreamController<int>();
      _ctr = TabController(
        vsync: this,
        length: widget.season.sections.length,
        initialIndex: _index,
      )..addListener(() {
          _indexStream?.add(_ctr?.index);
        });
    }
    itemScrollController = _isList
        ? List.generate(
            widget.season.sections.length, (_) => ItemScrollController())
        : [ItemScrollController()];
    reverse = _isList
        ? List.generate(widget.season.sections.length, (_) => false)
        : [false];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      itemScrollController[_index].jumpTo(index: currentIndex);
    });
    if (widget.bvid != null && widget.season != null) {
      _favStream = StreamController<int>();
      () async {
        dynamic result = await VideoHttp.videoRelation(bvid: widget.bvid);
        if (result['status']) {
          _seasonFav = result['data']['season_fav'] ? 1 : 0;
          _favStream?.add(_seasonFav);
        }
      }();
    }
  }

  @override
  void dispose() {
    _favStream?.close();
    _indexStream?.close();
    _ctr?.removeListener(() {});
    _ctr?.dispose();
    super.dispose();
  }

  Widget buildEpisodeListItem(
    dynamic episode,
    int index,
    int length,
    bool isCurrentIndex,
  ) {
    Color primary = Theme.of(context).colorScheme.primary;
    late String title;
    if (episode.runtimeType.toString() == "EpisodeItem") {
      if (episode.longTitle != null && episode.longTitle != "") {
        dynamic leading = episode.title ?? index + 1;
        title =
            "${Utils.isStringNumeric(leading) ? '第$leading话' : leading}  ${episode.longTitle!}";
      } else {
        title = episode.title!;
      }
    } else if (episode.runtimeType.toString() == "PageItem") {
      title = episode.pagePart!;
    } else if (episode.runtimeType.toString() == "Part") {
      title = episode.pagePart!;
      // debugPrint("未知类型：${episode.runtimeType}");
    }
    return ListTile(
      onTap: () {
        if (episode.badge != null && episode.badge == "会员") {
          dynamic userInfo = GStorage.userInfo.get('userInfoCache');
          int vipStatus = 0;
          if (userInfo != null) {
            vipStatus = userInfo.vipStatus;
          }
          if (vipStatus != 1) {
            SmartDialog.showToast('需要大会员');
            // return;
          }
        }
        SmartDialog.showToast('切换到：$title');
        widget.onClose();
        widget.changeFucCall(
          episode is bangumi.EpisodeItem ? episode.epId : null,
          episode.runtimeType.toString() == "EpisodeItem"
              ? episode.bvid
              : widget.bvid,
          episode.cid,
          episode.runtimeType.toString() == "EpisodeItem"
              ? episode.aid
              : widget.aid,
          episode is video.EpisodeItem
              ? episode.arc?.pic
              : episode is bangumi.EpisodeItem
                  ? episode.cover
                  : null,
        );
      },
      dense: false,
      leading: (episode is video.EpisodeItem && episode.arc?.pic != null) ||
              (episode is video.Part && episode.firstFrame != null) ||
              (episode is bangumi.EpisodeItem && episode.cover != null)
          ? Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: isCurrentIndex
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        width: 1.8,
                        strokeAlign: BorderSide.strokeAlignOutside,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : null,
              child: LayoutBuilder(
                builder: (context, constraints) => NetworkImgLayer(
                  radius: 6,
                  src: episode is video.EpisodeItem
                      ? episode.arc?.pic
                      : episode is bangumi.EpisodeItem
                          ? episode.cover
                          : episode.firstFrame,
                  width: constraints.maxHeight * StyleString.aspectRatio,
                  height: constraints.maxHeight,
                ),
              ),
            )
          : isCurrentIndex
              ? Image.asset(
                  'assets/images/live.png',
                  color: primary,
                  height: 12,
                  semanticLabel: "正在播放：",
                )
              : null,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isCurrentIndex ? FontWeight.bold : null,
          color: isCurrentIndex
              ? primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (episode.badge != null) ...[
            if (episode.badge == '会员')
              Image.asset(
                'assets/images/big-vip.png',
                height: 20,
                semanticLabel: "大会员",
              )
            else
              Text(episode.badge),
            const SizedBox(width: 10),
          ],
          if (episode is! bangumi.EpisodeItem) Text('${index + 1}/$length'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Utils.getSheetHeight(context),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Container(
            height: 45,
            padding: const EdgeInsets.only(left: 14, right: 14),
            child: Row(
              children: [
                Text(
                  '合集（${_isList ? widget.season.epCount : widget.episodes!.length}）',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                StreamBuilder(
                  stream: _favStream?.stream,
                  builder: (context, snapshot) => snapshot.hasData
                      ? _mediumButton(
                          tooltip: _seasonFav == 1 ? '取消订阅' : '订阅',
                          icon: _seasonFav == 1
                              ? Icons.notifications_off_outlined
                              : Icons.notifications_active_outlined,
                          onPressed: () async {
                            dynamic result = await VideoHttp.seasonFav(
                              isFav: _seasonFav == 1,
                              seasonId: widget.season.id,
                            );
                            if (result['status']) {
                              SmartDialog.showToast(
                                  '${_seasonFav == 1 ? '取消' : ''}订阅成功');
                              _seasonFav = _seasonFav == 1 ? 0 : 1;
                              _favStream?.add(_seasonFav);
                            } else {
                              SmartDialog.showToast(result['msg']);
                            }
                          },
                        )
                      : const SizedBox.shrink(),
                ),
                _mediumButton(
                  tooltip: '跳至顶部',
                  icon: Icons.vertical_align_top,
                  onPressed: () {
                    itemScrollController[_ctr?.index ?? 0].scrollTo(
                      index: !reverse[_ctr?.index ?? 0]
                          ? 0
                          : _isList
                              ? widget.season.sections[_ctr?.index].episodes
                                      .length -
                                  1
                              : widget.episodes.length - 1,
                      duration: const Duration(milliseconds: 200),
                    );
                  },
                ),
                _mediumButton(
                  tooltip: '跳至底部',
                  icon: Icons.vertical_align_bottom,
                  onPressed: () {
                    itemScrollController[_ctr?.index ?? 0].scrollTo(
                      index: !reverse[_ctr?.index ?? 0]
                          ? _isList
                              ? widget.season.sections[_ctr?.index].episodes
                                      .length -
                                  1
                              : widget.episodes.length - 1
                          : 0,
                      duration: const Duration(milliseconds: 200),
                    );
                  },
                ),
                _mediumButton(
                  tooltip: '跳至当前',
                  icon: Icons.my_location,
                  onPressed: () async {
                    if (_ctr != null && _ctr?.index != (_index)) {
                      _ctr?.animateTo(_index);
                      await Future.delayed(const Duration(milliseconds: 225));
                    }
                    itemScrollController[_ctr?.index ?? 0].scrollTo(
                      index: currentIndex,
                      duration: const Duration(milliseconds: 200),
                    );
                  },
                ),
                const Spacer(),
                StreamBuilder(
                  stream: _indexStream?.stream,
                  initialData: 0,
                  builder: (context, snapshot) => _mediumButton(
                    tooltip: reverse[snapshot.data] ? '正序' : '反序',
                    icon: !reverse[snapshot.data]
                        ? MdiIcons.sortAscending
                        : MdiIcons.sortDescending,
                    onPressed: () {
                      setState(() {
                        reverse[_ctr?.index ?? 0] = !reverse[_ctr?.index ?? 0];
                      });
                    },
                  ),
                ),
                _mediumButton(
                  tooltip: '关闭',
                  icon: Icons.close,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
          if (_isList)
            Material(
              child: TabBar(
                controller: _ctr,
                padding: const EdgeInsets.only(right: 60),
                isScrollable: true,
                tabs: (widget.season.sections as List)
                    .map((item) => Tab(text: item.title))
                    .toList(),
                dividerHeight: 1,
                dividerColor:
                    Theme.of(context).dividerColor.withOpacity(0.1),
              ),
            ),
          Expanded(
            child: _isList
                ? TabBarView(
                    controller: _ctr,
                    children: List.generate(
                      widget.season.sections.length,
                      (index) => _buildBody(
                          index, widget.season.sections[index].episodes),
                    ),
                  )
                : _buildBody(null, widget.episodes),
          ),
        ],
      ),
    );
  }

  Widget _mediumButton({
    String? tooltip,
    IconData? icon,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon),
        style: ButtonStyle(
          padding: WidgetStateProperty.all(EdgeInsets.zero),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildBody(i, episodes) => Material(
        child: ScrollablePositionedList.separated(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          reverse: reverse[i ?? 0],
          itemCount: episodes.length,
          itemBuilder: (BuildContext context, int index) {
            return buildEpisodeListItem(
              episodes[index],
              index,
              episodes.length,
              i != null
                  ? i == (_index)
                      ? currentIndex == index
                      : false
                  : currentIndex == index,
            );
          },
          itemScrollController: itemScrollController[i ?? 0],
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withOpacity(0.1),
          ),
        ),
      );
}
