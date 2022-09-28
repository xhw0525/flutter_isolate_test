import 'dart:async';
import 'dart:isolate';

main(List<String> args) async {
  var worker = Worker();
  // for (int i = 0; i < 100; i++) {
  //   worker.reuqest('发送消息$i').then((data) {
  //     print('子线程处理后的消息:$data');
  //   });
  // }
  worker.reuqest('发送消息1').then((data) {
    print('子线程处理后的消息:$data');
  });
}

class Worker {
  SendPort? _sendPort;
  Isolate? _isolate;
  final _isolateReady = Completer<void>();
  final Map<Capability, Completer> _completers = {};

  Worker() {
    init();
  }

  void dispose() {
    _isolate?.kill();
  }

  Future reuqest(dynamic message) async {
    await _isolateReady.future;
    final completer = Completer();
    final requestId = Capability();
    _completers[requestId] = completer;
    _sendPort?.send(_Request(requestId, message));
    return completer.future;
  }

  Future<void> init() async {
    final receivePort = ReceivePort();
    receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
        _isolateReady.complete();
        return;
      }
      if (message is _Response) {
        final completer = _completers[message.requestId];
        if (completer != null && message.success) {
          completer.complete(message.message);
        }
        return;
      }
    });
    _isolate = await Isolate.spawn(
      _isolateEntry,
      receivePort.sendPort,
    );
  }

  static void _isolateEntry(dynamic message1) {
    SendPort? tmpSendPort;

    final tmpReceivePort = ReceivePort();
    tmpReceivePort.listen((dynamic message2) async {
      if (message2 is _Request) {
        print('子线程收到：${message2.message}');
        tmpSendPort?.send(
            _Response.ok(message2.requestId, '处理后的消息:${message2.message}'));
        return;
      }
    });

    if (message1 is SendPort) {
      tmpSendPort = message1;
      tmpSendPort.send(tmpReceivePort.sendPort);
      return;
    }
  }
}

class _Request {
  final Capability requestId;

  final dynamic message;

  const _Request(this.requestId, this.message);
}

class _Response {
  final Capability requestId;

  final bool success;

  final dynamic message;

  const _Response.ok(this.requestId, this.message, {this.success = true});
}
