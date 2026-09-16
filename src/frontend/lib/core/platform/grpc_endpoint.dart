import 'dart:io';

import 'package:grpc/grpc.dart';

/// Picks the gRPC transport for talking to the backend (ADR-002).
///
/// Unix domain sockets are the default and match production: frontend and
/// backend run as the same user on the same machine (the Raspberry Pi), so
/// no separate auth layer is needed beyond filesystem permissions. TCP
/// loopback is an explicit, opt-in development fallback for setups that
/// don't share a kernel/socket namespace - e.g. a Flutter debug build
/// running as a native Windows process against a backend inside WSL2.
abstract final class GrpcEndpoint {
  const GrpcEndpoint._();

  static const String _defaultSocketPath = '/run/carnine/carnine.sock';

  /// Builds a channel to the backend using [options], honoring the same
  /// `CARNINE_SOCKET_PATH`/`CARNINE_TCP_ADDRESS` environment overrides the
  /// backend itself reads, so both sides agree on a non-default location
  /// without editing code (see docs/07-deployment.md §7.4).
  static ClientChannel createChannel({required ChannelOptions options}) {
    final tcpOverride = Platform.environment['CARNINE_TCP_ADDRESS'];
    if (tcpOverride != null) {
      final authority = Uri.parse('grpc://$tcpOverride');
      return ClientChannel(
        authority.host,
        port: authority.port,
        options: options,
      );
    }

    if (Platform.isWindows) {
      return ClientChannel('127.0.0.1', port: 50051, options: options);
    }

    final socketPath =
        Platform.environment['CARNINE_SOCKET_PATH'] ?? _defaultSocketPath;
    return ClientChannel(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      port: 0,
      options: options,
    );
  }
}
