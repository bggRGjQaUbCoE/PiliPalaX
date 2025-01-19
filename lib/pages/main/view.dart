import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/common/widgets/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/tabs.dart';
import 'package:PiliPlus/grpc/grpc_client.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/models/common/dynamic_badge_mode.dart';
import 'package:PiliPlus/pages/dynamics/index.dart';
import 'package:PiliPlus/pages/home/index.dart';
import 'package:PiliPlus/utils/event_bus.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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
  late final _homeController = Get.put(HomeController());
  late final _dynamicController = Get.put(DynamicsController());

  late int _lastSelectTime = 0; //上次点击时间
  late bool enableMYBar;
  late bool useSideBar;

  @override
  void initState() {
    super.initState();
    _lastSelectTime = DateTime.now().millisecondsSinceEpoch;
    _mainController.controller = TabController(
      vsync: this,
      initialIndex: _mainController.selectedIndex.value,
      length: _mainController.navigationBars.length,
    );
    enableMYBar =
        GStorage.setting.get(SettingBoxKey.enableMYBar, defaultValue: true);
    useSideBar =
        GStorage.setting.get(SettingBoxKey.useSideBar, defaultValue: false);
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
    _checkDefaultSearch(true);
    _checkUnread(context.orientation == Orientation.portrait);
    super.didPopNext();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _mainController.checkUnreadDynamic();
      _checkDefaultSearch(true);
      _checkUnread(context.orientation == Orientation.portrait);
    }
  }

  void _checkDefaultSearch([bool shouldCheck = false]) {
    if (_mainController.homeIndex != -1 && _homeController.enableSearchWord) {
      if (shouldCheck &&
          _mainController.pages[_mainController.selectedIndex.value]
              is! HomePage) {
        return;
      }
      int now = DateTime.now().millisecondsSinceEpoch;
      if (now - _homeController.lateCheckSearchAt >= 5 * 60 * 1000) {
        _homeController.lateCheckSearchAt = now;
        _homeController.querySearchDefault();
      }
    }
  }

  void _checkUnread([bool shouldCheck = false]) {
    if (_mainController.isLogin.value &&
        _mainController.homeIndex != -1 &&
        _mainController.msgBadgeMode != DynamicBadgeMode.hidden) {
      if (shouldCheck &&
          _mainController.pages[_mainController.selectedIndex.value]
              is! HomePage) {
        return;
      }
      int now = DateTime.now().millisecondsSinceEpoch;
      if (now - _mainController.lastCheckUnreadAt >= 5 * 60 * 1000) {
        _mainController.lastCheckUnreadAt = now;
        _mainController.queryUnreadMsg();
      }
    }
  }

  void setIndex(int value) async {
    feedBack();

    if (value != _mainController.selectedIndex.value) {
      _mainController.selectedIndex.value = value;
      _mainController.controller.animateTo(value);
      dynamic currentPage = _mainController.pages[value];
      if (currentPage is HomePage) {
        _checkDefaultSearch();
        _checkUnread();
      } else if (currentPage is DynamicsPage) {
        _mainController.setCount();
      }
    } else {
      dynamic currentPage = _mainController.pages[value];

      if (currentPage is HomePage) {
        _homeController.animateToTop();
      } else if (currentPage is DynamicsPage) {
        _dynamicController.animateToTop();
      }

      int now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastSelectTime < 500) {
        if (currentPage is HomePage) {
          _homeController.onRefresh();
        } else if (currentPage is DynamicsPage) {
          _dynamicController.onRefresh();
        }
      }
      _lastSelectTime = now;
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
        if (_mainController.selectedIndex.value != 0) {
          setIndex(0);
          _mainController.bottomBarStream.add(true);
        } else {
          if (Platform.isAndroid) {
            Utils.channel.invokeMethod('back');
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (useSideBar || context.orientation == Orientation.landscape)
              Obx(
                () => _mainController.navigationBars.length > 1
                    ? NavigationRail(
                        groupAlignment: 0.5,
                        selectedIndex: _mainController.selectedIndex.value,
                        onDestinationSelected: setIndex,
                        labelType: NavigationRailLabelType.selected,
                        leading: userAndSearchVertical,
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
                    : Container(
                        padding: EdgeInsets.only(
                          top: MediaQuery.paddingOf(context).top + 10,
                        ),
                        width: 56,
                        child: userAndSearchVertical,
                      ),
              ),
            VerticalDivider(
              width: 1,
              indent: MediaQuery.of(context).padding.top,
              endIndent: MediaQuery.of(context).padding.bottom,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.06),
            ),
            Expanded(
              child: CustomTabBarView(
                scrollDirection: context.orientation == Orientation.portrait
                    ? Axis.horizontal
                    : Axis.vertical,
                physics: const NeverScrollableScrollPhysics(),
                controller: _mainController.controller,
                children: _mainController.pages,
              ),
            ),
          ],
        ),
        bottomNavigationBar:
            useSideBar || context.orientation == Orientation.landscape
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
                                            _mainController.selectedIndex.value,
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
                                            _mainController.selectedIndex.value,
                                        onTap: setIndex,
                                        iconSize: 16,
                                        selectedFontSize: 12,
                                        unselectedFontSize: 12,
                                        type: BottomNavigationBarType.fixed,
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
      ),
    );
  }

  Widget _buildIcon({
    required int id,
    required int count,
    required Widget icon,
  }) =>
      id == 1 &&
              _mainController.dynamicBadgeMode != DynamicBadgeMode.hidden &&
              count > 0
          ? Badge(
              label: _mainController.dynamicBadgeMode == DynamicBadgeMode.number
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

  Widget get userAndSearchVertical {
    return Column(
      children: [
        Semantics(
          label: "我的",
          child: Obx(
            () => _homeController.isLogin.value
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      NetworkImgLayer(
                        type: 'avatar',
                        width: 34,
                        height: 34,
                        src: _homeController.userFace.value,
                      ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                _homeController.showUserInfoDialog(context),
                            splashColor: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(0.3),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(50),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -6,
                        bottom: -6,
                        child: Obx(() => MineController.anonymity.value
                            ? IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    size: 16,
                                    MdiIcons.incognito,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink()),
                      ),
                    ],
                  )
                : DefaultUser(
                    onPressed: () =>
                        _homeController.showUserInfoDialog(context)),
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => _homeController.isLogin.value
              ? msgBadge(_mainController)
              : const SizedBox.shrink(),
        ),
        IconButton(
          icon: const Icon(
            Icons.search_outlined,
            semanticLabel: '搜索',
          ),
          onPressed: () => Get.toNamed('/search'),
        ),
      ],
    );
  }
}
