import 'package:PiliPalaX/common/widgets/interactiveviewer_gallery/hero_dialog_route.dart';
import 'package:PiliPalaX/common/widgets/interactiveviewer_gallery/interactiveviewer_gallery.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

extension ImageExtension on num {
  int cacheSize(BuildContext context) {
    return (this * MediaQuery.of(context).devicePixelRatio).round();
  }
}

extension ScrollControllerExt on ScrollController {
  void animToTop() {
    if (!hasClients) return;
    if (offset >= MediaQuery.of(Get.context!).size.height * 7) {
      jumpTo(0);
    } else {
      animateTo(0,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }
}

extension ListExt<T> on List<T>? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;

  T? getOrNull(int index) {
    if (isNullOrEmpty) {
      return null;
    }
    return this![index];
  }

  bool eq(List<T>? other) {
    if (this == null) {
      return other == null;
    }
    if (other == null || this!.length != other.length) {
      return false;
    }
    for (int index = 0; index < this!.length; index += 1) {
      if (this![index] != other[index]) {
        return false;
      }
    }
    return true;
  }

  bool ne(List<T>? other) => !eq(other);
}

extension StringExt on String {
  String get http2https => replaceFirst(RegExp("^http://"), "https://");
}

extension BoolExt on bool {
  bool get not => !this;
}

extension BuildContextExt on BuildContext {
  Color get vipColor {
    return Theme.of(this).brightness == Brightness.light
        ? const Color(0xFFFF6699)
        : const Color(0xFFD44E7D);
  }

  void imageView({
    int? initialPage,
    required List<String> imgList,
    ValueChanged<int>? onDismissed,
  }) {
    Navigator.of(this).push(
      HeroDialogRoute(
        builder: (context) => InteractiveviewerGallery(
          sources: imgList,
          initIndex: initialPage ?? 0,
          onPageChanged: (int pageIndex) {},
          onDismissed: onDismissed,
        ),
      ),
    );
  }
}
