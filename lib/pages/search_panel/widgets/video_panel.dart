import 'package:PiliPalaX/common/widgets/http_error.dart';
import 'package:PiliPalaX/common/widgets/loading_widget.dart';
import 'package:PiliPalaX/http/loading_state.dart';
import 'package:PiliPalaX/pages/search/widgets/search_text.dart';
import 'package:PiliPalaX/pages/video/detail/reply/view.dart'
    show MySliverPersistentHeaderDelegate;
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/widgets/video_card_h.dart';
import 'package:PiliPalaX/models/common/search_type.dart';
import 'package:PiliPalaX/pages/search_panel/index.dart';
import 'package:intl/intl.dart';

import '../../../common/constants.dart';
import '../../../utils/grid.dart';

Widget searchVideoPanel(context, ctr, LoadingState loadingState) {
  final controller = Get.put(VideoPanelController());
  return CustomScrollView(
    controller: ctr.scrollController,
    slivers: [
      SliverPersistentHeader(
        pinned: false,
        floating: true,
        delegate: MySliverPersistentHeaderDelegate(
          child: Container(
            height: 34,
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Obx(
                      () => Wrap(
                        // spacing: ,
                        children: [
                          for (var i in controller.filterList) ...[
                            CustomFilterChip(
                              label: i['label'],
                              type: i['type'],
                              selectedType: controller.selectedType.value,
                              callFn: (bool selected) async {
                                debugPrint('selected: $selected');
                                controller.selectedType.value = i['type'];
                                ctr.order.value =
                                    i['type'].toString().split('.').last;
                                SmartDialog.showLoading(msg: 'loading');
                                await ctr.onRefresh();
                                SmartDialog.dismiss();
                              },
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(indent: 7, endIndent: 8),
                const SizedBox(width: 3),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    tooltip: '筛选',
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                    ),
                    onPressed: () =>
                        controller.onShowFilterDialog(context, ctr),
                    icon: Icon(
                      Icons.filter_list_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      switch (loadingState) {
        Loading() => errorWidget(),
        Success() => (loadingState.response as List?)?.isNotEmpty == true
            ? SliverPadding(
                padding: EdgeInsets.only(
                  left: StyleString.safeSpace,
                  right: StyleString.safeSpace,
                  bottom: StyleString.safeSpace +
                      MediaQuery.of(context).padding.bottom,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithExtentAndRatio(
                    mainAxisSpacing: StyleString.safeSpace,
                    crossAxisSpacing: StyleString.safeSpace,
                    maxCrossAxisExtent: Grid.maxRowWidth * 2,
                    childAspectRatio: StyleString.aspectRatio * 2.4,
                    mainAxisExtent: 0,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      if (index == loadingState.response.length - 1) {
                        ctr.onLoadMore();
                      }
                      return VideoCardH(
                        videoItem: loadingState.response[index],
                        showPubdate: true,
                      );
                    },
                    childCount: loadingState.response.length,
                  ),
                ),
              )
            : HttpError(
                callback: ctr.onReload,
              ),
        Error() => HttpError(
            errMsg: loadingState.errMsg,
            callback: ctr.onReload,
          ),
        _ => throw UnimplementedError(),
      },
    ],
  );
}

class CustomFilterChip extends StatelessWidget {
  const CustomFilterChip({
    this.label,
    this.type,
    this.selectedType,
    this.callFn,
    super.key,
  });

  final String? label;
  final ArchiveFilterType? type;
  final ArchiveFilterType? selectedType;
  final Function? callFn;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilterChip(
        padding: const EdgeInsets.only(left: 8, right: 8),
        labelPadding: EdgeInsets.zero,
        label: Text(
          label!,
          style: const TextStyle(fontSize: 13),
        ),
        labelStyle: TextStyle(
            color: type == selectedType
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline),
        selected: type == selectedType,
        showCheckmark: false,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        selectedColor: Colors.transparent,
        // backgroundColor:
        //     Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        backgroundColor: Colors.transparent,
        side: BorderSide.none,
        onSelected: (bool selected) => callFn?.call(selected),
      ),
    );
  }
}

class VideoPanelController extends GetxController {
  RxList<Map> filterList = [{}].obs;
  Rx<ArchiveFilterType> selectedType = ArchiveFilterType.values.first.obs;
  List pubTimeFiltersList = [
    {'label': '不限', 'value': 0},
    {'label': '最近一天', 'value': 1},
    {'label': '最近一周', 'value': 2},
    {'label': '最近半年', 'value': 3},
  ];
  List timeFiltersList = [
    {'label': '全部时长', 'value': 0},
    {'label': '0-10分钟', 'value': 1},
    {'label': '10-30分钟', 'value': 2},
    {'label': '30-60分钟', 'value': 3},
    {'label': '60分钟+', 'value': 4},
  ];
  List zoneFiltersList = [
    {'label': '全部', 'value': 0},
    {'label': '动画', 'value': 1, 'tids': 1},
    {'label': '番剧', 'value': 2, 'tids': 13},
    {'label': '国创', 'value': 3, 'tids': 167},
    {'label': '音乐', 'value': 4, 'tids': 3},
    {'label': '舞蹈', 'value': 5, 'tids': 129},
    {'label': '游戏', 'value': 6, 'tids': 4},
    {'label': '知识', 'value': 7, 'tids': 36},
    {'label': '科技', 'value': 8, 'tids': 188},
    {'label': '运动', 'value': 9, 'tids': 234},
    {'label': '汽车', 'value': 10, 'tids': 223},
    {'label': '生活', 'value': 11, 'tids': 160},
    {'label': '美食', 'value': 12, 'tids': 221},
    {'label': '动物', 'value': 13, 'tids': 217},
    {'label': '鬼畜', 'value': 14, 'tids': 119},
    {'label': '时尚', 'value': 15, 'tids': 155},
    {'label': '资讯', 'value': 16, 'tids': 202},
    {'label': '娱乐', 'value': 17, 'tids': 5},
    {'label': '影视', 'value': 18, 'tids': 181},
    {'label': '记录', 'value': 19, 'tids': 177},
    {'label': '电影', 'value': 20, 'tids': 23},
    {'label': '电视', 'value': 21, 'tids': 11},
  ];
  int currentPubTimeFilterval = 0;
  late DateTime pubBegin;
  late DateTime pubEnd;
  bool customPubBegin = false;
  bool customPubEnd = false;
  int currentTimeFilterval = 0;
  int currentZoneFilterval = 0;

  @override
  void onInit() {
    DateTime now = DateTime.now();
    pubBegin = DateTime(
      now.year,
      now.month,
      1,
      0,
      0,
      0,
    );
    pubEnd = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    );
    List<Map<String, dynamic>> list = ArchiveFilterType.values
        .map((type) => {
              'label': type.description,
              'type': type,
            })
        .toList();
    filterList.value = list;
    super.onInit();
  }

  onShowFilterDialog(
    BuildContext context,
    SearchPanelController searchPanelCtr,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Widget dateWidget([bool isFirst = true]) {
            return SearchText(
              searchText:
                  DateFormat('yyyy-MM-dd').format(isFirst ? pubBegin : pubEnd),
              textAlign: TextAlign.center,
              onSelect: (text) {
                showDatePicker(
                  context: context,
                  initialDate: isFirst ? pubBegin : pubEnd,
                  firstDate: isFirst ? DateTime(2009, 6, 26) : pubBegin,
                  lastDate: isFirst ? pubEnd : DateTime.now(),
                ).then((selectedDate) async {
                  if (selectedDate != null) {
                    if (isFirst) {
                      customPubBegin = true;
                      pubBegin = selectedDate;
                    } else {
                      customPubEnd = true;
                      pubEnd = selectedDate;
                    }
                    currentPubTimeFilterval = -1;
                    SmartDialog.dismiss();
                    // SmartDialog.showToast("「${item['label']}」的筛选结果");
                    SearchPanelController ctr = Get.find<SearchPanelController>(
                        tag: 'video${searchPanelCtr.keyword!}');
                    ctr.pubBegin = DateTime(
                          pubBegin.year,
                          pubBegin.month,
                          pubBegin.day,
                          0,
                          0,
                          0,
                        ).millisecondsSinceEpoch ~/
                        1000;
                    ctr.pubEnd = DateTime(
                          pubEnd.year,
                          pubEnd.month,
                          pubEnd.day,
                          23,
                          59,
                          59,
                        ).millisecondsSinceEpoch ~/
                        1000;
                    setState(() {});
                    SmartDialog.showLoading(msg: 'loading');
                    await ctr.onRefresh();
                    SmartDialog.dismiss();
                  }
                });
              },
              onLongSelect: (_) {},
              bgColor: currentPubTimeFilterval == -1 &&
                      (isFirst ? customPubBegin : customPubEnd)
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.1),
              textColor: currentPubTimeFilterval == -1 &&
                      (isFirst ? customPubBegin : customPubEnd)
                  ? Theme.of(context).colorScheme.onSecondaryContainer
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.8),
            );
          }

          return SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: 80 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text('发布时间', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: pubTimeFiltersList
                        .map(
                          (item) => SearchText(
                            searchText: item['label'],
                            onSelect: (text) async {
                              Get.back();
                              currentPubTimeFilterval = item['value'];
                              SmartDialog.dismiss();
                              SmartDialog.showToast("「${item['label']}」的筛选结果");
                              SearchPanelController ctr =
                                  Get.find<SearchPanelController>(
                                      tag: 'video${searchPanelCtr.keyword!}');
                              DateTime now = DateTime.now();
                              if (item['value'] == 0) {
                                ctr.pubBegin = null;
                                ctr.pubEnd = null;
                              } else {
                                ctr.pubBegin = DateTime(
                                      now.year,
                                      now.month,
                                      now.day -
                                          (item['value'] == 0
                                              ? 0
                                              : item['value'] == 1
                                                  ? 6
                                                  : 179),
                                      0,
                                      0,
                                      0,
                                    ).millisecondsSinceEpoch ~/
                                    1000;
                                ctr.pubEnd = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                      23,
                                      59,
                                      59,
                                    ).millisecondsSinceEpoch ~/
                                    1000;
                              }
                              SmartDialog.showLoading(msg: 'loading');
                              await ctr.onRefresh();
                              SmartDialog.dismiss();
                            },
                            onLongSelect: (_) {},
                            bgColor: item['value'] == currentPubTimeFilterval
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                : null,
                            textColor: item['value'] == currentPubTimeFilterval
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: dateWidget()),
                      const SizedBox(width: 8),
                      const Text(
                        '至',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: dateWidget(false)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('内容时长', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: timeFiltersList
                        .map(
                          (item) => SearchText(
                            searchText: item['label'],
                            onSelect: (text) async {
                              Get.back();
                              currentTimeFilterval = item['value'];
                              SmartDialog.dismiss();
                              SmartDialog.showToast("「${item['label']}」的筛选结果");
                              SearchPanelController ctr =
                                  Get.find<SearchPanelController>(
                                      tag: 'video${searchPanelCtr.keyword!}');
                              ctr.duration.value = item['value'];
                              SmartDialog.showLoading(msg: 'loading');
                              await ctr.onRefresh();
                              SmartDialog.dismiss();
                            },
                            onLongSelect: (_) {},
                            bgColor: item['value'] == currentTimeFilterval
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                : null,
                            textColor: item['value'] == currentTimeFilterval
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text('内容分区', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: zoneFiltersList
                        .map(
                          (item) => SearchText(
                            searchText: item['label'],
                            onSelect: (text) async {
                              Get.back();
                              currentZoneFilterval = item['value'];
                              SmartDialog.dismiss();
                              SmartDialog.showToast("「${item['label']}」的筛选结果");
                              SearchPanelController ctr =
                                  Get.find<SearchPanelController>(
                                      tag: 'video${searchPanelCtr.keyword!}');
                              ctr.tids = item['tids'];
                              SmartDialog.showLoading(msg: 'loading');
                              await ctr.onRefresh();
                              SmartDialog.dismiss();
                            },
                            onLongSelect: (_) {},
                            bgColor: item['value'] == currentZoneFilterval
                                ? Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                : null,
                            textColor: item['value'] == currentZoneFilterval
                                ? Theme.of(context)
                                    .colorScheme
                                    .onSecondaryContainer
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
