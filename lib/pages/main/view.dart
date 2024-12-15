import 'dart:async';
import 'dart:io';

import 'package:PiliPalaX/grpc/grpc_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/models/common/dynamic_badge_mode.dart';
import 'package:PiliPalaX/pages/dynamics/index.dart';
import 'package:PiliPalaX/pages/home/index.dart';
import 'package:PiliPalaX/utils/event_bus.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/storage.dart';
import './controller.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();

  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();
}

class _MainAppState extends State<MainApp>
    with SingleTickerProviderStateMixin, RouteAware, WidgetsBindingObserver {
  final MainController _mainController = Get.put(MainController());
  final HomeController _homeController = Get.put(HomeController());
  final DynamicsController _dynamicController = Get.put(DynamicsController());

  int? _lastSelectTime; //上次点击时间
  Box setting = GStorage.setting;
  late bool enableMYBar;
  late bool useSideBar;

  @override
  void initState() {
    super.initState();
    _lastSelectTime = DateTime.now().millisecondsSinceEpoch;
    _mainController.pageController =
        PageController(initialPage: _mainController.selectedIndex);
    enableMYBar = setting.get(SettingBoxKey.enableMYBar, defaultValue: true);
    useSideBar = setting.get(SettingBoxKey.useSideBar, defaultValue: false);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MainApp.routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void didPopNext() {
    _mainController.checkUnreadDynamic();
    super.didPopNext();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _mainController.checkUnreadDynamic();
    }
  }

  void setIndex(int value) async {
    feedBack();
    _mainController.pageController.jumpToPage(value);
    var currentPage = _mainController.pages[value];
    if (currentPage is HomePage) {
      if (_homeController.flag) {
        // 单击返回顶部 双击并刷新
        if (DateTime.now().millisecondsSinceEpoch - _lastSelectTime! < 500) {
          _homeController.onRefresh();
        } else {
          _homeController.animateToTop();
        }
        _lastSelectTime = DateTime.now().millisecondsSinceEpoch;
      }
      _homeController.flag = true;
    } else {
      _homeController.flag = false;
    }

    // if (currentPage is RankPage) {
    //   if (_rankController.flag) {
    //     // 单击返回顶部 双击并刷新
    //     if (DateTime.now().millisecondsSinceEpoch - _lastSelectTime! < 500) {
    //       _rankController.onRefresh();
    //     } else {
    //       _rankController.animateToTop();
    //     }
    //     _lastSelectTime = DateTime.now().millisecondsSinceEpoch;
    //   }
    //   _rankController.flag = true;
    // } else {
    //   _rankController.flag = false;
    // }

    if (currentPage is DynamicsPage) {
      if (_dynamicController.flag) {
        // 单击返回顶部 双击并刷新
        if (DateTime.now().millisecondsSinceEpoch - _lastSelectTime! < 500) {
          _dynamicController.onRefresh();
        } else {
          _dynamicController.animateToTop();
        }
        _lastSelectTime = DateTime.now().millisecondsSinceEpoch;
      }
      _dynamicController.flag = true;
      _mainController.setCount();
    } else {
      _dynamicController.flag = false;
    }
  }

  @override
  void dispose() async {
    MainApp.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    await GrpcClient.instance.shutdown();
    await GStorage.close();
    EventBus().off(EventName.loginEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (_mainController.selectedIndex != 0) {
          setIndex(0);
          _mainController.bottomBarStream.add(true);
        } else {
          if (Platform.isAndroid) {
            const MethodChannel("onUserLeaveHint").invokeMethod('back');
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: LayoutBuilder(
        builder: (context, constriants) {
          bool isPortait = constriants.maxHeight > constriants.maxWidth;

          return Scaffold(
            extendBody: true,
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (useSideBar) ...[
                  SizedBox(
                    width: context.width * 0.0387 +
                        36.801 +
                        MediaQuery.of(context).padding.left,
                    child: Obx(
                      () => _mainController.navigationBars.length > 1
                          ? NavigationRail(
                              groupAlignment: 1,
                              minWidth: context.width * 0.0286 + 28.56,
                              backgroundColor: Colors.transparent,
                              selectedIndex: _mainController.selectedIndex,
                              onDestinationSelected: setIndex,
                              labelType: NavigationRailLabelType.none,
                              leading:
                                  UserAndSearchVertical(ctr: _homeController),
                              destinations: _mainController.navigationBars
                                  .map((e) => NavigationRailDestination(
                                        icon: _buildIcon(
                                          id: e['id'],
                                          count: e['count'],
                                          icon: e['icon'],
                                        ),
                                        selectedIcon: _buildIcon(
                                          id: e['id'],
                                          count: e['count'],
                                          icon: e['selectIcon'],
                                        ),
                                        label: Text(e['label']),
                                        padding: EdgeInsets.symmetric(
                                            vertical: 0.01 * context.height),
                                      ))
                                  .toList(),
                              trailing: SizedBox(height: 0.1 * context.height),
                            )
                          : Container(
                              padding: EdgeInsets.only(
                                  top: MediaQuery.paddingOf(context).top + 10),
                              constraints: BoxConstraints(
                                minWidth: context.width * 0.0286 + 28.56,
                              ),
                              child:
                                  UserAndSearchVertical(ctr: _homeController),
                            ),
                    ),
                  ),
                ] else if (!isPortait)
                  Obx(
                    () => _mainController.navigationBars.length > 1
                        ? NavigationRail(
                            onDestinationSelected: setIndex,
                            selectedIndex: _mainController.selectedIndex,
                            destinations: _mainController.navigationBars
                                .map(
                                  (e) => NavigationRailDestination(
                                    icon: _buildIcon(
                                      id: e['id'],
                                      count: e['count'],
                                      icon: e['icon'],
                                    ),
                                    selectedIcon: _buildIcon(
                                      id: e['id'],
                                      count: e['count'],
                                      icon: e['selectIcon'],
                                    ),
                                    label: Text(e['label']),
                                  ),
                                )
                                .toList(),
                          )
                        : const SizedBox.shrink(),
                  ),
                VerticalDivider(
                  width: 1,
                  indent: MediaQuery.of(context).padding.top,
                  endIndent: MediaQuery.of(context).padding.bottom,
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.06),
                ),
                Expanded(
                  child: PageView(
                    physics: const NeverScrollableScrollPhysics(),
                    controller: _mainController.pageController,
                    onPageChanged: (index) {
                      _mainController.selectedIndex = index;
                      setState(() {});
                    },
                    children: _mainController.pages,
                  ),
                ),
                if (useSideBar) SizedBox(width: context.width * 0.004),
              ],
            ),
            bottomNavigationBar: useSideBar || !isPortait
                ? null
                : StreamBuilder(
                    stream: _mainController.hideTabBar
                        ? _mainController.bottomBarStream.stream
                        : StreamController<bool>.broadcast().stream,
                    initialData: true,
                    builder: (context, AsyncSnapshot snapshot) {
                      return AnimatedSlide(
                        curve: Curves.easeInOutCubicEmphasized,
                        duration: const Duration(milliseconds: 500),
                        offset: Offset(0, snapshot.data ? 0 : 1),
                        child: enableMYBar
                            ? Obx(
                                () => _mainController.navigationBars.length > 1
                                    ? NavigationBar(
                                        onDestinationSelected: setIndex,
                                        selectedIndex:
                                            _mainController.selectedIndex,
                                        destinations:
                                            _mainController.navigationBars.map(
                                          (e) {
                                            return NavigationDestination(
                                              icon: _buildIcon(
                                                id: e['id'],
                                                count: e['count'],
                                                icon: e['icon'],
                                              ),
                                              selectedIcon: _buildIcon(
                                                id: e['id'],
                                                count: e['count'],
                                                icon: e['selectIcon'],
                                              ),
                                              label: e['label'],
                                            );
                                          },
                                        ).toList(),
                                      )
                                    : const SizedBox.shrink(),
                              )
                            : Obx(
                                () => _mainController.navigationBars.length > 1
                                    ? BottomNavigationBar(
                                        currentIndex:
                                            _mainController.selectedIndex,
                                        onTap: setIndex,
                                        iconSize: 16,
                                        selectedFontSize: 12,
                                        unselectedFontSize: 12,
                                        type: BottomNavigationBarType.fixed,
                                        // selectedItemColor:
                                        //     Theme.of(context).colorScheme.primary, // 选中项的颜色
                                        // unselectedItemColor:
                                        //     Theme.of(context).colorScheme.onSurface,
                                        items: _mainController.navigationBars
                                            .map(
                                              (e) => BottomNavigationBarItem(
                                                icon: _buildIcon(
                                                  id: e['id'],
                                                  count: e['count'],
                                                  icon: e['icon'],
                                                ),
                                                activeIcon: _buildIcon(
                                                  id: e['id'],
                                                  count: e['count'],
                                                  icon: e['selectIcon'],
                                                ),
                                                label: e['label'],
                                              ),
                                            )
                                            .toList(),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }

  Widget _buildIcon({
    required int id,
    required int count,
    required Widget icon,
  }) =>
      id == 1 &&
              _mainController.dynamicBadgeType != DynamicBadgeMode.hidden &&
              count > 0
          ? Badge(
              label: _mainController.dynamicBadgeType == DynamicBadgeMode.number
                  ? Text(count.toString())
                  : null,
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
              // isLabelVisible:
              //     _mainController.dynamicBadgeType != DynamicBadgeMode.hidden &&
              //         count > 0,
              // backgroundColor: Theme.of(context).colorScheme.primary,
              // textColor: Theme.of(context).colorScheme.onInverseSurface,
              child: icon,
            )
          : icon;
}
