# Protobuf Event Contract

Carnine uses the shared `src/proto/carnine.proto` file as the single source of
truth for the Rust backend and Flutter frontend.

## Event Types

The `LibraryEvent`, `PlayerEvent`, and `AudioEvent` messages use Proto3 enum
fields instead of free-form strings. The enum types are:

- `LibraryEventType` for scan, import, and media-discovery events
- `PlayerEventType` for player state and queue transitions
- `AudioEventType` for audio-device, source, and decoder lifecycle events

Each enum has an `*_UNSPECIFIED` zero value as required by Proto3. New event
values must be added to the relevant enum and handled in both generated-client
mappers before they are used by the services.

## Compatibility

The enum representation is intentional. There are no released clients using
the previous string-based event fields, so the contract can use the typed form
without a migration field or compatibility shim.

When the schema changes, regenerate the Dart stubs from `src/frontend`:

```bash
protoc -I ../proto --dart_out=grpc:lib/lib ../proto/carnine.proto
```

Rust stubs are generated automatically by the backend `build.rs` during Cargo
builds and checks.
