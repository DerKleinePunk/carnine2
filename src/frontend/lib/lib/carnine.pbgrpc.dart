// This is a generated file - do not edit.
//
// Generated from carnine.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'carnine.pb.dart' as $0;

export 'carnine.pb.dart';

@$pb.GrpcServiceName('carnine.CarnineService')
class CarnineServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  CarnineServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.CanDataResponse> getCanData(
    $0.CanDataRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getCanData, request, options: options);
  }

  $grpc.ResponseFuture<$0.CommandResponse> sendCommand(
    $0.CommandRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sendCommand, request, options: options);
  }

  // method descriptors

  static final _$getCanData =
      $grpc.ClientMethod<$0.CanDataRequest, $0.CanDataResponse>(
          '/carnine.CarnineService/GetCanData',
          ($0.CanDataRequest value) => value.writeToBuffer(),
          $0.CanDataResponse.fromBuffer);
  static final _$sendCommand =
      $grpc.ClientMethod<$0.CommandRequest, $0.CommandResponse>(
          '/carnine.CarnineService/SendCommand',
          ($0.CommandRequest value) => value.writeToBuffer(),
          $0.CommandResponse.fromBuffer);
}

@$pb.GrpcServiceName('carnine.CarnineService')
abstract class CarnineServiceBase extends $grpc.Service {
  $core.String get $name => 'carnine.CarnineService';

  CarnineServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CanDataRequest, $0.CanDataResponse>(
        'GetCanData',
        getCanData_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CanDataRequest.fromBuffer(value),
        ($0.CanDataResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CommandRequest, $0.CommandResponse>(
        'SendCommand',
        sendCommand_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CommandRequest.fromBuffer(value),
        ($0.CommandResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CanDataResponse> getCanData_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CanDataRequest> $request) async {
    return getCanData($call, await $request);
  }

  $async.Future<$0.CanDataResponse> getCanData(
      $grpc.ServiceCall call, $0.CanDataRequest request);

  $async.Future<$0.CommandResponse> sendCommand_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CommandRequest> $request) async {
    return sendCommand($call, await $request);
  }

  $async.Future<$0.CommandResponse> sendCommand(
      $grpc.ServiceCall call, $0.CommandRequest request);
}
