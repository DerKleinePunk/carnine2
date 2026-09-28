import 'dart:async';

import 'package:carnine_frontend/features/media/data/media_channel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

/// A channel whose teardown never completes, like the one left behind when
/// the backend restarted (#44).
class _StuckChannel implements ClientChannel {
  int terminateCalls = 0;

  @override
  Future<void> shutdown() => Completer<void>().future;

  @override
  Future<void> terminate() {
    terminateCalls++;
    return Completer<void>().future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('reconnect does not wait for the old channel to close', () async {
    final channels = <_StuckChannel>[];
    final mediaChannel = MediaChannel(
      channelFactory: () {
        final channel = _StuckChannel();
        channels.add(channel);
        return channel;
      },
    );

    mediaChannel.stub;
    await mediaChannel.reconnect().timeout(const Duration(seconds: 1));

    expect(channels.single.terminateCalls, 1);

    // The next access builds a fresh channel.
    mediaChannel.stub;
    expect(channels, hasLength(2));
  });
}
