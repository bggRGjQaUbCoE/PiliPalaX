import 'dart:io';
import 'dart:math';

import 'package:PiliPalaX/http/interceptor_anonymity.dart';
import 'package:PiliPalaX/models/common/dynamic_badge_mode.dart';
import 'package:PiliPalaX/models/common/dynamics_type.dart';
import 'package:PiliPalaX/models/common/nav_bar_config.dart';
import 'package:PiliPalaX/models/common/rcmd_type.dart';
import 'package:PiliPalaX/models/common/reply_sort_type.dart';
import 'package:PiliPalaX/models/common/theme_type.dart';
import 'package:PiliPalaX/models/common/up_panel_position.dart';
import 'package:PiliPalaX/models/video/play/CDN.dart';
import 'package:PiliPalaX/models/video/play/quality.dart';
import 'package:PiliPalaX/models/video/play/subtitle.dart';
import 'package:PiliPalaX/pages/home/controller.dart';
import 'package:PiliPalaX/pages/main/controller.dart';
import 'package:PiliPalaX/pages/member/new/controller.dart';
import 'package:PiliPalaX/pages/mine/controller.dart';
import 'package:PiliPalaX/pages/setting/pages/color_select.dart';
import 'package:PiliPalaX/pages/setting/widgets/normal_item.dart';
import 'package:PiliPalaX/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPalaX/pages/setting/widgets/slide_dialog.dart';
import 'package:PiliPalaX/pages/setting/widgets/switch_item.dart';
import 'package:PiliPalaX/plugin/pl_player/models/bottom_progress_behavior.dart';
import 'package:PiliPalaX/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliPalaX/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliPalaX/utils/extension.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/global_data.dart';
import 'package:PiliPalaX/utils/recommend_filter.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:auto_orientation/auto_orientation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

extension SettingsModelExt on SettingsModel {
  Widget get widget => switch (settingsType) {
        SettingsType.normal => NormalItem(
            title: title,
            getTitle: getTitle,
            subtitle: subtitle,
            getSubtitle: getSubtitle,
            setKey: setKey,
            defaultVal: defaultVal,
            onChanged: onChanged,
            needReboot: needReboot,
            leading: leading,
            getTrailing: getTrailing,
            onTap: onTap,
            contentPadding: contentPadding,
            titleStyle: titleStyle,
          ),
        SettingsType.sw1tch => SetSwitchItem(
            title: title,
            subtitle: subtitle,
            setKey: setKey,
            defaultVal: defaultVal,
            onChanged: onChanged,
            needReboot: needReboot,
            leading: leading,
            onTap: onTap,
            contentPadding: contentPadding,
            titleStyle: titleStyle,
          ),
      };
}

class SettingsModel {
  final SettingsType settingsType;
  final String? title;
  final Function? getTitle;
  final String? subtitle;
  final Function? getSubtitle;
  final String? setKey;
  final bool? defaultVal;
  final ValueChanged<bool>? onChanged;
  final bool? needReboot;
  final Widget? leading;
  final Function? getTrailing;
  final Function? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? titleStyle;
  final bool? enableFeedback;

  SettingsModel({
    required this.settingsType,
    this.title,
    this.getTitle,
    this.subtitle,
    this.getSubtitle,
    this.setKey,
    this.defaultVal,
    this.onChanged,
    this.needReboot,
    this.leading,
    this.getTrailing,
    this.onTap,
    this.contentPadding,
    this.titleStyle,
    this.enableFeedback,
  });
}

enum SettingsType { normal, sw1tch }

