# Frontend (Flutter)

Minimal bootstrap app for Carnine.

## Build Dependencies

To generate gRPC client code, install the Dart protobuf plugin globally:

```bash
dart pub global activate protoc_plugin
```

Ensure `protoc-gen-dart` is in your PATH.

The protobuf schema is shared across frontend and backend at `../proto/carnine.proto`.

Generate Dart gRPC client stubs from the shared schema:

```bash
protoc -I ../proto --dart_out=grpc:lib/lib ../proto/carnine.proto
```

## Commands

- `flutter pub get`
- `flutter analyze .`
- `flutter test .`
- `flutter run`

## Current State

This is an initial UI shell to validate build and runtime setup before integrating backend communication.
