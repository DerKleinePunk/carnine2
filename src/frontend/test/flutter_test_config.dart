import 'dart:async';

import 'package:carnine_frontend/core/platform/grpc_endpoint.dart';

/// Runs before every test file. The tests must not depend on the shell that
/// starts them: the WSL dev shell exports CARNINE_TCP_ADDRESS and
/// CARNINE_SOCKET_PATH, and with them a widget test that builds a real channel
/// left a TCP connect timer pending and failed, while CI stayed green.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GrpcEndpoint.environment = () => const {};
  await testMain();
}