List<SettingsModel> get styleSettings => [
      SettingsModel(
          settingsType: SettingsType.sw1tch,
          title: '横屏适配',
          subtitle: '启用横屏布局与逻辑，平板、折叠屏等可开启；建议全屏方向设为【不改变当前方向】',
          leading: const Icon(Icons.phonelink_outlined),
          setKey: SettingBoxKey.horizontalScreen,
          defaultVal: false,
          onChanged: (value) {
            if (value) {
              autoScreen();
              // SmartDialog.showToast('已开启横屏适配');
            } else {
              AutoOrientation.portraitUpMode();
              // SmartDialog.showToast('已关闭横屏适配');
            }
          }),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '改用侧边栏',
        subtitle: '开启后底栏与顶栏被替换，且相关设置失效',
        leading: Icon(Icons.chrome_reader_mode_outlined),
        setKey: SettingBoxKey.useSideBar,
        defaultVal: false,
        needReboot: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: 'MD3样式底栏',
        subtitle: 'Material You设计规范底栏，关闭可变窄',
        leading: Icon(Icons.design_services_outlined),
        setKey: SettingBoxKey.enableMYBar,
        defaultVal: true,
        needReboot: true,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) async {
          double? result = await showDialog(
              context: Get.context!,
              builder: (context) {
                return SlideDialog<double>(
                  title: '最大列宽度（默认240dp）',
                  value: GStorage.maxRowWidth,
                  min: 150.0,
                  max: 500.0,
                  divisions: 35,
                  suffix: 'dp',
                );
              });
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.maxRowWidth, result);
            SmartDialog.showToast('重启生效');
            setState();
          }
        },
        leading: const Icon(Icons.calendar_view_week_outlined),
        title: '列表宽度（dp）限制',
        getSubtitle: () =>
            '当前:${GStorage.maxRowWidth.toInt()}dp，屏幕宽度:${MediaQuery.of(Get.context!).size.width.toPrecision(2)}dp。宽度越小列数越多，横条、大卡会2倍折算',
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '播放页移除安全边距',
        subtitle: '隐藏状态栏、撑满屏幕，但播放控件仍处于安全域内',
        leading: Icon(Icons.fit_screen_outlined),
        setKey: SettingBoxKey.videoPlayerRemoveSafeArea,
        defaultVal: false,
        needReboot: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '动态页启用瀑布流',
        subtitle: '关闭会显示为单列',
        leading: Icon(Icons.view_array_outlined),
        setKey: SettingBoxKey.dynamicsWaterfallFlow,
        defaultVal: true,
        needReboot: true,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '动态页UP主显示位置',
        leading: const Icon(Icons.person_outlined),
        getSubtitle: () => '当前：${GStorage.upPanelPosition.labels}',
        onTap: (setState) async {
          UpPanelPosition? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<UpPanelPosition>(
                title: '动态页UP主显示位置',
                value: GStorage.upPanelPosition,
                values: UpPanelPosition.values.map((e) {
                  return {'title': e.labels, 'value': e};
                }).toList(),
              );
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.upPanelPosition, result.index);
            SmartDialog.showToast('重启生效');
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '动态页显示所有已关注UP主',
        subtitle: '并以最常访问排序UP',
        leading: Icon(Icons.people_alt_outlined),
        setKey: SettingBoxKey.dynamicsShowAllFollowedUp,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) async {
          DynamicBadgeMode? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<DynamicBadgeMode>(
                title: '动态未读标记',
                value: GStorage.dynamicBadgeType,
                values: DynamicBadgeMode.values.map((e) {
                  return {'title': e.description, 'value': e};
                }).toList(),
              );
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.dynamicBadgeMode, result.code);
            MainController mainController = Get.put(MainController());
            mainController.dynamicBadgeType =
                DynamicBadgeMode.values[result.code];
            if (mainController.dynamicBadgeType != DynamicBadgeMode.hidden) {
              mainController.getUnreadDynamic();
            }
            SmartDialog.showToast('设置成功');
            setState();
          }
        },
        title: '动态未读标记',
        leading: const Icon(Icons.motion_photos_on_outlined),
        getSubtitle: () => '当前标记样式：${GStorage.dynamicBadgeType.description}',
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '首页顶栏收起',
        subtitle: '首页列表滑动时，收起顶栏',
        leading: Icon(Icons.vertical_align_top_outlined),
        setKey: SettingBoxKey.hideSearchBar,
        defaultVal: true,
        needReboot: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '首页底栏收起',
        subtitle: '首页列表滑动时，收起底栏',
        leading: Icon(Icons.vertical_align_bottom_outlined),
        setKey: SettingBoxKey.hideTabBar,
        defaultVal: true,
        needReboot: true,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) {
          _showQualityDialog(
            context: Get.context!,
            title: '图片质量',
            initValue: GStorage.picQuality,
            callback: (picQuality) {
              GStorage.setting.put(SettingBoxKey.defaultPicQa, picQuality);
              GlobalData().imgQuality = picQuality;
              setState();
            },
          );
        },
        title: '图片质量',
        subtitle: '选择合适的图片清晰度，上限100%',
        leading: const Icon(Icons.image_outlined),
        getTrailing: () => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            '${GStorage.picQuality}%',
            style: Theme.of(Get.context!).textTheme.titleSmall,
          ),
        ),
      ),
      // preview quality
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) {
          _showQualityDialog(
            context: Get.context!,
            title: '查看大图质量',
            initValue: GStorage.previewQ,
            callback: (picQuality) {
              GStorage.setting.put(SettingBoxKey.previewQuality, picQuality);
              setState();
            },
          );
        },
        title: '查看大图质量',
        subtitle: '选择合适的图片清晰度，上限100%',
        leading: const Icon(Icons.image_outlined),
        getTrailing: () => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            '${GStorage.previewQ}%',
            style: Theme.of(Get.context!).textTheme.titleSmall,
          ),
        ),
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) async {
          double? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SlideDialog<double>(
                title: 'Toast不透明度',
                value: GStorage.toastOpacity,
                min: 0.0,
                max: 1.0,
                divisions: 10,
              );
            },
          );
          if (result != null) {
            SmartDialog.showToast('设置成功');
            GStorage.setting.put(SettingBoxKey.defaultToastOp, result);
            setState();
          }
        },
        leading: const Icon(Icons.opacity_outlined),
        title: '气泡提示不透明度',
        subtitle: '自定义气泡提示(Toast)不透明度',
        getTrailing: () => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            GStorage.toastOpacity.toStringAsFixed(1),
            style: Theme.of(Get.context!).textTheme.titleSmall,
          ),
        ),
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) async {
          ThemeType? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<ThemeType>(
                  title: '主题模式',
                  value: GStorage.themeType,
                  values: ThemeType.values.map(
                    (e) {
                      return {'title': e.description, 'value': e};
                    },
                  ).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.themeMode, result.index);
            Get.put(ColorSelectController()).themeType.value = result;
            Get.forceAppUpdate();
          }
        },
        leading: const Icon(Icons.flashlight_on_outlined),
        title: '主题模式',
        getSubtitle: () => '当前模式：${GStorage.themeType.description}',
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) => Get.toNamed('/colorSetting'),
        leading: const Icon(Icons.color_lens_outlined),
        title: '应用主题',
        getSubtitle: () =>
            '当前主题：${Get.put(ColorSelectController()).type.value == 0 ? '动态取色' : '指定颜色'}',
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) async {
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<int>(
                title: '首页启动页',
                value: GStorage.defaultHomePage,
                values: defaultNavigationBars.map((e) {
                  return {'title': e['label'], 'value': e['id']};
                }).toList(),
              );
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.defaultHomePage, result);
            SmartDialog.showToast('设置成功，重启生效');
            setState();
          }
        },
        leading: const Icon(Icons.home_outlined),
        title: '默认启动页',
        getSubtitle: () =>
            '当前启动页：${defaultNavigationBars.firstWhere((e) => e['id'] == GStorage.defaultHomePage)['label']}',
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) async {
          dynamic result = await Get.toNamed('/fontSizeSetting');
          if (result != null) {
            Get.put(ColorSelectController()).currentTextScale.value = result;
          }
        },
        title: '字体大小',
        leading: const Icon(Icons.format_size_outlined),
        getSubtitle: () =>
            Get.put(ColorSelectController()).currentTextScale.value == 1.0
                ? '默认'
                : Get.put(ColorSelectController())
                    .currentTextScale
                    .value
                    .toString(),
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) => Get.toNamed('/tabbarSetting'),
        title: '首页标签页',
        subtitle: '删除或调换首页标签页',
        leading: const Icon(Icons.toc_outlined),
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) => Get.toNamed('/navbarSetting'),
        title: 'Navbar编辑',
        leading: const Icon(Icons.toc_outlined),
      ),
      if (Platform.isAndroid)
        SettingsModel(
          settingsType: SettingsType.normal,
          onTap: (setState) => Get.toNamed('/displayModeSetting'),
          title: '屏幕帧率',
          leading: const Icon(Icons.autofps_select_outlined),
        ),
    ];

