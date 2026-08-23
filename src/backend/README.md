# Backend (Rust)

Minimal bootstrap service for Carnine.

## Build Dependencies

To build the gRPC code, you need to install Protocol Buffers compiler:

```bash
sudo apt install protobuf-compiler
```

The protobuf schema is shared across frontend and backend at `../proto/carnine.proto`.

## Commands

- `cargo check`
- `cargo run`
- `cargo test`
- `cargo deb`

The generated-stub gRPC smoke client can be used without Flutter:

```bash
cargo run --example media_grpc_client -- http://[::1]:50051 version
cargo run --example media_grpc_client -- http://[::1]:50051 state
cargo run --example media_grpc_client -- http://[::1]:50051 smoke /path/to/audio.mp3
```

For manual, dynamic gRPC exploration, `granc` is a suitable external tool.
It needs a protobuf `FileDescriptorSet` when server reflection is not enabled.
The project client remains the regression-test tool because it uses generated
Tonic stubs and therefore fails at compile time when the contract changes.

`cargo deb` erzeugt ein optimiertes Debian-Paket unter `target/debian/`.
Installieren lässt es sich beispielsweise mit:

```bash
sudo apt install target/debian/carnine-backend_0.1.0-1_amd64.deb
```

## Current State

This is an initial executable skeleton. gRPC services and domain modules will be added incrementally.
