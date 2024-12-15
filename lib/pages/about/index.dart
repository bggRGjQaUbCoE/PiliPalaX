import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:PiliPalaX/models/github/latest.dart';
import 'package:PiliPalaX/pages/setting/controller.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:PiliPalaX/utils/utils.dart';
import '../../utils/cache_manage.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final AboutController _aboutController = Get.put(AboutController());
  static const String _sourceCodeUrl =
      'https://github.com/bggRGjQaUbCoE/PiliPalaX';
  static const String _originSourceCodeUrl =
      'https://github.com/guozhigq/pilipala';
  static const String _upstreamUrl = 'https://github.com/orz12/PiliPalaX';

  @override
  void initState() {
    super.initState();
    // 读取缓存占用
    getCacheSize();
  }

  Future<void> getCacheSize() async {
    final res = await CacheManage().loadApplicationCache();
    _aboutController.cacheSize.value = res;
  }

  @override
  Widget build(BuildContext context) {
    final Color outline = Theme.of(context).colorScheme.outline;
    TextStyle subTitleStyle =
        TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline);
    return Scaffold(
      appBar: AppBar(title: Text('关于')),
      body: ListView(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: ExcludeSemantics(
                child: Image.asset(
              'assets/images/logo/logo_android_2.png',
            )),
          ),
          ListTile(
            title: Text('PiliPalaX',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(height: 2)),
            subtitle: Row(children: [
              const Spacer(),
              Text(
                '使用Flutter开发的B站第三方客户端',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
                semanticsLabel: '与你一起，发现不一样的世界',
              ),
              const Icon(
                Icons.accessibility_new,
                semanticLabel: "无障碍适配",
                size: 18,
              ),
              const Spacer(),
            ]),
          ),
          Obx(
            () => ListTile(
              // onTap: () => _aboutController.tapOnVersion(),
              title: const Text('当前版本'),
              leading: const Icon(Icons.commit_outlined),
              trailing: Text(_aboutController.currentVersion.value,
                  style: subTitleStyle),
            ),
          ),
          // Obx(
          //   () => ListTile(
          //     onTap: () => _aboutController.onUpdate(),
          //     title: const Text('最新版本'),
          //     leading: const Icon(Icons.flag_outlined),
          //     trailing: Text(
          //       _aboutController.isLoading.value
          //           ? '正在获取'
          //           : _aboutController.isUpdate.value
          //               ? '有新版本  ❤️${_aboutController.remoteVersion.value}'
          //               : '当前已是最新版',
          //       style: subTitleStyle,
          //     ),
          //   ),
          // ),
          // ListTile(
          //   onTap: () {},
          //   title: const Text('更新日志'),
          //   trailing: const Icon(
          //     Icons.arrow_forward,
          //     size: 16,
          //   ),
          // ),
          Divider(
            thickness: 1,
            height: 30,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          ListTile(
            onTap: () => Utils.launchURL(_sourceCodeUrl),
            leading: const Icon(Icons.code),
            title: const Text('Source Code'),
            subtitle: Text(_sourceCodeUrl, style: subTitleStyle),
          ),
          ListTile(
            onTap: () => Utils.launchURL(_originSourceCodeUrl),
            leading: const Icon(Icons.code),
            title: const Text('Origin'),
            subtitle: Text(
              _originSourceCodeUrl,
              style: subTitleStyle,
            ),
          ),
          ListTile(
            onTap: () => Utils.launchURL(_upstreamUrl),
            leading: const Icon(Icons.code),
            title: const Text('Upstream'),
            subtitle: Text(
              _upstreamUrl,
              style: subTitleStyle,
            ),
          ),
          ListTile(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return SimpleDialog(
                    clipBehavior: Clip.hardEdge,
                    title: const Text('问题反馈'),
                    children: [
                      ListTile(
                        title: const Text('GitHub Issue'),
                        onTap: () => Utils.launchURL('$_sourceCodeUrl/issues'),
                      ),
                    ],
                  );
                },
              );
            },
            leading: const Icon(Icons.feedback_outlined),
            title: const Text('问题反馈'),
            trailing: Icon(
              Icons.arrow_forward,
              size: 16,
              color: outline,
            ),
          ),
          ListTile(
            onTap: () {
              Get.toNamed('/logs');
            },
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('错误日志'),
            trailing: Icon(Icons.arrow_forward, size: 16, color: outline),
          ),
          ListTile(
            onTap: () async {
              await CacheManage().clearCacheAll(context);
              getCacheSize();
            },
            leading: const Icon(Icons.delete_outline),
            title: const Text('清除缓存'),
            subtitle: Obx(
              () => Text(
                '图片及网络缓存 ${_aboutController.cacheSize.value}',
                style: subTitleStyle,
              ),
            ),
          ),
          ListTile(
              title: const Text('导入/导出设置'),
              dense: false,
              leading: const Icon(Icons.import_export_outlined),
              onTap: () async {
                await showDialog(
                  context: context,
                  builder: (context) {
                    return SimpleDialog(
                      clipBehavior: Clip.hardEdge,
                      title: const Text('导入/导出设置'),
                      children: [
                        ListTile(
                          title: const Text('导出设置至剪贴板'),
                          onTap: () async {
                            Get.back();
                            String data = await GStorage.exportAllSettings();
                            Clipboard.setData(ClipboardData(text: data));
                            SmartDialog.showToast('已复制到剪贴板');
                          },
                        ),
                        ListTile(
                          title: const Text('从剪贴板导入设置'),
                          onTap: () async {
                            Get.back();
                            ClipboardData? data =
                                await Clipboard.getData('text/plain');
                            if (data == null ||
                                data.text == null ||
                                data.text!.isEmpty) {
                              SmartDialog.showToast('剪贴板无数据');
                              return;
                            }
                            if (!context.mounted) return;
                            await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('是否导入如下设置？'),
                                  content: Text(data.text!),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Get.back();
                                      },
                                      child: const Text('取消'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        Get.back();
                                        try {
                                          await GStorage.importAllSettings(
                                              data.text!);
                                          SmartDialog.showToast('导入成功');
                                        } catch (e) {
                                          SmartDialog.showToast('导入失败：$e');
                                        }
                                      },
                                      child: const Text('确定'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              }),
          ListTile(
            title: const Text('重置所有设置'),
            leading: const Icon(Icons.settings_backup_restore_outlined),
            onTap: () async {
              await showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('重置所有设置'),
                    content: const Text('是否重置所有设置？'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Get.back();
                        },
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Get.back();
                          await Future.wait([
                            GStorage.setting.clear(),
                            GStorage.video.clear(),
                          ]);
                          SmartDialog.showToast('重置成功');
                        },
                        child: const Text('重置可导出的设置'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Get.back();
                          await Future.wait([
                            GStorage.userInfo.clear(),
                            GStorage.setting.clear(),
                            GStorage.localCache.clear(),
                            GStorage.video.clear(),
                            GStorage.historyWord.clear(),
                          ]);
                          SmartDialog.showToast('重置成功');
                        },
                        child: const Text('重置所有数据（含登录信息）'),
                      ),
                    ],
                  );
                },
              );
            },
          )
        ],
      ),
    );
  }
}

