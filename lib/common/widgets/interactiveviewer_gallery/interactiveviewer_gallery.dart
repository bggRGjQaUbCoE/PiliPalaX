import 'dart:io';

import 'package:PiliPalaX/utils/download.dart';
import 'package:PiliPalaX/utils/storage.dart';
import 'package:PiliPalaX/utils/utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:status_bar_control/status_bar_control.dart';
import 'interactive_viewer_boundary.dart';
import 'interactive_viewer.dart' as custom;

/// https://github.com/qq326646683/interactiveviewer_gallery

/// Builds a carousel controlled by a [PageView] for the tweet media sources.
///
/// Used for showing a full screen view of the [TweetMedia] sources.
///
/// The sources can be panned and zoomed interactively using an
/// [InteractiveViewer].
/// An [InteractiveViewerBoundary] is used to detect when the boundary of the
/// source is hit after zooming in to disable or enable the swiping gesture of
/// the [PageView].
///
typedef IndexedFocusedWidgetBuilder = Widget Function(
    BuildContext context, int index, bool isFocus, bool enablePageView);

typedef IndexedTagStringBuilder = String Function(int index);

class InteractiveviewerGallery<T> extends StatefulWidget {
  const InteractiveviewerGallery({
    super.key,
    required this.sources,
    required this.initIndex,
    this.itemBuilder,
    this.maxScale = 8,
    this.minScale = 1.0,
    this.onPageChanged,
    this.onDismissed,
  });

  /// The sources to show.
  final List<T> sources;

  /// The index of the first source in [sources] to show.
  final int initIndex;

  /// The item content
  final IndexedFocusedWidgetBuilder? itemBuilder;

  final double maxScale;

  final double minScale;

  final ValueChanged<int>? onPageChanged;

  final ValueChanged<int>? onDismissed;

  @override
  State<InteractiveviewerGallery> createState() =>
      _InteractiveviewerGalleryState();
}

