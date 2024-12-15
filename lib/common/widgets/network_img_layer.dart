import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:PiliPalaX/utils/extension.dart';
import 'package:PiliPalaX/utils/global_data.dart';
import '../../utils/storage.dart';
import '../constants.dart';

Box<dynamic> setting = GStorage.setting;

class NetworkImgLayer extends StatelessWidget {
  const NetworkImgLayer({
    super.key,
    this.src,
    required this.width,
    required this.height,
    this.type,
    this.fadeOutDuration,
    this.fadeInDuration,
    // 图片质量 默认1%
    this.quality,
    this.semanticsLabel,
    this.ignoreHeight,
    this.radius,
    this.imageBuilder,
    this.isLongPic,
    this.callback,
  });

  final String? src;
  final double width;
  final double height;
  final String? type;
  final Duration? fadeOutDuration;
  final Duration? fadeInDuration;
  final int? quality;
  final String? semanticsLabel;
  final bool? ignoreHeight;
  final double? radius;
  final ImageWidgetBuilder? imageBuilder;
  final Function? isLongPic;
  final Function? callback;

  @override
  Widget build(BuildContext context) {
    late final int defaultImgQuality = GlobalData().imgQuality;
    bool thumbnail = true;
    int? memCacheWidth, memCacheHeight;

    if (callback?.call() == true || width <= height) {
      memCacheWidth = width.cacheSize(context);
    } else {
      memCacheHeight = height.cacheSize(context);
    }
    Widget res = src != '' && src != null
        ? ClipRRect(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(
              radius != null
                  ? radius!
                  : type == 'avatar'
                      ? 50
                      : type == 'emote'
                          ? 0
                          : StyleString.imgRadius.x,
            ),
            child: Builder(
              builder: (context) => CachedNetworkImage(
                imageUrl:
                    '${src?.startsWith('//') == true ? 'https:$src' : src?.http2https}${type != 'emote' && thumbnail ? '@${quality ?? defaultImgQuality}q.webp' : ''}',
                width: width,
                height: ignoreHeight == null || ignoreHeight == false
                    ? height
                    : null,
                memCacheWidth: memCacheWidth,
                memCacheHeight: memCacheHeight,
                fit: BoxFit.cover,
                alignment: isLongPic?.call() == true
                    ? Alignment.topCenter
                    : Alignment.center,
                fadeOutDuration:
                    fadeOutDuration ?? const Duration(milliseconds: 120),
                fadeInDuration:
                    fadeInDuration ?? const Duration(milliseconds: 120),
                filterQuality: FilterQuality.low,
                errorWidget: (BuildContext context, String url, Object error) =>
                    placeholder(context),
                placeholder: (BuildContext context, String url) =>
                    placeholder(context),
                imageBuilder: imageBuilder,
                // errorListener: (value) {
                //   thumbnail = false;
                //   if (context.mounted) {
                //     (context as Element).markNeedsBuild();
                //   }
                // },
              ),
            ),
          )
        : placeholder(context);
    if (semanticsLabel != null) {
      return Semantics(
        label: semanticsLabel,
        child: res,
      );
    }
    return res;
  }

  Widget placeholder(BuildContext context) {
    int cacheWidth = width.cacheSize(context);
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .onInverseSurface
            .withOpacity(0.4),
        borderRadius: BorderRadius.circular(type == 'avatar'
            ? 50
            : type == 'emote'
                ? 0
                : StyleString.imgRadius.x),
      ),
      child: type == 'bg'
          ? const SizedBox()
          : Center(
              child: Image.asset(
                type == 'avatar'
                    ? 'assets/images/noface.jpeg'
                    : 'assets/images/loading.png',
                width: width,
                height: height,
                cacheWidth: cacheWidth == 0 ? null : cacheWidth,
                // cacheHeight: height.cacheSize(context),
              ),
            ),
    );
  }
}
