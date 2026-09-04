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

## ARM64 Debian package

Build the Raspberry Pi bundle and package it together with the `flutter-pi`
runtime:

```bash
flutterpi_tool build --arch=arm64 --cpu=pi4 \
	--dart-define="CARNINE_VERSION=$(cat ../../VERSION)"
bash package-deb.sh build/flutter-pi/aarch64-generic carnine-frontend.deb "$(cat ../../VERSION)"
```

The package installs the application under `/opt/carnine/frontend` and
provides `carnine-frontend.service`. It uses DRM/KMS directly, so no X11 or
Wayland session is required.

The Carnine Dart application does not use Vulkan, GStreamer, or Flutter audio.
The bundled `flutter-pi` binary must nevertheless be built without those
optional features before their runtime libraries can be removed from the
Debian package dependencies.

The application fonts `NotoSansSC` and `NotoSansJP` are bundled with the
application. The image also installs `fontconfig` and `fonts-liberation` as a
runtime-compatible replacement for the Arial font expected by the Flutter
engine.

## Current State

This is an initial UI shell to validate build and runtime setup before integrating backend communication.
