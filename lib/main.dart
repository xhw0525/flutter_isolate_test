import 'dart:async';
import 'dart:io';
import 'dart:isolate';

main(List<String> args) async {
  var worker = WorkerImp();
  // for (int i = 0; i < 100; i++) {
  //   worker.reuqest('发送消息$i').then((data) {
  //     print('子线程处理后的消息:$data');
  //   });
  // }
  worker.reuqest('发送消息1').then((data) {
    print('子线程处理后的消息:$data');
  });
}

class WorkerImp extends Worker {
  @override
  WorkResponse runThread(WorkRequest _request) {
    print('子线程收到：${_request.message}');
    print('运行耗时任务');
    sleep(const Duration(seconds: 5));
    return WorkResponse.ok(_request.requestId, '处理后的消息:${_request.message}');
  }
}

abstract class Worker {
  SendPort? _p2;
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
    _p2?.send(WorkRequest(requestId, message));
    return completer.future;
  }

  Future<void> init() async {
    final r1 = ReceivePort();
    r1.listen((message) {
      if (message is SendPort) {
        _p2 = message;
        _isolateReady.complete();
        return;
      }
      if (message is WorkResponse) {
        final completer = _completers[message.requestId];
        if (completer != null && message.success) {
          completer.complete(message.message);
        }
        return;
      }
    });
    _isolate = await Isolate.spawn(
      _isolateEntry,
      r1.sendPort,
    );
  }

  WorkResponse runThread(WorkRequest _request);

  void _isolateEntry(dynamic message1) {
    SendPort? p1;

    final r2 = ReceivePort();
    r2.listen((dynamic message2) async {
      if (message2 is WorkRequest) {
        WorkResponse _response = await runThread(message2);
        p1?.send(_response);
        return;
      }
    });

    if (message1 is SendPort) {
      p1 = message1;
      p1.send(r2.sendPort);
      return;
    }
  }
}

class WorkRequest {
  final Capability requestId;

  final dynamic message;

  const WorkRequest(this.requestId, this.message);
}

class WorkResponse {
  final Capability requestId;

  final bool success;

  final dynamic message;

  const WorkResponse.ok(this.requestId, this.message, {this.success = true});
}
