import 'package:PiliPalaX/grpc/app/main/community/reply/v1/reply.pb.dart';
import 'package:PiliPalaX/http/loading_state.dart';
import 'package:PiliPalaX/models/common/reply_type.dart';
import 'package:PiliPalaX/models/video/reply/data.dart';
import 'package:PiliPalaX/pages/common/common_controller.dart';
import 'package:PiliPalaX/pages/video/detail/reply_new/reply_page.dart';
import 'package:PiliPalaX/utils/extension.dart';
import 'package:PiliPalaX/utils/global_data.dart';
import 'package:PiliPalaX/utils/utils.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPalaX/models/common/reply_sort_type.dart';
import 'package:PiliPalaX/models/video/reply/item.dart';
import 'package:PiliPalaX/utils/feed_back.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:get/get_navigation/src/dialog/dialog_route.dart';

abstract class ReplyController extends CommonController {
  String nextOffset = '';
  bool isLoadingMore = false;
  RxInt count = (-1).obs;

  ReplySortType sortType = ReplySortType.time;
  RxString sortTypeTitle = ReplySortType.time.titles.obs;
  RxString sortTypeLabel = ReplySortType.time.labels.obs;

  late final savedReplies = {};

  late bool isLogin = GStorage.userInfo.get('userInfoCache') != null;

  CursorReply? cursor;
  late Mode mode = Mode.MAIN_LIST_HOT;
  bool hasUpTop = false;

  @override
  void onInit() {
    super.onInit();
    int defaultReplySortIndex = GStorage.setting
        .get(SettingBoxKey.replySortType, defaultValue: 1) as int;
    if (defaultReplySortIndex == 2) {
      GStorage.setting.put(SettingBoxKey.replySortType, 0);
      defaultReplySortIndex = 0;
    }
    sortType = ReplySortType.values[defaultReplySortIndex];
    sortTypeTitle.value = sortType.titles;
    sortTypeLabel.value = sortType.labels;
    if (sortType == ReplySortType.time) {
      mode = Mode.MAIN_LIST_TIME;
    }
  }

  @override
  Future onRefresh() {
    cursor = null;
    nextOffset = '';
    return super.onRefresh();
  }

  @override
  bool customHandleResponse(Success response) {
    if (GlobalData().grpcReply) {
      MainListReply replies = response.response;
      if (cursor == null) {
        count.value = replies.subjectControl.count.toInt();
        hasUpTop = replies.hasUpTop();
        if (replies.hasUpTop()) {
          replies.replies.insert(0, replies.upTop);
        }
      }
      cursor = replies.cursor;
      if (currentPage != 1 && loadingState.value is Success) {
        replies.replies
            .insertAll(0, (loadingState.value as Success).response.replies);
      }
      isEnd = replies.replies.isEmpty ||
          replies.cursor.isEnd ||
          replies.replies.length >= count.value;
      loadingState.value = LoadingState.success(replies);
    } else {
      List<ReplyItemModel> replies = response.response.replies;
      if (isLogin.not) {
        nextOffset = response.response.cursor.paginationReply.nextOffset ?? '';
      }
      count.value = isLogin.not
          ? response.response.cursor.allCount
          : response.response.page.count ?? 0;
      if (replies.isEmpty) {
        isEnd = true;
      }
      if (currentPage == 1) {
        if (response.response.upper.top != null) {
          final bool flag = response.response.topReplies.any(
              (ReplyItemModel reply) =>
                  reply.rpid != response.response.upper.top.rpid) as bool;
          if (flag) {
            replies.insert(0, response.response.upper.top);
            hasUpTop = true;
          }
        }
        if (response.response.topReplies != null) {
          replies.insertAll(0, response.response.topReplies);
          hasUpTop = true;
        }
      } else if (loadingState.value is Success) {
        replies.insertAll(0, (loadingState.value as Success).response.replies);
      }
      if (replies.length >= count.value) {
        isEnd = true;
      }
      loadingState.value = LoadingState.success(response.response);
    }
    return true;
  }