class _InteractiveviewerGalleryState extends State<InteractiveviewerGallery>
    with SingleTickerProviderStateMixin {
  PageController? _pageController;
  custom.TransformationController? _transformationController;

  /// The controller to animate the transformation value of the
  /// [InteractiveViewer] when it should reset.
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  /// `true` when an source is zoomed in and not at the at a horizontal boundary
  /// to disable the [PageView].
  bool _enablePageView = true;

  late Offset _doubleTapLocalPosition;

  int? currentIndex;

  late List<bool> _thumbList;
  late int _quality;

  @override
  void initState() {
    super.initState();

    _quality =
        GStorage.setting.get(SettingBoxKey.previewQuality, defaultValue: 80);
    _thumbList = List.generate(widget.sources.length, (_) => true);

    _pageController = PageController(initialPage: widget.initIndex);

    _transformationController = custom.TransformationController();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        _transformationController!.value =
            _animation?.value ?? Matrix4.identity();
      });

    currentIndex = widget.initIndex;
    setStatusBar();
  }

  setStatusBar() async {
    if (Platform.isIOS || Platform.isAndroid) {
      await StatusBarControl.setHidden(
        true,
        animation: StatusBarAnimation.FADE,
      );
    }
  }

  @override
  void dispose() async {
    _pageController?.dispose();
    _animationController.removeListener(() {});
    _animationController.dispose();
    if (Platform.isIOS || Platform.isAndroid) {
      StatusBarControl.setHidden(false, animation: StatusBarAnimation.FADE);
    }
    for (int index = 0; index < widget.sources.length; index++) {
      CachedNetworkImageProvider(_getActualUrl(index)).evict();
    }
    super.dispose();
  }

  /// When the source gets scaled up, the swipe up / down to dismiss gets
  /// disabled.
  ///
  /// When the scale resets, the dismiss and the page view swiping gets enabled.
  void _onScaleChanged(double scale) {
    final bool initialScale = scale <= widget.minScale;

    if (initialScale) {
      if (!_enablePageView) {
        setState(() {
          _enablePageView = true;
        });
      }
    } else {
      if (_enablePageView) {
        setState(() {
          _enablePageView = false;
        });
      }
    }
  }

  /// When the left boundary has been hit after scaling up the source, the page
  /// view swiping gets enabled if it has a page to swipe to.
  void _onLeftBoundaryHit() {
    if (!_enablePageView && _pageController!.page!.floor() > 0) {
      setState(() {
        _enablePageView = true;
      });
    }
  }

  /// When the right boundary has been hit after scaling up the source, the page
  /// view swiping gets enabled if it has a page to swipe to.
  void _onRightBoundaryHit() {
    if (!_enablePageView &&
        _pageController!.page!.floor() < widget.sources.length - 1) {
      setState(() {
        _enablePageView = true;
      });
    }
  }

  /// When the source has been scaled up and no horizontal boundary has been hit,
  /// the page view swiping gets disabled.
  void _onNoBoundaryHit() {
    if (_enablePageView) {
      setState(() {
        _enablePageView = false;
      });
    }
  }

  /// When the page view changed its page, the source will animate back into the
  /// original scale if it was scaled up.
  ///
  /// Additionally the swipe up / down to dismiss gets enabled.
  void _onPageChanged(int page) {
    setState(() {
      currentIndex = page;
    });
    widget.onPageChanged?.call(page);
    if (_transformationController!.value != Matrix4.identity()) {
      // animate the reset for the transformation of the interactive viewer

      _animation = Matrix4Tween(
        begin: _transformationController!.value,
        end: Matrix4.identity(),
      ).animate(
        CurveTween(curve: Curves.easeOut).animate(_animationController),
      );

      _animationController.forward(from: 0);
    }
  }

  String _getActualUrl(int index) => _thumbList[index] && _quality != 100
      ? '${widget.sources[index]}@${_quality}q.webp'
      : widget.sources[index];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InteractiveViewerBoundary(
          controller: _transformationController,
          boundaryWidth: MediaQuery.of(context).size.width,
          onScaleChanged: _onScaleChanged,
          onLeftBoundaryHit: _onLeftBoundaryHit,
          onRightBoundaryHit: _onRightBoundaryHit,
          onNoBoundaryHit: _onNoBoundaryHit,
          maxScale: widget.maxScale,
          minScale: widget.minScale,
          onDismissed: () {
            Get.back();
            widget.onDismissed?.call(_pageController!.page!.floor());
          },
          onReset: () {
            if (!_enablePageView) {
              setState(() {
                _enablePageView = true;
              });
            }
          },
          child: PageView.builder(
            onPageChanged: _onPageChanged,
            controller: _pageController,
            physics:
                _enablePageView ? null : const NeverScrollableScrollPhysics(),
            itemCount: widget.sources.length,
            itemBuilder: (BuildContext context, int index) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: Get.back,
                onDoubleTapDown: (TapDownDetails details) {
                  _doubleTapLocalPosition = details.localPosition;
                },
                onDoubleTap: onDoubleTap,
                onLongPress: onLongPress,
                child: widget.itemBuilder != null
                    ? widget.itemBuilder!(
                        context,
                        index,
                        index == currentIndex,
                        _enablePageView,
                      )
                    : _itemBuilder(index),
              );
            },
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              12,
              8,
              20,
              MediaQuery.of(context).padding.bottom + 8,
            ),
            decoration: _enablePageView
                ? BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3)
                      ],
                    ),
                  )
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    Get.back();
                    widget.onDismissed?.call(_pageController!.page!.floor());
                  },
                ),
                widget.sources.length > 1
                    ? Text(
                        "${currentIndex! + 1}/${widget.sources.length}",
                        style: const TextStyle(color: Colors.white),
                      )
                    : const SizedBox(),
                PopupMenuButton(
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        value: 0,
                        onTap: () => onShareImg(widget.sources[currentIndex!]),
                        child: const Text("分享图片"),
                      ),
                      PopupMenuItem(
                        value: 1,
                        onTap: () {
                          Utils.copyText(widget.sources[currentIndex!]);
                        },
                        child: const Text("复制链接"),
                      ),
                      PopupMenuItem(
                        value: 2,
                        onTap: () {
                          DownloadUtils.downloadImg(
                            context,
                            [widget.sources[currentIndex!]],
                          );
                        },
                        child: const Text("保存图片"),
                      ),
                      if (widget.sources.length > 1)
                        PopupMenuItem(
                          value: 3,
                          onTap: () {
                            DownloadUtils.downloadImg(
                              context,
                              widget.sources[currentIndex!],
                            );
                          },
                          child: const Text("保存全部图片"),
                        ),
                    ];
                  },
                  child: const Icon(Icons.more_horiz, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 图片分享
  void onShareImg(String imgUrl) async {
    SmartDialog.showLoading();
    var response = await Dio()
        .get(imgUrl, options: Options(responseType: ResponseType.bytes));
    final temp = await getTemporaryDirectory();
    SmartDialog.dismiss();
    String imgName =
        "plpl_pic_${DateTime.now().toString().split('-').join()}.jpg";
    var path = '${temp.path}/$imgName';
    File(path).writeAsBytesSync(response.data);
    Share.shareXFiles([XFile(path)], subject: imgUrl);
  }

  Widget _itemBuilder(index) {
    return Center(
      child: Hero(
        tag: widget.sources[index],
        child: CachedNetworkImage(
          fadeInDuration: const Duration(milliseconds: 0),
          fadeOutDuration: const Duration(milliseconds: 0),
          imageUrl: _getActualUrl(index),
          // fit: BoxFit.contain,
          progressIndicatorBuilder: (context, url, progress) {
            return Center(
              child: SizedBox(
                width: 150.0,
                child: LinearProgressIndicator(value: progress.progress ?? 0),
              ),
            );
          },
          // errorListener: (value) {
          //   WidgetsBinding.instance.addPostFrameCallback((_) {
          //     setState(() {
          //       _thumbList[index] = false;
          //     });
          //   });
          // },
        ),
      ),
    );
  }

  onDoubleTap() {
    Matrix4 matrix = _transformationController!.value.clone();
    double currentScale = matrix.row0.x;

    double targetScale = widget.minScale;

    if (currentScale <= widget.minScale) {
      targetScale = widget.maxScale * 0.4;
    }

    double offSetX = targetScale == 1.0
        ? 0.0
        : -_doubleTapLocalPosition.dx * (targetScale - 1);
    double offSetY = targetScale == 1.0
        ? 0.0
        : -_doubleTapLocalPosition.dy * (targetScale - 1);

    matrix = Matrix4.fromList([
      targetScale,
      matrix.row1.x,
      matrix.row2.x,
      matrix.row3.x,
      matrix.row0.y,
      targetScale,
      matrix.row2.y,
      matrix.row3.y,
      matrix.row0.z,
      matrix.row1.z,
      targetScale,
      matrix.row3.z,
      offSetX,
      offSetY,
      matrix.row2.w,
      matrix.row3.w
    ]);

    _animation = Matrix4Tween(
      begin: _transformationController!.value,
      end: matrix,
    ).animate(
      CurveTween(curve: Curves.easeOut).animate(_animationController),
    );
    _animationController
        .forward(from: 0)
        .whenComplete(() => _onScaleChanged(targetScale));
  }

  onLongPress() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          clipBehavior: Clip.hardEdge,
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                onTap: () {
                  onShareImg(widget.sources[currentIndex!]);
                  Get.back();
                },
                dense: true,
                title: const Text('分享', style: TextStyle(fontSize: 14)),
              ),
              ListTile(
                onTap: () {
                  Get.back();
                  Utils.copyText(widget.sources[currentIndex!]);
                },
                dense: true,
                title: const Text('复制链接', style: TextStyle(fontSize: 14)),
              ),
              ListTile(
                onTap: () {
                  Get.back();
                  DownloadUtils.downloadImg(
                    context,
                    [widget.sources[currentIndex!]],
                  );
                },
                dense: true,
                title: const Text('保存图片', style: TextStyle(fontSize: 14)),
              ),
              if (widget.sources.length > 1)
                ListTile(
                  onTap: () {
                    Get.back();
                    DownloadUtils.downloadImg(
                      context,
                      widget.sources as List<String>,
                    );
                  },
                  dense: true,
                  title: const Text('保存全部图片', style: TextStyle(fontSize: 14)),
                ),
            ],
          ),
        );
      },
    );
  }
}
