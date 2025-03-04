import 'package:PiliPlus/http/loading_state.dart';

import '../models/user/black.dart';
import 'index.dart';

class BlackHttp {
  static Future<LoadingState> blackList({required int pn, int? ps}) async {
    var res = await Request().get(Api.blackLst, queryParameters: {
      'pn': pn,
      'ps': ps ?? 50,
      're_version': 0,
      'jsonp': 'jsonp',
      'csrf': await Request.getCsrf(),
    });
    if (res.data['code'] == 0) {
      BlackListDataModel data = BlackListDataModel.fromJson(res.data['data']);
      return LoadingState.success(data);
    } else {
      return LoadingState.error(res.data['message']);
    }
  }

  // 移除黑名单
  static Future removeBlack({required int fid}) async {
    var res = await Request().post(
      Api.removeBlack,
      queryParameters: {
        'act': 6,
        'csrf': await Request.getCsrf(),
        'fid': fid,
        'jsonp': 'jsonp',
        're_src': 116,
      },
    );
    if (res.data['code'] == 0) {
      return {
        'status': true,
        'data': [],
        'msg': '操作成功',
      };
    } else {
      return {
        'status': false,
        'data': [],
        'msg': res.data['message'],
      };
    }
  }
}