void _showQualityDialog({
  required BuildContext context,
  required String title,
  required int initValue,
  required ValueChanged<int> callback,
}) {
  showDialog(
    context: context,
    builder: (context) {
      int picQuality = initValue;
      return AlertDialog(
        title: Text(title),
        contentPadding:
            const EdgeInsets.only(top: 20, left: 8, right: 8, bottom: 8),
        content: SizedBox(
          height: 40,
          child: Builder(
            builder: (context) => Slider(
              value: picQuality.toDouble(),
              min: 10,
              max: 100,
              divisions: 9,
              label: '$picQuality%',
              onChanged: (double val) {
                picQuality = val.toInt();
                (context as Element).markNeedsBuild();
              },
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(),
              child: Text('取消',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.outline))),
          TextButton(
            onPressed: () {
              Get.back();
              callback(picQuality);
              SmartDialog.showToast('设置成功');
            },
            child: const Text('确定'),
          )
        ],
      );
    },
  );
}

List<SettingsModel> get playSettings => [
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '弹幕开关',
        subtitle: '是否展示弹幕',
        leading: Icon(Icons.comment_outlined),
        setKey: SettingBoxKey.enableShowDanmaku,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) => Get.toNamed('/playSpeedSet'),
        leading: const Icon(Icons.speed_outlined),
        title: '倍速设置',
        subtitle: '设置视频播放速度',
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '自动播放',
        subtitle: '进入详情页自动播放',
        leading: Icon(Icons.motion_photos_auto_outlined),
        setKey: SettingBoxKey.autoPlayEnable,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '双击快退/快进',
        subtitle: '左侧双击快退/右侧双击快进，关闭则双击均为暂停/播放',
        leading: Icon(Icons.touch_app_outlined),
        setKey: SettingBoxKey.enableQuickDouble,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '自动启用字幕',
        leading: const Icon(Icons.closed_caption_outlined),
        getSubtitle: () =>
            '当前选择偏好：${SubtitlePreferenceCode.fromCode(GStorage.defaultSubtitlePreference)!.description}',
        onTap: (setState) async {
          String? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<String>(
                  title: '字幕选择偏好',
                  value: GStorage.setting.get(SettingBoxKey.subtitlePreference,
                      defaultValue: SubtitlePreference.values.first.code),
                  values: SubtitlePreference.values.map((e) {
                    return {'title': e.description, 'value': e.code};
                  }).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.subtitlePreference, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '竖屏扩大展示',
        subtitle: '小屏竖屏视频宽高比由16:9扩大至1:1（不支持收起）；横屏适配时，扩大至9:16',
        leading: Icon(Icons.expand_outlined),
        setKey: SettingBoxKey.enableVerticalExpand,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '自动全屏',
        subtitle: '视频开始播放时进入全屏',
        leading: Icon(Icons.fullscreen_outlined),
        setKey: SettingBoxKey.enableAutoEnter,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '自动退出全屏',
        subtitle: '视频结束播放时退出全屏',
        leading: Icon(Icons.fullscreen_exit_outlined),
        setKey: SettingBoxKey.enableAutoExit,
        defaultVal: true,
      ),
      SettingsModel(
          settingsType: SettingsType.sw1tch,
          title: '延长播放控件显示时间',
          subtitle: '开启后延长至30秒，便于屏幕阅读器滑动切换控件焦点',
          leading: Icon(Icons.timer_outlined),
          setKey: SettingBoxKey.enableLongShowControl,
          defaultVal: false),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '全向旋转',
        subtitle: '小屏可受重力转为临时全屏，若系统锁定旋转仍触发请关闭，关闭会影响横屏适配',
        leading: Icon(Icons.screen_rotation_alt_outlined),
        setKey: SettingBoxKey.allowRotateScreen,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '后台播放',
        subtitle: '进入后台时继续播放',
        leading: Icon(Icons.motion_photos_pause_outlined),
        setKey: SettingBoxKey.continuePlayInBackground,
        defaultVal: false,
      ),
      if (Platform.isAndroid)
        SettingsModel(
            settingsType: SettingsType.sw1tch,
            title: '后台画中画',
            subtitle: '进入后台时以小窗形式（PiP）播放',
            leading: const Icon(Icons.picture_in_picture_outlined),
            setKey: SettingBoxKey.autoPiP,
            defaultVal: false,
            onChanged: (val) {
              if (val &&
                  !GStorage.setting.get(SettingBoxKey.enableBackgroundPlay,
                      defaultValue: true)) {
                SmartDialog.showToast('建议开启后台音频服务');
              }
            }),
      if (Platform.isAndroid)
        SettingsModel(
          settingsType: SettingsType.sw1tch,
          title: '画中画不加载弹幕',
          subtitle: '当弹幕开关开启时，小窗屏蔽弹幕以获得较好的体验',
          leading: Icon(Icons.comments_disabled_outlined),
          setKey: SettingBoxKey.pipNoDanmaku,
          defaultVal: false,
        ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '全屏手势反向',
        subtitle: '默认播放器中部向上滑动进入全屏，向下退出\n开启后向下全屏，向上退出',
        leading: Icon(Icons.swap_vert_outlined),
        setKey: SettingBoxKey.fullScreenGestureReverse,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '观看人数',
        subtitle: '展示同时在看人数',
        leading: Icon(Icons.people_outlined),
        setKey: SettingBoxKey.enableOnlineTotal,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '默认全屏方向',
        leading: const Icon(Icons.open_with_outlined),
        getSubtitle: () =>
            '当前全屏方向：${FullScreenModeCode.fromCode(GStorage.defaultFullScreenMode)!.description}',
        onTap: (setState) async {
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<int>(
                  title: '默认全屏方向',
                  value: GStorage.defaultFullScreenMode,
                  values: FullScreenMode.values.map((e) {
                    return {'title': e.description, 'value': e.code};
                  }).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.fullScreenMode, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '底部进度条展示',
        leading: const Icon(Icons.border_bottom_outlined),
        getSubtitle: () =>
            '当前展示方式：${BtmProgresBehaviorCode.fromCode(GStorage.defaultBtmProgressBehavior)!.description}',
        onTap: (setState) async {
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<int>(
                  title: '底部进度条展示',
                  value: GStorage.defaultBtmProgressBehavior,
                  values: BtmProgressBehavior.values.map((e) {
                    return {'title': e.description, 'value': e.code};
                  }).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.btmProgressBehavior, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '后台音频服务',
        subtitle: '避免画中画没有播放暂停功能',
        leading: Icon(Icons.volume_up_outlined),
        setKey: SettingBoxKey.enableBackgroundPlay,
        defaultVal: true,
      ),
    ];

List<SettingsModel> get videoSettings => [
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '开启硬解',
        subtitle: '以较低功耗播放视频，若异常卡死请关闭',
        leading: Icon(Icons.flash_on_outlined),
        setKey: SettingBoxKey.enableHA,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '免登录1080P',
        subtitle: '免登录查看1080P视频',
        leading: Icon(Icons.hd_outlined),
        setKey: SettingBoxKey.p1080,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: 'B站定向流量支持',
        subtitle: '若套餐含B站定向流量，则会自动使用。可查阅运营商的流量记录确认。',
        leading: const Icon(Icons.perm_data_setting_outlined),
        getTrailing: () => Transform.scale(
          alignment: Alignment.centerRight,
          scale: 0.8,
          child: Switch(
            thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                (Set<WidgetState> states) {
              if (states.isNotEmpty && states.first == WidgetState.selected) {
                return const Icon(Icons.lock_outline_rounded);
              }
              return null;
            }),
            value: true,
            onChanged: (_) {},
          ),
        ),
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: 'CDN 设置',
        leading: Icon(MdiIcons.cloudPlusOutline),
        getSubtitle: () =>
            '当前使用：${CDNServiceCode.fromCode(GStorage.defaultCDNService)!.description}，部分 CDN 可能失效，如无法播放请尝试切换',
        onTap: (setState) async {
          String? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<String>(
                  title: 'CDN 设置',
                  value: GStorage.defaultCDNService,
                  values: CDNService.values.map((e) {
                    return {'title': e.description, 'value': e.code};
                  }).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.CDNService, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '音频不跟随 CDN 设置',
        subtitle: '直接采用备用 URL，可解决部分视频无声',
        leading: Icon(MdiIcons.musicNotePlus),
        setKey: SettingBoxKey.disableAudioCDN,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '默认画质',
        leading: const Icon(Icons.video_settings_outlined),
        getSubtitle: () =>
            '当前画质：${VideoQualityCode.fromCode(GStorage.defaultVideoQa)!.description!}',
        onTap: (setState) async {
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<int>(
                title: '默认画质',
                value: GStorage.defaultVideoQa,
                values: VideoQuality.values.reversed.map((e) {
                  return {'title': e.description, 'value': e.code};
                }).toList(),
              );
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.defaultVideoQa, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '蜂窝网络画质',
        leading: const Icon(Icons.video_settings_outlined),
        getSubtitle: () =>
            '当前画质：${VideoQualityCode.fromCode(GStorage.defaultVideoQaCellular)!.description!}',
        onTap: (setState) async {
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<int>(
                title: '蜂窝网络画质',
                value: GStorage.defaultVideoQaCellular,
                values: VideoQuality.values.reversed.map((e) {
                  return {'title': e.description, 'value': e.code};
                }).toList(),
              );
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.defaultVideoQaCellular, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '默认音质',
        leading: const Icon(Icons.music_video_outlined),
        getSubtitle: () =>
            '当前音质：${AudioQualityCode.fromCode(GStorage.defaultAudioQa)!.description!}',
        onTap: (setState) async {
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<int>(
                title: '默认音质',
                value: GStorage.defaultAudioQa,
                values: AudioQuality.values.reversed.map((e) {
                  return {'title': e.description, 'value': e.code};
                }).toList(),
              );
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.defaultAudioQa, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '蜂窝网络音质',
        leading: const Icon(Icons.music_video_outlined),
        getSubtitle: () =>
            '当前音质：${AudioQualityCode.fromCode(GStorage.defaultAudioQaCellular)!.description!}',
        onTap: (setState) async {
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<int>(
                title: '蜂窝网络音质',
                value: GStorage.defaultAudioQaCellular,
                values: AudioQuality.values.reversed.map((e) {
                  return {'title': e.description, 'value': e.code};
                }).toList(),
              );
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.defaultAudioQaCellular, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '首选解码格式',
        leading: const Icon(Icons.movie_creation_outlined),
        getSubtitle: () =>
            '首选解码格式：${VideoDecodeFormatsCode.fromCode(GStorage.defaultDecode)!.description!}，请根据设备支持情况与需求调整',
        onTap: (setState) async {
          String? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<String>(
                  title: '默认解码格式',
                  value: GStorage.defaultDecode,
                  values: VideoDecodeFormats.values.map((e) {
                    return {'title': e.description, 'value': e.code};
                  }).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.defaultDecode, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '次选解码格式',
        getSubtitle: () =>
            '非杜比视频次选：${VideoDecodeFormatsCode.fromCode(GStorage.secondDecode)!.description!}，仍无则选择首个提供的解码格式',
        leading: const Icon(Icons.swap_horizontal_circle_outlined),
        onTap: (setState) async {
          String? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<String>(
                  title: '次选解码格式',
                  value: GStorage.secondDecode,
                  values: VideoDecodeFormats.values.map((e) {
                    return {'title': e.description, 'value': e.code};
                  }).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.secondDecode, result);
            setState();
          }
        },
      ),
      if (Platform.isAndroid)
        SettingsModel(
          settingsType: SettingsType.sw1tch,
          title: '优先使用 OpenSL ES 输出音频',
          leading: Icon(Icons.speaker_outlined),
          subtitle:
              '关闭则优先使用AudioTrack输出音频（此项即mpv的--ao），若遇系统音效丢失、无声、音画不同步等问题请尝试关闭。',
          setKey: SettingBoxKey.useOpenSLES,
          defaultVal: true,
        ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '扩大缓冲区',
        leading: Icon(Icons.storage_outlined),
        subtitle: '默认缓冲区为视频4MB/直播16MB，开启后为32MB/64MB，加载时间变长',
        setKey: SettingBoxKey.expandBuffer,
        defaultVal: false,
      ),
      //video-sync
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '视频同步',
        leading: const Icon(Icons.view_timeline_outlined),
        getSubtitle: () => '当前：${GStorage.videoSync}（此项即mpv的--video-sync）',
        onTap: (setState) async {
          String? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<String>(
                  title: '视频同步',
                  value: GStorage.videoSync,
                  values: [
                    'audio',
                    'display-resample',
                    'display-resample-vdrop',
                    'display-resample-desync',
                    'display-tempo',
                    'display-vdrop',
                    'display-adrop',
                    'display-desync',
                    'desync'
                  ].map((e) {
                    return {'title': e, 'value': e};
                  }).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.videoSync, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '硬解模式',
        leading: const Icon(Icons.memory_outlined),
        getSubtitle: () => '当前：${GStorage.hardwareDecoding}（此项即mpv的--hwdec）',
        onTap: (setState) async {
          String? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<String>(
                  title: '硬解模式',
                  value: GStorage.hardwareDecoding,
                  values:
                      ['auto', 'auto-copy', 'auto-safe', 'no', 'yes'].map((e) {
                    return {'title': e, 'value': e};
                  }).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.hardwareDecoding, result);
            setState();
          }
        },
      ),
    ];

List<SettingsModel> get recommendSettings => [
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '首页推荐类型',
        leading: const Icon(Icons.model_training_outlined),
        getSubtitle: () => '当前使用「${GStorage.defaultRcmdType}端」推荐¹',
        onTap: (setState) async {
          String? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<String>(
                title: '推荐类型',
                value: GStorage.defaultRcmdType,
                values: RcmdType.values.map((e) {
                  return {'title': e.labels, 'value': e.values};
                }).toList(),
              );
            },
          );
          if (result != null) {
            if (result == 'app') {
              if (GStorage.isLogin.not) {
                SmartDialog.showToast('尚未登录，无法收到个性化推荐');
              }
            }
            GStorage.setting.put(SettingBoxKey.defaultRcmdType, result);
            SmartDialog.showToast('下次启动时生效');
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '推荐动态',
        subtitle: '是否在推荐内容中展示动态(仅app端)',
        leading: Icon(Icons.motion_photos_on_outlined),
        setKey: SettingBoxKey.enableRcmdDynamic,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '首页推荐刷新',
        subtitle: '下拉刷新时保留上次内容',
        leading: Icon(Icons.refresh),
        setKey: SettingBoxKey.enableSaveLastData,
        defaultVal: false,
        needReboot: true,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        leading: const Icon(Icons.thumb_up_outlined),
        title: '点赞率过滤',
        getSubtitle: () =>
            '过滤掉点赞数/播放量「小于${GStorage.minLikeRatioForRecommend}%」的推荐视频(仅web端)',
        onTap: (setState) async {
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<int>(
                  title: '选择点赞率（0即不过滤）',
                  value: GStorage.minLikeRatioForRecommend,
                  values: [0, 1, 2, 3, 4].map(
                    (e) {
                      return {'title': '$e %', 'value': e};
                    },
                  ).toList());
            },
          );
          if (result != null) {
            GStorage.setting
                .put(SettingBoxKey.minLikeRatioForRecommend, result);
            RecommendFilter.update();
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        leading: const Icon(Icons.title_outlined),
        title: '标题关键词过滤',
        getSubtitle: () {
          String banWordForRecommend = GStorage.banWordForRecommend;
          return banWordForRecommend.isEmpty ? "点击添加" : banWordForRecommend;
        },
        onTap: (setState) async {
          final TextEditingController textController =
              TextEditingController(text: GStorage.banWordForRecommend);
          await showDialog(
            context: Get.context!,
            builder: (context) {
              return AlertDialog(
                title: const Text(
                  '标题关键词过滤',
                  style: TextStyle(fontSize: 18),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('使用|隔开，如：尝试|测试'),
                    TextField(
                      autofocus: true,
                      controller: textController,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: 4,
                    )
                  ],
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: Get.back,
                    child: Text(
                      '取消',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                  TextButton(
                    child: const Text('保存'),
                    onPressed: () async {
                      Get.back();
                      GStorage.setting.put(
                        SettingBoxKey.banWordForRecommend,
                        textController.text,
                      );
                      setState();
                      RecommendFilter.update();
                      SmartDialog.showToast('已保存');
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '视频时长过滤',
        leading: const Icon(Icons.timelapse_outlined),
        getSubtitle: () => '过滤掉时长「小于${GStorage.minDurationForRcmd}秒」的推荐视频',
        onTap: (setState) async {
          const List<int> defDurations = [0, 30, 60, 90, 120];
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              int minDurationForRcmd = GStorage.minDurationForRcmd;
              return SelectDialog<int>(
                  title: '选择时长（0即不过滤）',
                  value: minDurationForRcmd,
                  values: [
                    ...[
                      ...defDurations,
                      if (defDurations.contains(minDurationForRcmd).not)
                        minDurationForRcmd,
                    ]..sort(),
                    -1,
                  ].map((e) {
                    if (e == -1) {
                      return {'title': '自定义', 'value': e};
                    }
                    return {'title': '$e 秒', 'value': e};
                  }).toList());
            },
          );
          if (result != null) {
            void updateDuration(int value) {
              GStorage.setting.put(SettingBoxKey.minDurationForRcmd, value);
              RecommendFilter.update();
              setState();
            }

            if (result == -1) {
              showDialog(
                context: Get.context!,
                builder: (context) {
                  String duration = '';
                  return AlertDialog(
                    title: Text(
                      '自定义时长',
                      style: TextStyle(fontSize: 18),
                    ),
                    content: TextField(
                      autofocus: true,
                      onChanged: (value) => duration = value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'\d+')),
                      ],
                      decoration: const InputDecoration(suffixText: 's'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: Get.back,
                        child: Text(
                          '取消',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Get.back();
                          updateDuration(int.tryParse(duration) ?? 0);
                        },
                        child: Text('确定'),
                      ),
                    ],
                  );
                },
              );
            } else {
              updateDuration(result);
            }
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '已关注UP豁免推荐过滤',
        subtitle: '推荐中已关注用户发布的内容不会被过滤',
        leading: const Icon(Icons.favorite_border_outlined),
        setKey: SettingBoxKey.exemptFilterForFollowed,
        defaultVal: true,
        onChanged: (_) => {RecommendFilter.update},
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '过滤器也应用于相关视频',
        subtitle: '视频详情页的相关视频也进行过滤²',
        leading: const Icon(Icons.explore_outlined),
        setKey: SettingBoxKey.applyFilterToRelatedVideos,
        defaultVal: true,
        onChanged: (_) => {RecommendFilter.update},
      ),
    ];

List<SettingsModel> get privacySettings => [
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) {
          if (GStorage.isLogin.not) {
            SmartDialog.showToast('登录后查看');
            return;
          }
          Get.toNamed('/blackListPage');
        },
        title: '黑名单管理',
        subtitle: '已拉黑用户',
        leading: const Icon(Icons.block),
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) {
          MineController.onChangeAnonymity(Get.context!);
          setState();
        },
        leading: const Icon(Icons.privacy_tip_outlined),
        getTitle: () => MineController.anonymity.value ? '退出无痕模式' : '进入无痕模式',
        getSubtitle: () => MineController.anonymity.value
            ? '已进入无痕模式，搜索、观看视频/直播不携带Cookie与CSRF，其余操作不受影响'
            : '未开启无痕模式，将使用账户信息提供完整服务',
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        onTap: (setState) {
          showDialog(
            context: Get.context!,
            builder: (context) {
              return AlertDialog(
                title: const Text('查看详情'),
                content: Text(AnonymityInterceptor.anonymityList.join('\n')),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Get.back();
                    },
                    child: const Text('确认'),
                  )
                ],
              );
            },
          );
        },
        leading: const Icon(Icons.flag_outlined),
        title: '了解无痕模式',
        subtitle: '查看无痕模式作用的API列表',
      ),
    ];

List<SettingsModel> get extraSettings => [
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '空降助手',
        subtitle: '点击配置',
        setKey: SettingBoxKey.enableSponsorBlock,
        defaultVal: false,
        onTap: () => Get.toNamed('/sponsorBlock'),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.shield_outlined),
            Icon(
              Icons.play_arrow_rounded,
              size: 15,
            ),
          ],
        ),
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '检查未读动态',
        subtitle: '点击设置检查周期(min)',
        leading: const Icon(Icons.notifications_none),
        setKey: SettingBoxKey.checkDynamic,
        defaultVal: true,
        onChanged: (value) {
          Get.find<MainController>().checkDynamic = value;
        },
        onTap: () {
          int dynamicPeriod = GStorage.dynamicPeriod;
          showDialog(
            context: Get.context!,
            builder: (context) {
              return AlertDialog(
                title: Text('检查周期', style: TextStyle(fontSize: 18)),
                content: TextFormField(
                  autofocus: true,
                  initialValue: dynamicPeriod.toString(),
                  keyboardType: TextInputType.numberWithOptions(),
                  onChanged: (value) {
                    dynamicPeriod = int.tryParse(value) ?? 5;
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'\d+')),
                  ],
                  decoration: InputDecoration(suffixText: 'min'),
                ),
                actions: [
                  TextButton(
                    onPressed: Get.back,
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Get.back();
                      GStorage.setting
                          .put(SettingBoxKey.dynamicPeriod, dynamicPeriod);
                      Get.find<MainController>().dynamicPeriod = dynamicPeriod;
                    },
                    child: Text('确定'),
                  )
                ],
              );
            },
          );
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '使用gRPC加载评论',
        subtitle: '如无法加载评论，可关闭\n非gRPC楼中楼无法定位评论、按热度/时间排序、查看对话',
        leading: SizedBox(
          height: 24,
          width: 24,
          child: Icon(MdiIcons.google, size: 20),
        ),
        setKey: SettingBoxKey.grpcReply,
        defaultVal: true,
        onChanged: (value) {
          GlobalData().grpcReply = value;
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '显示视频分段信息',
        leading: Transform.rotate(
          angle: pi / 2,
          child: Icon(MdiIcons.viewHeadline),
        ),
        setKey: SettingBoxKey.showViewPoints,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '视频页显示相关视频',
        leading: Icon(MdiIcons.motionPlayOutline),
        setKey: SettingBoxKey.showRelatedVideo,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '显示视频评论',
        leading: Icon(MdiIcons.commentTextOutline),
        setKey: SettingBoxKey.showVideoReply,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '显示番剧评论',
        leading: Icon(MdiIcons.commentTextOutline),
        setKey: SettingBoxKey.showBangumiReply,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '默认展开视频简介',
        leading: const Icon(Icons.expand_more),
        setKey: SettingBoxKey.alwaysExapndIntroPanel,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '横屏自动展开视频简介',
        leading: const Icon(Icons.expand_more),
        setKey: SettingBoxKey.exapndIntroPanelH,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '横屏分P/合集列表显示在Tab栏',
        leading: const Icon(Icons.format_list_numbered_rtl_sharp),
        setKey: SettingBoxKey.horizontalSeasonPanel,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '横屏播放页在侧栏打开UP主页',
        leading: const Icon(Icons.account_circle_outlined),
        setKey: SettingBoxKey.horizontalMemberPage,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '评论折叠行数',
        subtitle: '0行为不折叠',
        leading: const Icon(Icons.compress),
        setKey: SettingBoxKey.replyLengthLimit,
        getTrailing: () => Text(
          '${GlobalData().replyLengthLimit}行',
          style: Theme.of(Get.context!).textTheme.titleSmall,
        ),
        onTap: (setState) {
          String replyLengthLimit = GlobalData().replyLengthLimit.toString();
          showDialog(
            context: Get.context!,
            builder: (context) {
              return AlertDialog(
                title: Text('评论折叠行数', style: TextStyle(fontSize: 18)),
                content: TextFormField(
                  autofocus: true,
                  initialValue: replyLengthLimit,
                  keyboardType: TextInputType.numberWithOptions(),
                  onChanged: (value) {
                    replyLengthLimit = value;
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'\d+')),
                  ],
                  decoration: InputDecoration(suffixText: '行'),
                ),
                actions: [
                  TextButton(
                    onPressed: Get.back,
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Get.back();
                      GlobalData().replyLengthLimit =
                          int.tryParse(replyLengthLimit) ?? 6;
                      await GStorage.setting.put(
                        SettingBoxKey.replyLengthLimit,
                        GlobalData().replyLengthLimit,
                      );
                      setState();
                    },
                    child: Text('确定'),
                  )
                ],
              );
            },
          );
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '弹幕行高',
        subtitle: '默认1.6',
        setKey: SettingBoxKey.danmakuLineHeight,
        leading: const Icon(Icons.subtitles_outlined),
        getTrailing: () => Text(
          GStorage.danmakuLineHeight.toString(),
          style: Theme.of(Get.context!).textTheme.titleSmall,
        ),
        onTap: (setState) {
          String danmakuLineHeight = GStorage.danmakuLineHeight.toString();
          showDialog(
            context: Get.context!,
            builder: (context) {
              return AlertDialog(
                title: Text('弹幕行高', style: TextStyle(fontSize: 18)),
                content: TextFormField(
                  autofocus: true,
                  initialValue: danmakuLineHeight,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    danmakuLineHeight = value;
                  },
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\.]+')),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: Get.back,
                    child: Text(
                      '取消',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Get.back();
                      await GStorage.setting.put(
                        SettingBoxKey.danmakuLineHeight,
                        max(
                          1.0,
                          double.tryParse(danmakuLineHeight)?.toPrecision(1) ??
                              1.6,
                        ),
                      );
                      setState();
                    },
                    child: Text('确定'),
                  )
                ],
              );
            },
          );
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '显示视频警告/争议信息',
        leading: const Icon(Icons.warning_amber_rounded),
        setKey: SettingBoxKey.showArgueMsg,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '分P/合集：倒序播放从首集开始播放',
        subtitle: '开启则自动切换为倒序首集，否则保持当前集',
        leading: Icon(MdiIcons.sort),
        setKey: SettingBoxKey.reverseFromFirst,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '禁用 SSL 证书验证',
        subtitle: '谨慎开启，禁用容易受到中间人攻击',
        leading: Icon(Icons.security),
        needReboot: true,
        setKey: SettingBoxKey.badCertificateCallback,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '显示继续播放分P提示',
        leading: Icon(Icons.local_parking),
        setKey: SettingBoxKey.continuePlayingPart,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        enableFeedback: true,
        setKey: SettingBoxKey.feedBackEnable,
        onChanged: (value) {
          feedBack();
        },
        leading: const Icon(Icons.vibration_outlined),
        title: '震动反馈',
        subtitle: '请确定手机设置中已开启震动反馈',
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '大家都在搜',
        subtitle: '是否展示「大家都在搜」',
        leading: Icon(Icons.data_thresholding_outlined),
        setKey: SettingBoxKey.enableHotKey,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '搜索默认词',
        subtitle: '是否展示搜索框默认词',
        leading: const Icon(Icons.whatshot_outlined),
        setKey: SettingBoxKey.enableSearchWord,
        defaultVal: true,
        onChanged: (val) {
          Get.find<HomeController>().defaultSearch.value = '';
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '快速收藏',
        subtitle: '点按收藏至默认，长按选择文件夹',
        leading: Icon(Icons.bookmark_add_outlined),
        setKey: SettingBoxKey.enableQuickFav,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '评论区搜索关键词',
        subtitle: '展示评论区搜索关键词',
        leading: Icon(Icons.search_outlined),
        setKey: SettingBoxKey.enableWordRe,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '启用AI总结',
        subtitle: '视频详情页开启AI总结',
        leading: Icon(Icons.engineering_outlined),
        setKey: SettingBoxKey.enableAi,
        defaultVal: true,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '消息页禁用"收到的赞"功能',
        subtitle: '禁止打开入口，降低网络社交依赖',
        leading: Icon(Icons.beach_access_outlined),
        setKey: SettingBoxKey.disableLikeMsg,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '默认展示评论区',
        subtitle: '在视频详情页默认切换至评论区页（仅Tab型布局）',
        leading: Icon(Icons.mode_comment_outlined),
        setKey: SettingBoxKey.defaultShowComment,
        defaultVal: false,
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '评论展示',
        setKey: SettingBoxKey.replySortType,
        leading: const Icon(Icons.whatshot_outlined),
        getSubtitle: () =>
            '当前优先展示「${ReplySortType.values[GStorage.defaultReplySort].titles}」',
        onTap: (setState) async {
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<int>(
                title: '评论展示',
                value: GStorage.defaultReplySort,
                values: ReplySortType.values.map((e) {
                  return {'title': e.titles, 'value': e.index};
                }).toList(),
              );
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.replySortType, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '动态展示',
        setKey: SettingBoxKey.defaultDynamicType,
        leading: const Icon(Icons.dynamic_feed_outlined),
        getSubtitle: () =>
            '当前优先展示「${DynamicsType.values[GStorage.defaultDynamicType].labels}」',
        onTap: (setState) async {
          int? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<int>(
                  title: '动态展示',
                  value: GStorage.defaultDynamicType,
                  values: DynamicsType.values.sublist(0, 4).map((e) {
                    return {'title': e.labels, 'value': e.index};
                  }).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.defaultDynamicType, result);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.normal,
        title: '用户页默认展示TAB',
        setKey: SettingBoxKey.memberTab,
        leading: const Icon(Icons.tab),
        getSubtitle: () => '当前优先展示「${GStorage.memberTab.title}」',
        onTap: (setState) async {
          MemberTabType? result = await showDialog(
            context: Get.context!,
            builder: (context) {
              return SelectDialog<MemberTabType>(
                  title: '用户页默认展示TAB',
                  value: GStorage.memberTab,
                  values: MemberTabType.values.map((e) {
                    return {'title': e.title, 'value': e};
                  }).toList());
            },
          );
          if (result != null) {
            GStorage.setting.put(SettingBoxKey.memberTab, result.index);
            setState();
          }
        },
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        onTap: () {
          String systemProxyHost = GStorage.defaultSystemProxyHost;
          String systemProxyPort = GStorage.defaultSystemProxyPort;

          showDialog(
            context: Get.context!,
            builder: (context) {
              return AlertDialog(
                title: const Text('设置代理'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
                    TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: systemProxyHost != ''
                            ? systemProxyHost
                            : '请输入Host，使用 . 分割',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        hintText: systemProxyHost,
                      ),
                      onChanged: (e) {
                        systemProxyHost = e;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        labelText:
                            systemProxyPort != '' ? systemProxyPort : '请输入Port',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        hintText: systemProxyPort,
                      ),
                      onChanged: (e) {
                        systemProxyPort = e;
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Get.back();
                    },
                    child: Text(
                      '取消',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Get.back();
                      GStorage.setting
                          .put(SettingBoxKey.systemProxyHost, systemProxyHost);
                      GStorage.setting
                          .put(SettingBoxKey.systemProxyPort, systemProxyPort);
                    },
                    child: const Text('确认'),
                  )
                ],
              );
            },
          );
        },
        leading: const Icon(Icons.airplane_ticket_outlined),
        title: '设置代理',
        subtitle: '设置代理 host:port',
        setKey: SettingBoxKey.enableSystemProxy,
      ),
      SettingsModel(
        settingsType: SettingsType.sw1tch,
        title: '自动清除缓存',
        subtitle: '每次启动时清除缓存',
        leading: Icon(Icons.auto_delete_outlined),
        setKey: SettingBoxKey.autoClearCache,
        defaultVal: false,
      ),
    ];
