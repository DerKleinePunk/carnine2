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

The frontend is cross-built with `emb_cli` and runs under ivi-homescreen
(ADR-020); flutter-pi is no longer used. `build_pi.sh` in the repository root
builds the bundle and packages it with `package-deb.sh
<ivi-homescreen-bundle> <output-deb> <version>`; the steps and the emb
workspace it needs are in `docs/07-deployment.md`, section 3.3.

The package installs the application under `/opt/carnine/frontend` and
provides `carnine-frontend.service`. It uses DRM/KMS directly, so no X11 or
Wayland session is required.

The application fonts `NotoSansSC` and `NotoSansJP` are bundled with the
application. The image also installs `fontconfig` and `fonts-liberation` as a
runtime-compatible replacement for the Arial font expected by the Flutter
engine.

## Current State

This is an initial UI shell to validate build and runtime setup before integrating backend communication.
