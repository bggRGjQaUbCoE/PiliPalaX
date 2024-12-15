import 'dart:async';

import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/skeleton/video_card_h.dart';
import 'package:PiliPalaX/common/widgets/http_error.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';

import '../../models/user/sub_folder.dart';
import '../../utils/utils.dart';
import 'controller.dart';
import 'widget/sub_video_card.dart';

class SubDetailPage extends StatefulWidget {
  const SubDetailPage({super.key});

  @override
  State<SubDetailPage> createState() => _SubDetailPageState();
}

class _SubDetailPageState extends State<SubDetailPage> {
  late final ScrollController _controller = ScrollController();
  final SubDetailController _subDetailController =
      Get.put(SubDetailController());
  late StreamController<bool> titleStreamC; // a
  late Future _futureBuilderFuture;
  late String id;

  @override
  void initState() {
    super.initState();
    id = Get.parameters['id']!;
    _futureBuilderFuture = _subDetailController.queryUserSubFolderDetail();
    titleStreamC = StreamController<bool>();
    _controller.addListener(
      () {
        if (_controller.offset > 160) {
          titleStreamC.add(true);
        } else if (_controller.offset <= 160) {
          titleStreamC.add(false);
        }

        if (_controller.position.pixels >=
            _controller.position.maxScrollExtent - 200) {
          EasyThrottle.throttle('subDetail', const Duration(seconds: 1), () {
            _subDetailController.onLoad();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    titleStreamC.close();
    _controller.removeListener(() {});
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 260 - MediaQuery.of(context).padding.top,
            pinned: true,
            title: StreamBuilder(
              stream: titleStreamC.stream,
              initialData: false,
              builder: (context, AsyncSnapshot snapshot) {
                return AnimatedOpacity(
                  opacity: snapshot.data ? 1 : 0,
                  curve: Curves.easeOut,
                  duration: const Duration(milliseconds: 500),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _subDetailController.item.title!,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '共${_subDetailController.item.mediaCount!}条视频',
                            style: Theme.of(context).textTheme.labelMedium,
                          )
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          Theme.of(context).dividerColor.withOpacity(0.2),
                    ),
                  ),
                ),
                padding: EdgeInsets.only(
                    top: kTextTabBarHeight +
                        MediaQuery.of(context).padding.top +
                        30,
                    left: 20,
                    right: 20),
                child: SizedBox(
                  height: 200,
                  child: Row(
                    // mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Hero(
                        tag: _subDetailController.heroTag,
                        child: NetworkImgLayer(
                          width: 180,
                          height: 110,
                          src: _subDetailController.item.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              _subDetailController.item.title!,
                              style: TextStyle(
                                  fontSize: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .fontSize,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                SubFolderItemData item =
                                    _subDetailController.item;
                                Get.toNamed(
                                  '/member?mid=${item.upper!.mid}',
                                  arguments: {
                                    'face': item.upper!.face,
                                  },
                                );
                              },
                              child: Text(
                                _subDetailController.item.upper!.name!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Obx(
                              () => Text(
                                '${Utils.numFormat(_subDetailController.playCount.value)}次播放',
                                style: TextStyle(
                                    fontSize: Theme.of(context)
                                        .textTheme
                                        .labelSmall!
                                        .fontSize,
                                    color:
                                        Theme.of(context).colorScheme.outline),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 15, bottom: 8, left: 14),
              child: Obx(
                () => Text(
                  '共${_subDetailController.subList.length}条视频',
                  style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.labelMedium!.fontSize,
                      color: Theme.of(context).colorScheme.outline,
                      letterSpacing: 1),
                ),
              ),
            ),
          ),
          FutureBuilder(
            future: _futureBuilderFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                // TODO: refactor
                if (snapshot.data is! Map) {
                  return HttpError(
                    callback: () => setState(() {
                      _futureBuilderFuture =
                          _subDetailController.queryUserSubFolderDetail();
                    }),
                  );
                }
                Map data = snapshot.data;
                if (data['status']) {
                  if (_subDetailController.item.mediaCount == 0) {
                    return HttpError(
                      callback: () => setState(() {
                        _futureBuilderFuture =
                            _subDetailController.queryUserSubFolderDetail();
                      }),
                    );
                  } else {
                    List subList = _subDetailController.subList;
                    return Obx(
                      () => subList.isEmpty
                          ? const SliverToBoxAdapter(child: SizedBox())
                          : SliverList(
                              delegate:
                                  SliverChildBuilderDelegate((context, index) {
                                return SubVideoCardH(
                                  videoItem: subList[index],
                                );
                              }, childCount: subList.length),
                            ),
                    );
                  }
                } else {
                  return HttpError(
                    errMsg: data['msg'],
                    callback: () => setState(() {
                      _futureBuilderFuture =
                          _subDetailController.queryUserSubFolderDetail();
                    }),
                  );
                }
              } else {
                // 骨架屏
                return SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return const VideoCardHSkeleton();
                  }, childCount: 10),
                );
              }
            },
          ),
          SliverToBoxAdapter(
            child: Container(
              height: MediaQuery.of(context).padding.bottom + 60,
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom),
              child: Center(
                child: Obx(
                  () => Text(
                    _subDetailController.loadingText.value,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 13),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
