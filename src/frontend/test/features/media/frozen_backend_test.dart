import 'dart:async';
import 'dart:io';

import 'package:carnine_frontend/core/platform/backend_heartbeat.dart';
import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';
import 'package:carnine_frontend/features/media/data/grpc_media_repository.dart';
import 'package:carnine_frontend/features/media/data/media_channel.dart';
import 'package:carnine_frontend/lib/carnine.pbgrpc.dart' as pb;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

/// A backend that holds its socket but never answers, like one stopped with
/// `kill -STOP` (#58): the kernel accepts the connection, nobody replies.
class _SilentBackend {
  _SilentBackend._(this._server);

  final ServerSocket _server;
  final List<Socket> _sockets = [];

  static Future<_SilentBackend> start() async {
    final backend = _SilentBackend._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    backend._server.listen(backend._sockets.add);
    return backend;
  }

  ClientChannel channel({ClientKeepAliveOptions? keepAlive}) {
    return channelWith(
      ChannelOptions(
        credentials: const ChannelCredentials.insecure(),
        keepAlive: keepAlive ?? const ClientKeepAliveOptions(),
      ),
    );
  }

  ClientChannel channelWith(ChannelOptions options) {
    return ClientChannel(
      InternetAddress.loopbackIPv4,
      port: _server.port,
      options: options,
    );
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close();
  }
}

void main() {
  late _SilentBackend backend;

  setUp(() async => backend = await _SilentBackend.start());
  tearDown(() => backend.close());

  // Why #58 needs a heartbeat: grpc-dart answers a missed keepalive ping
  // with an orderly finish that waits for the open streams, so a stream to a
  // frozen backend neither ends nor fails.
  test('the keepalive alone never ends a stream to a frozen backend', () async {
    var ended = false;
    // Closing the channel at the end fails the keepalive ping grpc-dart
    // still waits for; that error belongs to the cleanup, not to the test.
    await runZonedGuarded(
      () async {
        final channel = backend.channel(
          keepAlive: const ClientKeepAliveOptions(
            pingInterval: Duration(milliseconds: 300),
            timeout: Duration(milliseconds: 100),
            permitWithoutCalls: true,
          ),
        );
        final repository = GrpcMediaRepository(
          channel: MediaChannel(channelFactory: () => channel),
        );
        final subscription = repository.playerEvents().listen(
          (_) {},
          onError: (Object _) => ended = true,
          onDone: () => ended = true,
        );

        await Future<void>.delayed(const Duration(seconds: 2));
        expect(ended, isFalse);

        final closed = subscription.cancel();
        await channel.terminate();
        await closed;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      },
      (error, stackTrace) {
        if (!'$error'.contains('forcefully terminated')) {
          Error.throwWithStackTrace(error, stackTrace);
        }
      },
    );
  });

  test(
    'checkAlive fails against a frozen backend after its deadline',
    () async {
      final repository = GrpcMediaRepository(
        channel: MediaChannel(channelFactory: backend.channel),
      );
      final watch = Stopwatch()..start();

      await expectLater(
        repository.checkAlive(),
        throwsA(
          isA<GrpcError>().having(
            (error) => error.code,
            'code',
            StatusCode.deadlineExceeded,
          ),
        ),
      );

      expect(watch.elapsed, lessThan(BackendHeartbeat.defaultTimeout * 2));
      await repository.reconnect();
    },
  );

  test('reconnect makes a stream to a frozen backend fail at once', () async {
    final repository = GrpcMediaRepository(
      channel: MediaChannel(channelFactory: backend.channel),
    );
    final failed = Completer<void>();
    repository.playerEvents().listen(
      (_) {},
      onError: (Object _) => failed.isCompleted ? null : failed.complete(),
      onDone: () => failed.isCompleted ? null : failed.complete(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    await repository.reconnect();

    await failed.future.timeout(const Duration(seconds: 1));
  });

  // Seen on carnine-pc: while the backend was frozen, every reconnect
  // attempt logged "Unhandled Exception: HTTP/2 error: ... forcefully
  // terminated" - the keepalive ping waiting for its answer when the
  // heartbeat closed the channel.
  test(
    'closing the media channel to a frozen backend raises no error',
    () async {
      final unhandled = <Object>[];
      await runZonedGuarded(() async {
        final repository = GrpcMediaRepository(
          channel: MediaChannel(
            channelFactory: () =>
                backend.channelWith(GrpcEndpoint.longLivedChannelOptions),
          ),
        );
        repository.playerEvents().listen((_) {}, onError: (Object _) {});
        // Past the 5 s ping interval the channel used to have.
        await Future<void>.delayed(const Duration(milliseconds: 5600));

        await repository.reconnect();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }, (error, _) => unhandled.add(error));

      expect(unhandled, isEmpty);
    },
  );

  // Seen on carnine-pc with the maps and dashboard open: every few seconds
  // while frozen, the same unhandled exception from the navigation and power
  // supply channels - a position stream plus the status poll running into
  // its deadline was enough.
  test(
    'a stream plus deadline-bound calls to a frozen backend raise no error',
    () async {
      final unhandled = <Object>[];
      await runZonedGuarded(() async {
        final channel = backend.channelWith(
          GrpcEndpoint.longLivedChannelOptions,
        );
        final client = pb.NavigationServiceClient(channel);
        client.streamPositions(pb.Empty()).listen((_) {}, onError: (_) {});
        final poll = Timer.periodic(const Duration(seconds: 3), (_) {
          client
              .getNavigationStatus(
                pb.Empty(),
                options: CallOptions(timeout: const Duration(seconds: 2)),
              )
              .then((_) {}, onError: (Object _) {});
        });
        // The old keepalive surfaced the error after about 11.5 s.
        await Future<void>.delayed(const Duration(seconds: 13));
        poll.cancel();
        await channel.terminate();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }, (error, _) => unhandled.add(error));

      expect(unhandled, isEmpty);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
