import 'dart:math';

import 'package:PiliPalaX/common/widgets/pair.dart';
import 'package:PiliPalaX/http/constants.dart';
import 'package:PiliPalaX/http/index.dart';
import 'package:PiliPalaX/pages/video/detail/controller.dart'
    show SegmentType, SegmentTypeExt, SkipType, SkipTypeExt;
import 'package:PiliPalaX/utils/storage.dart';
import 'package:PiliPalaX/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:uuid/uuid.dart';

class SponsorBlockPage extends StatefulWidget {
  const SponsorBlockPage({super.key});

  @override
  State<SponsorBlockPage> createState() => _SponsorBlockPageState();
}

class _SponsorBlockPageState extends State<SponsorBlockPage> {
  static const _url = 'https://github.com/hanydd/BilibiliSponsorBlock';
  final _textController = TextEditingController();
  late double _blockLimit;
  late List<Pair<SegmentType, SkipType>> _blockSettings;
  late List<Color> _blockColor;
  late String _userId;
  late bool _blockToast;
  late String _blockServer;
  late bool _blockTrack;
  bool? _serverStatus;

  @override
  void initState() {
    super.initState();
    _blockLimit = GStorage.blockLimit;
    _blockSettings = GStorage.blockSettings;
    _blockColor = GStorage.blockColor;
    _userId = GStorage.blockUserID;
    _blockToast = GStorage.blockToast;
    _blockServer = GStorage.blockServer;
    _blockTrack = GStorage.blockTrack;
    _checkServerStatus();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  TextStyle get _titleStyle => TextStyle(fontSize: 15);
  TextStyle get _subTitleStyle => TextStyle(
        fontSize: 13,
        color: Theme.of(context).colorScheme.outline,
      );

  _checkServerStatus() {
    Request()
        .get(
      '$_blockServer/api/status/uptime',
      options: Options(
        headers: {
          'env': '',
          'app-key': '',
          'x-bili-mid': '',
          'x-bili-aurora-eid': '',
          'x-bili-aurora-zone': '',
          'cookie':
              'buvid3= ; SESSDATA= ; bili_jct= ; DedeUserID= ; DedeUserID__ckMd5= ; sid= ',
        },
      ),
    )
        .then((res) {
      setState(() {
        _serverStatus = res.statusCode == 200 &&
            res.data is String &&
            Utils.isStringNumeric(res.data);
      });
    });
  }

  Widget get _blockLimitItem => ListTile(
        dense: true,
        onTap: () {
          _textController.text = _blockLimit.toString();
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('最短片段时长', style: _titleStyle),
                content: TextFormField(
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  controller: _textController,
                  autofocus: true,
                  decoration: InputDecoration(suffixText: 's'),
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
                      _blockLimit = max(
                          0.0, double.tryParse(_textController.text) ?? 0.0);
                      await GStorage.setting
                          .put(SettingBoxKey.blockLimit, _blockLimit);
                      setState(() {});
                    },
                    child: Text('确定'),
                  )
                ],
              );
            },
          );
        },
        title: Text('最短片段时长', style: _titleStyle),
        subtitle: Text(
          '忽略短于此时长的片段',
          style: _subTitleStyle,
        ),
        trailing: Text(
          '${_blockLimit}s',
          style: TextStyle(fontSize: 13),
        ),
      );

  Widget get _aboudItem => ListTile(
        dense: true,
        title: Text('关于空降助手', style: _titleStyle),
        subtitle: Text(_url, style: _subTitleStyle),
        onTap: () => Utils.launchURL(_url),
      );

  Widget get _userIdItem => ListTile(
        dense: true,
        title: Text('用户ID', style: _titleStyle),
        subtitle: Text(_userId, style: _subTitleStyle),
        onTap: () {
          final key = GlobalKey<FormState>();
          _textController.text = _userId;
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('用户ID', style: _titleStyle),
                content: Form(
                  key: key,
                  child: TextFormField(
                    minLines: 1,
                    maxLines: 4,
                    autofocus: true,
                    controller: _textController,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\d]+')),
                    ],
                    validator: (value) {
                      if ((value?.length ?? -1) < 30) {
                        return '用户ID要求至少为30个字符长度的纯字符串';
                      }
                      return null;
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Get.back();
                      _userId = Uuid().v4().replaceAll('-', '');
                      await GStorage.setting
                          .put(SettingBoxKey.blockUserID, _userId);
                      setState(() {});
                    },
                    child: Text('随机'),
                  ),
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
                      if (key.currentState?.validate() == true) {
                        Get.back();
                        _userId = _textController.text;
                        await GStorage.setting
                            .put(SettingBoxKey.blockUserID, _userId);
                        setState(() {});
                      }
                    },
                    child: Text('确定'),
                  )
                ],
              );
            },
          );
        },
      );

  void _updateBlockToast() async {
    _blockToast = !_blockToast;
    await GStorage.setting.put(SettingBoxKey.blockToast, _blockToast);
    setState(() {});
  }

  void _updateBlockTrack() async {
    _blockTrack = !_blockTrack;
    await GStorage.setting.put(SettingBoxKey.blockTrack, _blockTrack);
    setState(() {});
  }

  Widget get _blockToastItem => ListTile(
      dense: true,
      onTap: _updateBlockToast,
      title: Text(
        '显示跳过Toast',
        style: _titleStyle,
      ),
      trailing: Transform.scale(
        alignment: Alignment.centerRight,
        scale: 0.8,
        child: Switch(
          thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
            if (states.isNotEmpty && states.first == WidgetState.selected) {
              return const Icon(Icons.done);
            }
            return null;
          }),
          value: _blockToast,
          onChanged: (val) {
            _updateBlockToast();
          },
        ),
      ));

  Widget get _blockTrackItem => ListTile(
      dense: true,
      onTap: _updateBlockTrack,
      title: Text(
        '跳过次数统计跟踪',
        style: _titleStyle,
      ),
      subtitle: Text(
        // from origin extension
        '此功能追踪您跳过了哪些片段，让用户知道他们提交的片段帮助了多少人。同时点赞会作为依据，确保垃圾信息不会污染数据库。在您每次跳过片段时，我们都会向服务器发送一条消息。希望大家开启此项设置，以便得到更准确的统计数据。:)',
        style: _subTitleStyle,
      ),
      trailing: Transform.scale(
        alignment: Alignment.centerRight,
        scale: 0.8,
        child: Switch(
          thumbIcon: WidgetStateProperty.resolveWith<Icon?>((states) {
            if (states.isNotEmpty && states.first == WidgetState.selected) {
              return const Icon(Icons.done);
            }
            return null;
          }),
          value: _blockTrack,
          onChanged: (val) {
            _updateBlockTrack();
          },
        ),
      ));

  Widget get _blockServerItem => ListTile(
        dense: true,
        onTap: () {
          _textController.text = _blockServer;
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('服务器地址', style: _titleStyle),
                content: TextFormField(
                  keyboardType: TextInputType.url,
                  controller: _textController,
                  autofocus: true,
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      Get.back();
                      _blockServer = HttpString.sponsorBlockBaseUrl;
                      await GStorage.setting
                          .put(SettingBoxKey.blockServer, _blockServer);
                      setState(() {});
                    },
                    child: Text('重置'),
                  ),
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
                      _blockServer = _textController.text;
                      await GStorage.setting
                          .put(SettingBoxKey.blockServer, _blockServer);
                      setState(() {});
                    },
                    child: Text('确定'),
                  )
                ],
              );
            },
          );
        },
        title: Text(
          '服务器地址',
          style: _titleStyle,
        ),
        subtitle: Text(
          _blockServer,
          style: _subTitleStyle,
        ),
      );

  Widget get _serverStatusItem => ListTile(
        dense: true,
        onTap: _checkServerStatus,
        title: Text(
          '服务器状态',
          style: _titleStyle,
        ),
        trailing: Text(
          _serverStatus == null
              ? '-'
              : _serverStatus == true
                  ? '正常'
                  : '错误',
          style: TextStyle(
            fontSize: 13,
            color: _serverStatus == null
                ? null
                : _serverStatus == true
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
          ),
        ),
      );

  Widget get _divider => SliverToBoxAdapter(
        child: Divider(
          height: 1,
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      );

  Widget get _dividerL => SliverToBoxAdapter(
        child: Divider(
          thickness: 16,
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('空降助手')),
      body: CustomScrollView(
        slivers: [
          _dividerL,
          SliverToBoxAdapter(child: _serverStatusItem),
          _dividerL,
          SliverToBoxAdapter(child: _blockLimitItem),
          _divider,
          SliverToBoxAdapter(child: _blockToastItem),
          _divider,
          SliverToBoxAdapter(child: _blockTrackItem),
          _dividerL,
          SliverList.separated(
            itemCount: _blockSettings.length,
            itemBuilder: (context, index) => ListTile(
              dense: true,
              enabled: _blockSettings[index].second != SkipType.disable,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    clipBehavior: Clip.hardEdge,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Color Picker ',
                            style: TextStyle(fontSize: 15),
                          ),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              height:
                                  MediaQuery.textScalerOf(context).scale(13),
                              width: MediaQuery.textScalerOf(context).scale(13),
                              alignment: Alignment.center,
                              child: Container(
                                height: 10,
                                width: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _blockColor[index],
                                ),
                              ),
                            ),
                            style: TextStyle(fontSize: 13),
                          ),
                          TextSpan(
                            text: ' ${_blockSettings[index].first.title}',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    content: SlideColorPicker(
                      color: _blockColor[index],
                      callback: (Color? color) async {
                        _blockColor[index] =
                            color ?? _blockSettings[index].first.color;
                        await GStorage.setting.put(
                            SettingBoxKey.blockColor,
                            _blockColor
                                .map((item) =>
                                    item.value.toRadixString(16).substring(2))
                                .toList());
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
              title: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Container(
                        height: MediaQuery.textScalerOf(context).scale(15),
                        width: 10,
                        alignment: Alignment.center,
                        child: Container(
                          height: 10,
                          width: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _blockColor[index],
                          ),
                        ),
                      ),
                      style: TextStyle(fontSize: 14),
                    ),
                    TextSpan(
                      text: ' ${_blockSettings[index].first.title}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              subtitle: Text(
                _blockSettings[index].first.description,
                style: TextStyle(
                  fontSize: 12,
                  color: _blockSettings[index].second == SkipType.disable
                      ? null
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              trailing: PopupMenuButton(
                initialValue: _blockSettings[index].second,
                onSelected: (item) async {
                  _blockSettings[index].second = item;
                  await GStorage.setting.put(SettingBoxKey.blockSettings,
                      _blockSettings.map((item) => item.second.index).toList());
                  setState(() {});
                },
                itemBuilder: (context) => SkipType.values
                    .map((item) => PopupMenuItem<SkipType>(
                          value: item,
                          child: Text(item.title),
                        ))
                    .toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _blockSettings[index].second.title,
                        style: TextStyle(
                          height: 1,
                          fontSize: 14,
                          color:
                              _blockSettings[index].second == SkipType.disable
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                        ),
                        strutStyle: StrutStyle(height: 1, leading: 0),
                      ),
                      Icon(
                        MdiIcons.unfoldMoreHorizontal,
                        size: MediaQuery.textScalerOf(context).scale(14),
                        color: _blockSettings[index].second == SkipType.disable
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color:
                  Theme.of(context).colorScheme.outline.withOpacity(0.1),
            ),
          ),
          _dividerL,
          SliverToBoxAdapter(child: _userIdItem),
          _divider,
          SliverToBoxAdapter(child: _blockServerItem),
          _dividerL,
          SliverToBoxAdapter(child: _aboudItem),
          _dividerL,
          SliverToBoxAdapter(
              child: SizedBox(
            height: 25 + MediaQuery.paddingOf(context).bottom,
          )),
        ],
      ),
    );
  }
}

