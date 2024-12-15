// 订阅者回调签名
typedef EventCallback = void Function(dynamic arg);

class EventBus {
  // 私有构造函数
  EventBus._internal();

  // 保存单例
  static final EventBus _singleton = EventBus._internal();

  // 工厂构造函数
  factory EventBus() => _singleton;

  // 保存事件订阅者队列，key:事件名(id)，value: 对应事件的订阅者队列
  final _emap = <dynamic, List<EventCallback>>{};

  // 添加订阅者
  void on(eventName, EventCallback f) {
    _emap[eventName] ??= <EventCallback>[];
    _emap[eventName]!.add(f);
  }

  // 移除订阅者
  void off(eventName, [EventCallback? f]) {
    var list = _emap[eventName];
    if (eventName == null || list == null) return;
    if (f == null) {
      _emap[eventName] = [];
    } else {
      list.remove(f);
    }
  }

  // 触发事件，事件触发后该事件所有订阅者会被调用
  void emit(eventName, [arg]) {
    var list = _emap[eventName];
    if (list == null) return;
    List<EventCallback> tempList = List.from(list);
    for (var callback in tempList) {
      callback(arg);
    }
  }

  // 获取订阅者数量
  int getSubscriberCount(eventName) {
    var list = _emap[eventName];
    return list?.length ?? 0;
  }
}

class EventName {
  static const String loginEvent = 'loginEvent';
}