  // 排序搜索评论
  queryBySort() {
    EasyThrottle.throttle('queryBySort', const Duration(seconds: 1), () {
      feedBack();
      switch (sortType) {
        case ReplySortType.time:
          sortType = ReplySortType.like;
          mode = Mode.MAIN_LIST_HOT;
          break;
        case ReplySortType.like:
          sortType = ReplySortType.time;
          mode = Mode.MAIN_LIST_TIME;
          break;
      }
      sortTypeTitle.value = sortType.titles;
      sortTypeLabel.value = sortType.labels;
      nextOffset = '';
      loadingState.value = LoadingState.loading();
      onRefresh();
    });
  }

  void onReply(
    BuildContext context, {
    dynamic oid,
    dynamic replyItem,
    int index = 0,
    ReplyType? replyType,
  }) {
    dynamic key = oid ??
        replyItem.oid +
            (GlobalData().grpcReply ? replyItem.id : replyItem.rpid);
    Navigator.of(context)
        .push(
      GetDialogRoute(
        pageBuilder: (buildContext, animation, secondaryAnimation) {
          return GlobalData().grpcReply
              ? ReplyPage(
                  oid: oid ?? replyItem.oid.toInt(),
                  root: oid != null ? 0 : replyItem.id.toInt(),
                  parent: oid != null ? 0 : replyItem.id.toInt(),
                  replyType: replyItem != null
                      ? ReplyType.values[replyItem.type.toInt()]
                      : replyType,
                  replyItem: replyItem,
                  savedReply: savedReplies[key],
                  onSaveReply: (reply) {
                    savedReplies[key] = reply;
                  },
                )
              : ReplyPage(
                  oid: oid ?? replyItem.oid,
                  root: oid != null ? 0 : replyItem.rpid,
                  parent: oid != null ? 0 : replyItem.rpid,
                  replyType: replyItem != null
                      ? ReplyType.values[replyItem.type.toInt()]
                      : replyType,
                  replyItem: replyItem,
                  savedReply: savedReplies[key],
                  onSaveReply: (reply) {
                    savedReplies[key] = reply;
                  },
                );
        },
        transitionDuration: const Duration(milliseconds: 500),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.linear;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    )
        .then(
      (res) {
        if (res != null) {
          savedReplies[key] = null;
          if (GlobalData().grpcReply) {
            ReplyInfo replyInfo = Utils.replyCast(res);
            MainListReply response = loadingState.value is Success
                ? (loadingState.value as Success).response
                : MainListReply();
            if (oid != null) {
              response.replies.insert(hasUpTop ? 1 : 0, replyInfo);
            } else {
              response.replies[index].replies.add(replyInfo);
            }
            count.value += 1;
            loadingState.value = LoadingState.success(response);
          } else {
            ReplyData response = loadingState.value is Success
                ? (loadingState.value as Success).response
                : ReplyData();
            response.replies ??= <ReplyItemModel>[];
            if (oid != null) {
              response.replies
                  ?.insert(hasUpTop ? 1 : 0, ReplyItemModel.fromJson(res, ''));
            } else {
              response.replies?[index].replies ??= <ReplyItemModel>[];
              response.replies?[index].replies
                  ?.add(ReplyItemModel.fromJson(res, ''));
            }
            count.value += 1;
            loadingState.value = LoadingState.success(response);
          }
        }
      },
    );
  }

  onMDelete(rpid, frpid) {
    if (GlobalData().grpcReply) {
      MainListReply response = (loadingState.value as Success).response;
      if (frpid == null) {
        response.replies.removeWhere((item) {
          return item.id.toInt() == rpid;
        });
      } else {
        response.replies.map((item) {
          if (item.id == frpid) {
            return item
              ..replies.removeWhere((reply) => reply.id.toInt() == rpid);
          } else {
            return item;
          }
        }).toList();
      }
      count.value -= 1;
      loadingState.value = LoadingState.success(response);
    } else {
      ReplyData response = (loadingState.value as Success).response;
      response.replies = frpid == null
          ? response.replies?.where((item) => item.rpid != rpid).toList()
          : response.replies?.map((item) {
              if (item.rpid == frpid) {
                return item
                  ..replies = item.replies
                      ?.where((reply) => reply.rpid != rpid)
                      .toList();
              } else {
                return item;
              }
            }).toList();
      count.value -= 1;
      loadingState.value = LoadingState.success(response);
    }
  }
}