class SlideColorPicker extends StatefulWidget {
  const SlideColorPicker({
    super.key,
    required this.color,
    required this.callback,
  });

  final Color color;
  final Function(Color? color) callback;

  @override
  State<SlideColorPicker> createState() => _SlideColorPickerState();
}

class _SlideColorPickerState extends State<SlideColorPicker> {
  late int _r;
  late int _g;
  late int _b;
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _r = widget.color.red;
    _g = widget.color.green;
    _b = widget.color.blue;
    _textController = TextEditingController(text: _convert);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String get _convert => Color.fromARGB(255, _r, _g, _b)
      .value
      .toRadixString(16)
      .substring(2)
      .toUpperCase();

  Widget _slider({
    required String title,
    required int value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        const SizedBox(width: 16),
        Text(title),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            divisions: 255,
            value: value.toDouble(),
            onChanged: onChanged,
          ),
        ),
        Text(
          value.toString(),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 100,
            color: Color.fromARGB(255, _r, _g, _b),
          ),
          const SizedBox(height: 10),
          IntrinsicWidth(
            child: TextField(
              inputFormatters: [
                LengthLimitingTextInputFormatter(6),
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
              ],
              controller: _textController,
              decoration: InputDecoration(
                isDense: true,
                prefixText: '#',
                contentPadding: const EdgeInsets.all(0),
              ),
              onChanged: (value) {
                _textController.text = value.toUpperCase();
                if (value.length == 6) {
                  Color color =
                      Color(int.tryParse('FF$value', radix: 16) ?? 0xFF000000);
                  setState(() {
                    _r = color.red;
                    _g = color.green;
                    _b = color.blue;
                  });
                }
              },
            ),
          ),
          _slider(
            title: 'R',
            value: _r,
            onChanged: (value) {
              setState(() {
                _r = value.round();
                _textController.text = _convert;
              });
            },
          ),
          _slider(
            title: 'G',
            value: _g,
            onChanged: (value) {
              setState(() {
                _g = value.round();
                _textController.text = _convert;
              });
            },
          ),
          _slider(
            title: 'B',
            value: _b,
            onChanged: (value) {
              setState(() {
                _b = value.round();
                _textController.text = _convert;
              });
            },
          ),
          Row(
            children: [
              const SizedBox(width: 16),
              TextButton(
                onPressed: () {
                  Get.back();
                  widget.callback(null);
                },
                child: Text(
                  '重置',
                ),
              ),
              const Spacer(),
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
                  widget.callback(Color.fromARGB(255, _r, _g, _b));
                },
                child: const Text('确定'),
              ),
              const SizedBox(width: 16),
            ],
          )
        ],
      ),
    );
  }
}
