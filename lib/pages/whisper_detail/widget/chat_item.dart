import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/common/widgets/network_img_layer.dart';
import 'package:PiliPalaX/utils/utils.dart';
import 'package:PiliPalaX/utils/storage.dart';

import '../../../http/search.dart';

enum MsgType {
  invalid(value: 0, label: "空空的~"),
  text(value: 1, label: "文本消息"),
  pic(value: 2, label: "图片消息"),
  audio(value: 3, label: "语音消息"),
  share(value: 4, label: "分享消息"),
  revoke(value: 5, label: "撤回消息"),
  custom_face(value: 6, label: "自定义表情"),
  share_v2(value: 7, label: "分享v2消息"),
  sys_cancel(value: 8, label: "系统撤销"),
  mini_program(value: 9, label: "小程序"),
  notify_msg(value: 10, label: "业务通知"),
  archive_card(value: 11, label: "投稿卡片"),
  article_card(value: 12, label: "专栏卡片"),
  pic_card(value: 13, label: "图片卡片"),
  common_share(value: 14, label: "异形卡片"),
  auto_reply_push(value: 16, label: "自动回复推送"),
  notify_text(value: 18, label: "文本提示");

  final int value;
  final String label;
  const MsgType({required this.value, required this.label});
  static MsgType parse(int value) {
    return MsgType.values
        .firstWhere((e) => e.value == value, orElse: () => MsgType.invalid);
  }
}

class ChatItem extends StatelessWidget {
  final dynamic item;
  final List? eInfos;

  const ChatItem({
    super.key,
    this.item,
    this.eInfos,
  });