class AboutController extends GetxController {
  Box setting = GStorage.setting;
  final SettingController settingController = Get.put(SettingController());
  RxString currentVersion = ''.obs;
  RxString remoteVersion = ''.obs;
  LatestDataModel? remoteAppInfo;
  RxBool isUpdate = true.obs;
  RxBool isLoading = true.obs;
  LatestDataModel? data;
  RxString cacheSize = ''.obs;

  @override
  void onInit() {
    super.onInit();
    // init();
    // 获取当前版本
    getCurrentApp();
    // 获取最新的版本
    // getRemoteApp();
  }

  // 获取设备信息
  // Future init() async {
  //   DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  //   if (Platform.isAndroid) {
  //     AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
  //     debugPrint(androidInfo.supportedAbis);
  //   } else if (Platform.isIOS) {
  //     IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
  //     debugPrint(iosInfo);
  //   }
  // }

  // 获取当前版本
  Future getCurrentApp() async {
    var currentInfo = await PackageInfo.fromPlatform();
    String buildNumber = currentInfo.buildNumber;
    currentVersion.value = "${currentInfo.version}+$buildNumber";
  }

  // // 获取远程版本
  // Future getRemoteApp() async {
  //   var result = await Request().get(Api.latestApp, extra: {'ua': 'pc'});
  //   if (result.data.isEmpty) {
  //     SmartDialog.showToast('检查更新失败，github接口未返回数据，请检查网络');
  //     return false;
  //   } else if (result.data[0] == null) {
  //     SmartDialog.showToast('检查更新失败，github接口返回如下内容：\n${result.data}');
  //     return false;
  //   }
  //   data = LatestDataModel.fromJson(result.data[0]);
  //   remoteAppInfo = data;
  //   remoteVersion.value = data!.tagName!;
  //   isUpdate.value =
  //       Utils.needUpdate(currentVersion.value, remoteVersion.value);
  //   isLoading.value = false;
  // }
}
