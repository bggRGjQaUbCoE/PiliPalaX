import 'package:PiliPlus/http/index.dart';
import 'package:PiliPlus/models/dynamics/result.dart';
import 'package:PiliPlus/pages/member/view.dart' show radioWidget;
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/common/widgets/network_img_layer.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:share_plus/share_plus.dart';

import '../../../http/constants.dart';
import '../controller.dart';

class AuthorPanel extends StatelessWidget {
  final dynamic item;
  final Function? addBannedList;
  final String? source;
  final Function? onRemove;
  const AuthorPanel({
    super.key,
    required this.item,
    this.addBannedList,
    this.source,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    String heroTag = Utils.makeHeroTag(item.modules.moduleAuthor.mid);
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            // 番剧
            if (item.modules.moduleAuthor.type == 'AUTHOR_TYPE_PGC' ||
                item.modules.moduleAuthor.type == 'AUTHOR_TYPE_UGC_SEASON') {
              return;
            }
            feedBack();
            Get.toNamed(
              '/member?mid=${item.modules.moduleAuthor.mid}',
              arguments: {
                'face': item.modules.moduleAuthor.face,
                'heroTag': heroTag
              },
            );
          },
          child: Hero(
            tag: heroTag,
            child: NetworkImgLayer(
              width: 40,
              height: 40,
              type: 'avatar',
              src: item.modules.moduleAuthor.face,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  item.modules.moduleAuthor.name,
                  // semanticsLabel: "UP主：${item.modules.moduleAuthor.name}",
                  style: TextStyle(
                    color: item.modules.moduleAuthor!.vip != null &&
                            item.modules.moduleAuthor!.vip['status'] > 0 &&
                            item.modules.moduleAuthor!.vip['type'] == 2
                        ? context.vipColor
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: Theme.of(context).textTheme.titleSmall!.fontSize,
                  ),
                ),
              ],
            ),
            DefaultTextStyle.merge(
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: Theme.of(context).textTheme.labelSmall!.fontSize,
              ),
              child: Row(
                children: [
                  Text(item is ItemOrigModel
                      ? Utils.dateFormat(item.modules.moduleAuthor.pubTs)
                      : item.modules.moduleAuthor.pubTime),
                  if (item.modules.moduleAuthor.pubTime != '' &&
                      item.modules.moduleAuthor.pubAction != '')
                    const Text(' '),
                  Text(item.modules.moduleAuthor.pubAction),
                ],
              ),
            )
          ],
        ),
        const Spacer(),
        if (source != 'detail' && item.modules?.moduleTag?.text != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: Border.all(
                width: 1.25,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            child: Text(
              item.modules.moduleTag.text,
              style: TextStyle(
                height: 1,
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
              strutStyle: const StrutStyle(
                leading: 0,
                height: 1,
                fontSize: 12,
              ),
            ),
          ),
        SizedBox(
          width: 32,
          height: 32,
          child: IconButton(
            tooltip: '更多',
            style: ButtonStyle(
              padding: WidgetStateProperty.all(EdgeInsets.zero),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                useRootNavigator: true,
                isScrollControlled: true,
                builder: (context) {
                  return morePanel(context);
                },
              );
            },
            icon: const Icon(Icons.more_vert_outlined, size: 18),
          ),
        ),
      ],
    );
  }

  Widget morePanel(context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      // clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: Get.back,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            child: Container(
              height: 35,
              padding: const EdgeInsets.only(bottom: 2),
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: const BorderRadius.all(Radius.circular(3))),
                ),
              ),
            ),
          ),
          if (item.type == 'DYNAMIC_TYPE_AV')
            ListTile(
              onTap: () async {
                try {
                  String bvid = item.modules.moduleDynamic.major.archive.bvid;
                  var res = await UserHttp.toViewLater(bvid: bvid);
                  SmartDialog.showToast(res['msg']);
                  Get.back();
                } catch (err) {
                  SmartDialog.showToast('出错了：${err.toString()}');
                }
              },
              minLeadingWidth: 0,
              // dense: true,
              leading: const Icon(Icons.watch_later_outlined, size: 19),
              title: Text(
                '稍后再看',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ListTile(
            title: Text(
              '分享动态',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            leading: const Icon(Icons.share_outlined, size: 19),
            onTap: () {
              Get.back();
              Share.share('${HttpString.dynamicShareBaseUrl}/${item.idStr}');
            },
            minLeadingWidth: 0,
          ),
          ListTile(
            title: Text(
              '临时屏蔽：${item.modules.moduleAuthor.name}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            leading: const Icon(Icons.visibility_off_outlined, size: 19),
            onTap: () {
              Get.back();
              DynamicsController dynamicsController =
                  Get.find<DynamicsController>();
              dynamicsController.tempBannedList
                  .add(item.modules.moduleAuthor.mid);
              SmartDialog.showToast(
                  '已临时屏蔽${item.modules.moduleAuthor.name}(${item.modules.moduleAuthor.mid})，重启恢复');
            },
            minLeadingWidth: 0,
          ),
          if (item.modules.moduleAuthor.mid ==
                  GStorage.userInfo.get('userInfoCache')?.mid &&
              onRemove != null)
            ListTile(
              onTap: () async {
                Get.back();
                showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                          title: const Text('确定删除该动态?'),
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
                                onRemove?.call(item.idStr);
                              },
                              child: const Text('确定'),
                            ),
                          ],
                        ));
              },
              minLeadingWidth: 0,
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error, size: 19),
              title: Text('删除',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(color: Theme.of(context).colorScheme.error)),
            ),
          if (GStorage.isLogin)
            ListTile(
              title: Text(
                '举报',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
              leading: Icon(
                Icons.error_outline_outlined,
                size: 19,
                color: Theme.of(context).colorScheme.error,
              ),
              onTap: () {
                Get.back();
                _showReportDynDialog(context);
              },
              minLeadingWidth: 0,
            ),
          const Divider(thickness: 0.1, height: 1),
          ListTile(
            onTap: Get.back,
            minLeadingWidth: 0,
            dense: true,
            title: Text(
              '取消',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDynDialog(context) {
    _ReportReasonType? reasonType;
    String? reasonDesc;
    late final key = GlobalKey<FormState>();
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              '举报动态',
              style: TextStyle(fontSize: 18),
            ),
            titlePadding: const EdgeInsets.only(left: 22, top: 16, right: 22),
            contentPadding: const EdgeInsets.only(top: 5),
            actionsPadding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 10),
            content: Builder(builder: (context) {
              return SingleChildScrollView(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 22,
                          right: 22,
                          bottom: 5,
                        ),
                        child: const Text('请选择举报的理由：'),
                      ),
                      ...List.generate(
                        _ReportReasonType.values.length ~/ 2,
                        (index) => Row(
                          children: List.generate(2, (index2) {
                            return Expanded(
                              child: radioWidget<_ReportReasonType>(
                                paddingStart: index2 == 0 ? 10 : 0,
                                value: _ReportReasonType
                                    .values[index * 2 + index2],
                                groupValue: reasonType,
                                title: _ReportReasonType
                                    .values[index * 2 + index2].title,
                                onChanged: (value) {
                                  reasonType = value;
                                  if (context.mounted) {
                                    (context as Element?)?.markNeedsBuild();
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                      ),
                      if (reasonType == _ReportReasonType.s10) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: const Text('为帮助审核人员更快处理，请补充问题类型和出现位置等详细信息'),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 22,
                            top: 5,
                            right: 22,
                          ),
                          child: Form(
                            key: key,
                            child: TextFormField(
                              minLines: 4,
                              maxLines: 4,
                              initialValue: reasonDesc,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(60),
                              ],
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.all(10),
                              ),
                              onChanged: (value) => reasonDesc = value,
                              validator: (value) {
                                if (value.isNullOrEmpty) {
                                  return '理由不能为空';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
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
                  if (reasonType == null) {
                    return;
                  }
                  if (reasonType == _ReportReasonType.s10 &&
                      key.currentState?.validate() != true) {
                    return;
                  }
                  try {
                    SmartDialog.showLoading();
                    Request()
                        .post(
                      'https://api.bilibili.com/x/dynamic/feed/dynamic_report/add',
                      queryParameters: {
                        'csrf': await Request.getCsrf(),
                      },
                      data: {
                        "accused_uid": item.modules.moduleAuthor.mid,
                        "dynamic_id": item.idStr,
                        "reason_type": reasonType!.code,
                        "reason_desc": reasonType == _ReportReasonType.s10
                            ? reasonDesc
                            : null,
                      },
                      options: Options(
                        contentType: Headers.formUrlEncodedContentType,
                      ),
                    )
                        .then((res) {
                      SmartDialog.dismiss();
                      if (res.data['code'] == 0) {
                        Get.back();
                        SmartDialog.showToast('举报成功');
                      } else {
                        SmartDialog.showToast(res.data['message']);
                      }
                    });
                  } catch (e) {
                    debugPrint('failed to report dyn: $e');
                  }
                },
                child: const Text('确定'),
              ),
            ],
          );
        });
  }
}

enum _ReportReasonType { s1, s2, s3, s4, s5, s6, s7, s8, s9, s10 }

extension _ReportReasonTypeExt on _ReportReasonType {
  String get title => [
        '垃圾广告',
        '引战',
        '色情',
        '人身攻击',
        '违法信息',
        '涉政谣言',
        '涉社会事件谣言',
        '虚假不实信息',
        '违法信息外链',
        '其他',
      ][index];
  int get code => [4, 8, 1, 5, 3, 9, 10, 12, 13, 0][index];
}