  @override
  Widget build(BuildContext context) {
    bool isOwner =
        item.senderUid == GStorage.userInfo.get('userInfoCache')?.mid;

    bool isPic = item.msgType == MsgType.pic.value; // 图片
    // bool isText = item.msgType == MsgType.text.value; // 文本
    // bool isArchive = item.msgType == 11; // 投稿
    // bool isArticle = item.msgType == 12; // 专栏
    bool isRevoke = item.msgType == MsgType.revoke.value; // 撤回消息
    // bool isShareV2 = item.msgType == MsgType.share_v2.value;
    bool isSystem = item.msgType == MsgType.notify_text.value ||
        item.msgType == MsgType.notify_msg.value ||
        item.msgType == MsgType.pic_card.value ||
        item.msgType == MsgType.auto_reply_push.value;
    dynamic content = item.content ?? '';
    Color textColor(BuildContext context) {
      return isOwner
          ? Theme.of(context).colorScheme.onPrimary
          : Theme.of(context).colorScheme.onSecondaryContainer;
    }

    Widget richTextMessage(BuildContext context) {
      var text = content['content'];
      if (eInfos != null) {
        final List<InlineSpan> children = [];
        Map<String, String> emojiMap = {};
        for (var e in eInfos!) {
          emojiMap[e['text']] = e['url'];
        }
        text.splitMapJoin(
          RegExp(r"\[[^\[\]]+\]"),
          onMatch: (Match match) {
            final String emojiKey = match[0]!;
            if (emojiMap.containsKey(emojiKey)) {
              children.add(WidgetSpan(
                child: NetworkImgLayer(
                  width: 18,
                  height: 18,
                  src: emojiMap[emojiKey]!,
                ),
              ));
            } else {
              children.add(TextSpan(
                text: emojiKey,
                style: TextStyle(
                  color: textColor(context),
                  letterSpacing: 0.6,
                  height: 1.5,
                ),
              ));
            }
            return '';
          },
          onNonMatch: (String text) {
            children.add(TextSpan(
                text: text,
                style: TextStyle(
                  color: textColor(context),
                  letterSpacing: 0.6,
                  height: 1.5,
                )));
            return '';
          },
        );
        return SelectableText.rich(
          TextSpan(
            children: children,
          ),
        );
      } else {
        return SelectableText(
          text,
          style: TextStyle(
            letterSpacing: 0.6,
            color: textColor(context),
            height: 1.5,
          ),
        );
      }
    }

    Widget messageContent(BuildContext context) {
      switch (MsgType.parse(item.msgType)) {
        case MsgType.notify_msg:
          return SystemNotice(item: item);
        case MsgType.pic_card:
          return SystemNotice2(item: item);
        case MsgType.notify_text:
          return Text(
            jsonDecode(content['content'])
                .map((m) => m['text'] as String)
                .join("\n"),
            textAlign: TextAlign.center,
            style: TextStyle(
              letterSpacing: 0.6,
              height: 5,
              color:
                  Theme.of(context).colorScheme.outline.withOpacity(0.8),
            ),
          );
        case MsgType.text:
          return richTextMessage(context);
        case MsgType.pic:
          return NetworkImgLayer(
            width: 220,
            height: 220 * content['height'] / content['width'],
            src: content['url'],
          );
        case MsgType.share_v2:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  SmartDialog.showLoading();
                  var bvid = content["bvid"];
                  final int cid = await SearchHttp.ab2c(bvid: bvid);
                  final String heroTag = Utils.makeHeroTag(bvid);
                  SmartDialog.dismiss<dynamic>().then(
                    (e) => Get.toNamed<dynamic>('/video?bvid=$bvid&cid=$cid',
                        arguments: <String, String?>{
                          'pic': content['thumb'],
                          'heroTag': heroTag,
                        }),
                  );
                },
                child: NetworkImgLayer(
                  width: 220,
                  height: 220 * 9 / 16,
                  src: content['thumb'],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                content['title'] ?? "",
                style: TextStyle(
                  letterSpacing: 0.6,
                  height: 1.5,
                  color: textColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                content['author'] ?? "",
                style: TextStyle(
                  letterSpacing: 0.6,
                  height: 1.5,
                  color: textColor(context).withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          );
        case MsgType.archive_card:
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  try {
                    SmartDialog.showLoading();
                    var bvid = content["bvid"];
                    final int cid = await SearchHttp.ab2c(bvid: bvid);
                    final String heroTag = Utils.makeHeroTag(bvid);
                    SmartDialog.dismiss<dynamic>().then(
                      (e) => Get.toNamed<dynamic>('/video?bvid=$bvid&cid=$cid',
                          arguments: <String, String?>{
                            'pic': content['thumb'],
                            'heroTag': heroTag,
                          }),
                    );
                  } catch (err) {
                    SmartDialog.dismiss();
                    SmartDialog.showToast(err.toString());
                  }
                },
                child: NetworkImgLayer(
                  width: 220,
                  height: 220 * 9 / 16,
                  src: content['cover'],
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                content['title'],
                style: TextStyle(
                  letterSpacing: 0.6,
                  height: 1.5,
                  color: textColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                Utils.timeFormat(content['times']),
                style: TextStyle(
                  letterSpacing: 0.6,
                  height: 1.5,
                  color: textColor(context).withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          );
        case MsgType.auto_reply_push:
          return Container(
              constraints: const BoxConstraints(
                maxWidth: 300.0, // 设置最大宽度为200.0
              ),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withOpacity(0.4),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(6),
                  bottomRight: Radius.circular(16),
                ),
              ),
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content['main_title'],
                    style: TextStyle(
                      letterSpacing: 0.6,
                      height: 1.5,
                      color: textColor(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  for (var i in content['sub_cards']) ...<Widget>[
                    const SizedBox(height: 6),
                    GestureDetector(
                        onTap: () async {
                          RegExp bvRegex = RegExp(r'BV[0-9A-Za-z]{10}',
                              caseSensitive: false);
                          Iterable<Match> matches =
                              bvRegex.allMatches(i['jump_url']);
                          if (matches.isNotEmpty) {
                            Match match = matches.first;
                            String bvid = match.group(0)!;
                            try {
                              SmartDialog.showLoading();
                              final int cid = await SearchHttp.ab2c(bvid: bvid);
                              final String heroTag = Utils.makeHeroTag(bvid);
                              SmartDialog.dismiss<dynamic>().then(
                                (e) => Get.toNamed<dynamic>(
                                    '/video?bvid=$bvid&cid=$cid',
                                    arguments: <String, String?>{
                                      'pic': i['cover_url'],
                                      'heroTag': heroTag,
                                    }),
                              );
                            } catch (err) {
                              SmartDialog.dismiss();
                              SmartDialog.showToast(err.toString());
                            }
                          } else {
                            SmartDialog.showToast('未匹配到 BV 号');
                            Get.toNamed('/webviewnew',
                                arguments: {'url': i['jump_url']});
                          }
                        },
                        child: Row(
                          children: [
                            NetworkImgLayer(
                              width: 130,
                              height: 130 * 9 / 16,
                              src: i['cover_url'],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i['field1'],
                                  maxLines: 2,
                                  style: TextStyle(
                                    letterSpacing: 0.6,
                                    height: 1.5,
                                    color: textColor(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  i['field2'],
                                  style: TextStyle(
                                    letterSpacing: 0.6,
                                    height: 1.5,
                                    color: textColor(context)
                                        .withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  i['field3'],
                                  style: TextStyle(
                                    letterSpacing: 0.6,
                                    height: 1.5,
                                    color: textColor(context)
                                        .withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )),
                          ],
                        )),
                  ],
                ],
              ));
        default:
          return Text(
            content != null && content != ''
                ? (content['content'] ?? content.toString())
                : '不支持的消息类型',
            style: TextStyle(
              letterSpacing: 0.6,
              height: 1.5,
              color: textColor(context),
              fontWeight: FontWeight.bold,
            ),
          );
      }
    }

    return isSystem
        ? messageContent(context)
        : isRevoke
            ? const SizedBox()
            : Row(
                children: [
                  if (!isOwner) const SizedBox(width: 12),
                  if (isOwner) const Spacer(),
                  Container(
                    constraints: const BoxConstraints(
                      maxWidth: 300.0, // 设置最大宽度为200.0
                    ),
                    decoration: BoxDecoration(
                      color: isOwner
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isOwner ? 16 : 6),
                        bottomRight: Radius.circular(isOwner ? 6 : 16),
                      ),
                    ),
                    margin: const EdgeInsets.only(top: 12),
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: 6,
                      left: isPic ? 8 : 12,
                      right: isPic ? 8 : 12,
                    ),
                    child: Column(
                      crossAxisAlignment: isOwner
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        messageContent(context),
                        SizedBox(height: isPic ? 7 : 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              Utils.dateFormat(item.timestamp),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall!
                                  .copyWith(
                                      color: isOwner
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                              .withOpacity(0.8)
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer
                                              .withOpacity(0.8)),
                            ),
                            item.msgStatus == 1
                                ? Text(
                                    '  已撤回',
                                    style:
                                        Theme.of(context).textTheme.labelSmall!,
                                  )
                                : const SizedBox()
                          ],
                        )
                      ],
                    ),
                  ),
                  if (!isOwner) const Spacer(),
                  if (isOwner) const SizedBox(width: 12),
                ],
              );
  }
}

class SystemNotice extends StatelessWidget {
  final dynamic item;
  const SystemNotice({super.key, this.item});

  @override
  Widget build(BuildContext context) {
    Map content = item.content ?? '';
    return Row(
      children: [
        const SizedBox(width: 12),
        Container(
          constraints: const BoxConstraints(
            maxWidth: 300.0, // 设置最大宽度为200.0
          ),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withOpacity(0.4),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(16),
            ),
          ),
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(content['title'],
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.bold)),
              Text(
                Utils.dateFormat(item.timestamp),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall!
                    .copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              Divider(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.05),
              ),
              SelectableText(
                content['text'],
              )
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class SystemNotice2 extends StatelessWidget {
  final dynamic item;
  const SystemNotice2({super.key, this.item});

  @override
  Widget build(BuildContext context) {
    Map content = item.content ?? '';
    return Row(
      children: [
        const SizedBox(width: 12),
        Container(
          constraints: const BoxConstraints(
            maxWidth: 300.0, // 设置最大宽度为200.0
          ),
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.only(bottom: 6),
          child: NetworkImgLayer(
            width: 320,
            height: 150,
            src: content['pic_url'],
          ),
        ),
        const Spacer(),
      ],
    );
  }
}
