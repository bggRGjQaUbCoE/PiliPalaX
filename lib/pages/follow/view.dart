import 'package:PiliPalaX/pages/fav_search/view.dart' show SearchType;
import 'package:PiliPalaX/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controller.dart';
import 'widgets/follow_list.dart';
import 'widgets/owner_follow_list.dart';

class FollowPage extends StatefulWidget {
  const FollowPage({super.key});

  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> {
  late String mid;
  late FollowController _followController;

  @override
  void initState() {
    super.initState();
    mid = Get.parameters['mid']!;
    _followController =
        Get.put(FollowController(), tag: Utils.makeHeroTag(mid));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _followController.isOwner.value
              ? '我的关注'
              : '${_followController.name}的关注',
        ),
        actions: [
          IconButton(
              onPressed: () => Get.toNamed('/favSearch', arguments: {
                    'mid': int.parse(mid),
                    'searchType': SearchType.follow,
                  }),
              icon: const Icon(Icons.search_outlined),
              tooltip: '搜索'),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) => <PopupMenuEntry>[
              PopupMenuItem(
                onTap: () => Get.toNamed('/blackListPage'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, size: 19),
                    SizedBox(width: 10),
                    Text('黑名单管理'),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Obx(
        () => !_followController.isOwner.value
            ? FollowList(ctr: _followController)
            : FutureBuilder(
                future: _followController.followUpTags(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    var data = snapshot.data;
                    if (data['status']) {
                      return Column(
                        children: [
                          TabBar(
                              controller: _followController.tabController,
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              tabs: [
                                for (var i in data['data']) ...[
                                  Tab(text: i.name),
                                ]
                              ]),
                          Expanded(
                            child: TabBarView(
                              controller: _followController.tabController,
                              children: [
                                for (var i = 0;
                                    i < _followController.tabController.length;
                                    i++) ...[
                                  OwnerFollowList(
                                    ctr: _followController,
                                    tagItem: _followController.followTags[i],
                                  )
                                ]
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return const SizedBox();
                    }
                  } else {
                    return const SizedBox();
                  }
                },
              ),
      ),
    );
  }
}

// class _FakeAPI {
//   static const List<String> _kOptions = <String>[
//     'aardvark',
//     'bobcat',
//     'chameleon',
//   ];
//   // Searches the options, but injects a fake "network" delay.
//   static Future<Iterable<String>> search(String query) async {
//     await Future<void>.delayed(
//         const Duration(seconds: 1)); // Fake 1 second delay.
//     if (query == '') {
//       return const Iterable<String>.empty();
//     }
//     return _kOptions.where((String option) {
//       return option.contains(query.toLowerCase());
//     });
//   }
// }
