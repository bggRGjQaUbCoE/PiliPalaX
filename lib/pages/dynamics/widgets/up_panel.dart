import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/models/dynamics/up.dart';
import 'package:PiliPalaX/models/live/item.dart';
import 'package:PiliPalaX/pages/dynamics/controller.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:PiliPalaX/utils/utils.dart';

class UpPanel extends StatefulWidget {
  final FollowUpModel? upData;
  final ScrollController scrollController;
  const UpPanel(this.upData, this.scrollController, {super.key});

  @override
  State<UpPanel> createState() => _UpPanelState();
}

class _UpPanelState extends State<UpPanel> {
  int currentMid = -1;
  List<UpItem> upList = [];
  List<LiveUserItem> liveList = [];
  Box userInfoCache = GStorage.userInfo;
  dynamic userInfo;
  bool _showLiveItems = false;
  late DynamicsController dynamicsController;

  @override
  void initState() {
    super.initState();
    userInfo = userInfoCache.get('userInfoCache');
    dynamicsController = Get.find<DynamicsController>();
  }

  @override
  Widget build(BuildContext context) {
    upList = widget.upData!.upList!;
    liveList = widget.upData!.liveUsers?.items ?? [];
    // return const SizedBox();
    return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: widget.scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 45,
              child: TextButton(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(const EdgeInsets.only()),
                ),
                child: Column(
                  children: [
                    const Spacer(),
                    const SizedBox(height: 12),
                    Text(
                      'Live(${liveList.length})',
                      style: const TextStyle(
                        fontSize: 13,
                      ),
                      semanticsLabel:
                          '${_showLiveItems ? '展开' : '收起'}直播中的${liveList.length}个Up',
                    ),
                    Icon(_showLiveItems ? Icons.expand_less : Icons.expand_more,
                        size: 12),
                    const Spacer(),
                  ],
                ),
                onPressed: () {
                  setState(() {
                    _showLiveItems = !_showLiveItems;
                  });
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 10,
            ),
          ),
          SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisExtent: 76,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              delegate: SliverChildListDelegate(
                [
                  if (_showLiveItems && liveList.isNotEmpty) ...[
                    for (int i = 0; i < liveList.length; i++) ...[
                      upItemBuild(liveList[i], i)
                    ],
                  ],
                  upItemBuild(UpItem(face: '', uname: '全部动态', mid: -1), 0),
                  upItemBuild(
                      UpItem(
                        face: userInfo.face,
                        uname: '我',
                        mid: userInfo.mid,
                      ),
                      1),
                  for (int i = 0; i < upList.length; i++) ...[
                    upItemBuild(upList[i], i + 2)
                  ],
                ],
              )),
          const SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
            ),
          ),
        ]);
  }

  Widget upItemBuild(data, i) {
    bool isCurrent = currentMid == data.mid || currentMid == -1;
    return InkWell(
      onTap: () {
        feedBack();
        if (data.type == 'up') {
          currentMid = data.mid;
          // dynamicsController.mid.value = data.mid;
          dynamicsController.upInfo.value = data;
          dynamicsController.onSelectUp(data.mid);
          // int liveLen = liveList.length;
          // int upLen = upList.length;
          // double itemWidth = contentWidth + itemPadding.horizontal;
          // double screenWidth = MediaQuery.sizeOf(context).width;
          // double moveDistance = 0.0;
          // if (itemWidth * (upList.length + liveList.length) <= screenWidth) {
          // } else if ((upLen - i - 0.5) * itemWidth > screenWidth / 2) {
          //   moveDistance =
          //       (i + liveLen + 0.5) * itemWidth + 46 - screenWidth / 2;
          // } else {
          //   moveDistance = (upLen + liveLen) * itemWidth + 46 - screenWidth;
          // }
          data.hasUpdate = false;
          // scrollController.animateTo(
          //   moveDistance,
          //   duration: const Duration(milliseconds: 500),
          //   curve: Curves.easeInOut,
          // );
          setState(() {});
        } else if (data.type == 'live') {
          LiveItemModel liveItem = LiveItemModel.fromJson({
            'title': data.title,
            'uname': data.uname,
            'face': data.face,
            'roomid': data.roomId,
          });
          Get.toNamed(
            '/liveRoom?roomid=${data.roomId}',
            arguments: {'liveItem': liveItem},
          );
        }
      },
      onLongPress: () {
        feedBack();
        if (data.mid == -1) {
          return;
        }
        String heroTag = Utils.makeHeroTag(data.mid);
        Get.toNamed('/member?mid=${data.mid}',
            arguments: {'face': data.face, 'heroTag': heroTag});
      },
      child: AnimatedOpacity(
        opacity: isCurrent ? 1 : 0.6,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              smallSize: 8,
              label: data.type == 'live' ? const Text('Live') : null,
              textColor: Theme.of(context).colorScheme.onSecondaryContainer,
              alignment: data.type == 'live'
                  ? AlignmentDirectional.topCenter
                  : AlignmentDirectional.topEnd,
              padding: const EdgeInsets.only(left: 6, right: 6),
              isLabelVisible: data.type == 'live' ||
                  (data.type == 'up' && (data.hasUpdate ?? false)),
              backgroundColor: data.type == 'live'
                  ? Theme.of(context)
                      .colorScheme
                      .secondaryContainer
                      .withOpacity(0.7)
                  : Theme.of(context).colorScheme.primary,
              child: data.face != ''
                  ? NetworkImgLayer(
                      width: 38,
                      height: 38,
                      src: data.face,
                      type: 'avatar',
                    )
                  : const CircleAvatar(
                      radius: 19,
                      backgroundImage: AssetImage(
                        'assets/images/logo/logo_android_2.png',
                      ),
                    ),
            ),
            const SizedBox(height: 3),
            Text(
              data.uname,
              overflow: TextOverflow.clip,
              maxLines: 2,
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: currentMid == data.mid
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  height: 1.1,
                  fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

// class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
//   _SliverHeaderDelegate({required this.height, required this.child});

//   final double height;
//   final Widget child;

//   @override
//   Widget build(
//       BuildContext context, double shrinkOffset, bool overlapsContent) {
//     return child;
//   }

//   @override
//   double get maxExtent => height;

//   @override
//   double get minExtent => height;

//   @override
//   bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
//       true;
// }

class UpPanelSkeleton extends StatelessWidget {
  const UpPanelSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onInverseSurface,
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 45,
          height: 12,
          color: Theme.of(context).colorScheme.onInverseSurface,
        ),
      ],
    );
  }
}
