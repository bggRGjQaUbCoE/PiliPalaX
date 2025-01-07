import 'package:PiliPlus/http/loading_state.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/search/suggest.dart';
import 'package:PiliPlus/utils/storage.dart';

class SSearchController extends GetxController {
  final searchFocusNode = FocusNode();
  final controller = TextEditingController();

  RxList<String> historyList = <String>[].obs;

  RxList<SearchSuggestItem> searchSuggestList = <SearchSuggestItem>[].obs;

  String hintText = '搜索';

  late bool enableHotKey;

  Rx<LoadingState> loadingState = LoadingState.loading().obs;

  int initIndex = 0;

  @override
  void onInit() {
    super.onInit();
    // 其他页面跳转过来
    if (Get.parameters.keys.isNotEmpty) {
      if (Get.parameters['keyword'] != null) {
        onClickKeyword(Get.parameters['keyword']!);
      }
      if (Get.parameters['hintText'] != null) {
        hintText = Get.parameters['hintText']!;
      }
    }

    historyList.value = List.from(GStorage.historyWord.get('cacheList') ?? []);

    enableHotKey =
        GStorage.setting.get(SettingBoxKey.enableHotKey, defaultValue: true);

    if (enableHotKey) {
      queryHotSearchList();
    }
  }

  void onChange(String value) {
    if (value.isEmpty) {
      searchSuggestList.clear();
    } else {
      querySearchSuggest(value);
    }
  }

  void onClear() {
    if (controller.value.text != '') {
      controller.clear();
      searchSuggestList.clear();
      searchFocusNode.requestFocus();
    } else {
      Get.back();
    }
  }

  // 搜索
  void submit() async {
    if (controller.text.isEmpty) {
      if (hintText.isEmpty) {
        return;
      }
      controller.text = hintText;
    }

    historyList.remove(controller.text);
    historyList.insert(0, controller.text);
    GStorage.historyWord.put('cacheList', historyList);
    searchFocusNode.unfocus();

    await Get.toNamed(
      '/searchResult',
      parameters: {
        'keyword': controller.text,
      },
      arguments: initIndex,
    );
    searchFocusNode.requestFocus();
  }

  // 获取热搜关键词
  Future queryHotSearchList() async {
    dynamic result = await SearchHttp.hotSearchList();
    if (result['status']) {
      loadingState.value = LoadingState.success(result['data'].list);
    } else {
      loadingState.value = LoadingState.error(result['msg']);
    }
  }

  void onClickKeyword(String keyword) {
    controller.text = keyword;
    searchSuggestList.clear();
    submit();
  }

  Future querySearchSuggest(String value) async {
    var result = await SearchHttp.searchSuggest(term: value);
    if (result['status']) {
      if (result['data'] is SearchSuggestModel) {
        searchSuggestList.value = result['data'].tag;
      }
    }
  }

  onLongSelect(word) {
    historyList.remove(word);
    GStorage.historyWord.put('cacheList', historyList);
  }

  onClearHistory() {
    historyList.clear();
    GStorage.historyWord.put('cacheList', []);
  }

  @override
  void onClose() {
    searchFocusNode.dispose();
    controller.dispose();
    super.onClose();
  }
}
