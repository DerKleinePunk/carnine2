# 09 Architecture Decisions

Record important decisions made during the design process, including alternatives and rationale.

## ADR-001: Technology Stack - Flutter Frontend + Rust Backend

**Status:** Accepted

**Context:**
The CarPC project requires a modern UI with hot-reload capability for rapid development, combined with high-performance backend processing for vehicle telemetry, CAN-bus communication, and media handling. The system runs on resource-constrained hardware (Raspberry Pi 4) and must handle real-time data streams.

**Decision:**
Use Flutter (Dart) for the frontend UI and Rust for the backend business logic. Communication between them via gRPC.

**Rationale:**
- **Flutter**: Hot-reload enables faster iteration; cross-platform widget library; strong type safety in Dart; can easily port to mobile later
- **Rust**: Memory safety without garbage collection; excellent performance for real-time tasks; strong ecosystem for systems programming (CAN, async I/O)
- **Separation of concerns**: Clear boundary between UI and business logic enables independent testing and deployment

**Alternatives considered:**
- Qt/C++ for both frontend and backend – would require more boilerplate; less rapid development cycle
- Python backend – insufficient performance for real-time CAN processing and concurrent connections
- Web-based frontend (React/Vue) – adds unnecessary complexity on embedded Linux; Flutter provides better control

**Consequences:**
- Requires learning both Dart and Rust; increased initial development time
- Need to maintain IPC layer (gRPC) between processes
- Better long-term maintainability and testability

---

## ADR-002: Inter-Process Communication - gRPC over Unix Domain Socket

**Status:** Accepted

**Context:**
Frontend (Flutter) and backend (Rust) run as separate processes. Need a reliable, strongly-typed communication mechanism with good performance and minimal latency.

**Decision:**
Use gRPC with Protocol Buffers for IPC, primarily over Unix domain sockets (fallback to TCP loopback).

**Rationale:**
- **Strong typing**: Proto definitions auto-generate client/server stubs in both languages; compile-time checking
- **Performance**: Binary serialization (Protocol Buffers) is faster than JSON
- **Streaming support**: gRPC streaming enables real-time data flows (e.g., vehicle telemetry updates)
- **Unix domain sockets**: Lower latency than TCP; no network stack overhead; filesystem-based security
- **Maturity**: Proven in production; libraries available for both Dart (gRPC Dart) and Rust (tonic)

**Alternatives considered:**
- REST over HTTP – less efficient; no built-in streaming; loosely typed
- Message queues (RabbitMQ, ZeroMQ) – overkill for local IPC; adds operational complexity
- Shared memory – unsafe without careful synchronization; harder to debug

**Consequences:**
- Need to define and maintain `.proto` files; code generation step in build process
- Slightly steeper learning curve than REST
- Excellent debugging and monitoring capabilities via gRPC tools

---

## ADR-003: Backend Language - Rust with Tokio Async Runtime

**Status:** Accepted

**Context:**
The backend must handle multiple concurrent tasks: CAN-bus polling, network requests, gRPC server, media processing. Resource constraints (Raspberry Pi 4) demand efficient concurrency without runtime overhead.

**Decision:**
Implement backend in Rust using Tokio for async I/O and task spawning.

**Rationale:**
- **Memory safety**: No garbage collector; predictable performance; no null pointer exceptions
- **Concurrency**: Async/await with Tokio enables handling hundreds of concurrent connections with minimal overhead
- **Type system**: Strong compile-time guarantees reduce runtime errors
- **Performance**: Zero-cost abstractions; codegen optimization at compile time
- **Error handling**: Rust's `Result` type with `anyhow::Result` and `?` operator ensures errors are not silently ignored

**Alternatives considered:**
- Go – good concurrency model but less control over memory; simpler but less safe
- C++ – full control but higher safety risks; more development time

**Consequences:**
- Steeper learning curve; longer initial development time
- Excellent runtime reliability and performance
- Compilation times are longer but provide strong guarantees

---

## ADR-004: Data Persistence - SQLite for Offline Data

**Status:** Accepted

**Context:**
System must work offline with cached data (maps, preferences, vehicle history). Needs a lightweight, self-contained database suitable for embedded systems.

**Decision:**
Use SQLite for local data storage, with synchronization logic for online reconciliation.

**Rationale:**
- **Lightweight**: Single file database; no server process required; perfect for Raspberry Pi
- **Offline support**: Data available even without network connectivity
- **Query capability**: Better than flat file storage for complex data access patterns
- **Reliability**: ACID transactions ensure data integrity during power loss scenarios
- **Embedded-friendly**: Widely used in automotive and embedded systems

**Alternatives considered:**
- PostgreSQL – overkill for single-device system; requires running server
- Firebase – tight coupling to cloud; problematic offline behavior
- Custom binary format – difficult to query; higher maintenance burden

**Consequences:**
- Need to manage database schema migrations
- Must implement offline-first sync logic for network data
- Excellent local performance and data integrity

---

## ADR-005: Real-time Data Streaming - gRPC Streaming for Vehicle Telemetry

**Status:** Accepted

**Context:**
Vehicle telemetry (speed, RPM, temperatures) must update the UI in real-time (<50ms latency). Traditional request-reply patterns introduce unnecessary latency.

**Decision:**
Use server-side gRPC streaming to push vehicle data updates from backend to frontend.

**Rationale:**
- **Low latency**: Server pushes data immediately; no polling overhead
- **Efficient**: Only transmits when data changes (with configurable update intervals)
- **Backpressure handling**: gRPC manages flow control automatically
- **Natural fit**: Rust Tokio streams map directly to gRPC streaming

**Alternatives considered:**
- Polling – excessive CPU usage on Raspberry Pi for frequent updates
- WebSockets – adds HTTP layer; less strongly typed
- Message queue – introduces latency; overkill for local IPC

**Consequences:**
- Requires implementing streaming handlers on backend
- Frontend must manage stream subscriptions and lifecycle
- Excellent real-time responsiveness

---

## ADR-006: CAN-Bus Integration - Direct RS232 via Custom Driver

**Status:** Accepted

**Context:**
Vehicle provides diagnostic and telemetry data over CAN-bus interface. System needs low-latency access to this data with minimal dependencies.

**Decision:**
Implement custom CAN-bus handler in Rust backend with direct RS232 communication to CAN interface hardware.

**Rationale:**
- **Control**: Custom driver allows optimization for specific hardware
- **Minimal dependencies**: Avoid heavy embedded libraries
- **Async-friendly**: Can be integrated into Tokio event loop
- **Performance**: Direct communication without middleware layers

**Alternatives considered:**
- SocketCAN (Linux kernel layer) – good but less portable; may not be available on all embedded Linux variants
- High-level CAN libraries – often include unnecessary features; harder to debug

**Consequences:**
- Increased complexity of backend implementation
- Deep knowledge of CAN protocol and RS232 communication required
- Complete control over data flow and timing

---

## ADR-007: Configuration Management - Rust `LazyLock` Static with TOML Files

**Status:** Accepted

**Context:**
System needs configuration for various parameters (update URLs, API keys, default preferences, CAN interface settings). Configuration should be readable/maintainable and loaded once at startup.

**Decision:**
Use TOML files for configuration storage with Rust `static` variables wrapped in `LazyLock` for thread-safe global access.

**Rationale:**
- **Human-readable**: TOML is easier to understand than JSON or YAML for manual editing
- **Lazy initialization**: `LazyLock` loads config only when first accessed; avoids startup overhead
- **Thread-safe**: Multiple tasks can safely read shared config
- **Type-safe**: Rust deserialization ensures config validity at startup

**Alternatives considered:**
- Environment variables – fine for simple settings; difficult for nested configs
- JSON – less readable; more verbose
- Dynamic reload – adds complexity; state management challenges

**Consequences:**
- Config must be valid TOML; errors halt startup (intentional for safety)
- Configuration changes require process restart
- Clear separation between code and configuration

---

## ADR-008: Error Handling - `anyhow::Result` with Context

**Status:** Accepted

**Context:**
Rust provides multiple error handling approaches. Need a strategy that provides good error context for debugging while remaining concise in code.

**Decision:**
Use `anyhow::Result<T>` for fallible operations, with `.context()` for adding contextual information at each level.

**Rationale:**
- **Context preservation**: Each layer can add context; final error includes full chain
- **Concise syntax**: `?` operator works naturally; avoids verbose error handling
- **Debugging**: Stack traces and context messages aid troubleshooting
- **Consistency**: Single error handling pattern across codebase

**Alternatives considered:**
- Custom error enums – more boilerplate; better type safety but harder to use
- Simple `Option<T>` – loses all error context
- `thiserror` crate – more structured but more verbose

**Consequences:**
- Errors are strings with context; no type-based error discrimination possible
- Excellent for system services where all errors should be logged
- Simpler error handling paths in code

---

## ADR-009: Code Organization - Modular Structure with `mod.rs` Files

**Status:** Accepted

**Context:**
Backend will grow to handle CAN, networking, media, storage, and other concerns. Need a clear structure that scales.

**Decision:**
Organize backend as modules with `mod.rs` files declaring submodules; each major concern (e.g., `can_handler`, `media`, `storage`) gets its own module directory.

**Rationale:**
- **Scoping**: Modules control visibility; public APIs are explicit
- **Encapsulation**: Internal implementation details remain private
- **Scalability**: Works well as codebase grows
- **Testing**: Modular structure supports unit testing of individual modules

**Alternatives considered:**
- Single file (like simple Python scripts) – unmaintainable at scale
- Flat file structure – no encapsulation; namespace pollution

**Consequences:**
- Clear boundaries between subsystems
- Easier to test components in isolation
- Well-defined interfaces between modules

---

## ADR-010: Logging and Tracing - `tracing` Crate for Structured Logging

**Status:** Accepted

**Context:**
System needs observability for debugging and monitoring. Traditional printf-style logging is insufficient for troubleshooting async/concurrent code.

**Decision:**
Use the `tracing` crate for structured logging with `debug!`, `info!`, and `error!` macros. Output to stdout/logs with filters for different verbosity levels.

**Rationale:**
- **Structured logging**: Logs include metadata and context; easier to parse and analyze
- **Async-aware**: Designed for async Rust code; tracks spans across await points
- **Performance**: Macros optimize away disabled levels
- **Ecosystem**: Integrates well with Tokio and other async crates

**Alternatives considered:**
- `log` crate – simpler but less powerful; lacks async awareness
- `println!` debugging – fine for development; poor for production observability
- `slog` – more complex configuration

**Consequences:**
- Structured logs can be filtered and analyzed programmatically
- Better visibility into system behavior in production
- Slight performance overhead (negligible on Raspberry Pi 4)

---

## ADR-011: Testing Strategy - Unit Tests in Module, Integration via gRPC

**Status:** Accepted

**Context:**
Need to validate backend functionality without running the full graphical application. Must support testing of business logic and IPC independently.

**Decision:**
Write unit tests directly in Rust modules for business logic. Integration tests call backend via gRPC client. Prefer tests over manual verification.

**Rationale:**
- **Avoiding UI**: Graphical testing is slow and error-prone; prefer automated tests
- **Unit tests**: Fast feedback loop; test individual components in isolation
- **Integration tests**: Verify IPC contract and end-to-end behavior
- **Regression prevention**: Test suite catches regressions early

**Alternatives considered:**
- Only integration tests – slower; harder to isolate issues
- Manual testing – time-consuming; unreliable

**Consequences:**
- Higher initial development time
- Test-driven development becomes natural
- System reliability significantly improved

---

## ADR-012: Concurrency Model - Tokio Tasks with `tokio::sync` Primitives

**Status:** Accepted

**Context:**
Multiple subsystems (CAN polling, gRPC server, media playback, network I/O) must execute concurrently without blocking.

**Decision:**
Use Tokio tasks for concurrent work; synchronize via `tokio::sync` channels and mutexes (Mutex, RwLock). Avoid blocking operations in async code.

**Rationale:**
- **Scalability**: Thousands of tasks share few OS threads; minimal overhead
- **Type safety**: Rust's ownership system prevents data races
- **Composability**: Tokio integrates seamlessly with async/await syntax
- **Well-tested**: Tokio is battle-tested in production systems

**Alternatives considered:**
- OS threads – higher memory overhead per task; more complex synchronization
- Futures without Tokio – requires managing executor; less integrated

**Consequences:**
- Must understand async/await patterns and Tokio APIs
- Excellent runtime efficiency
- No data races possible (enforced by compiler)

---

## ADR-013: Frontend Architecture - Widget-based with State Management

**Status:** Accepted

**Context:**
Flutter frontend must display multiple screens (navigation, media, settings, diagnostics). Need to manage shared state and navigate between screens efficiently.

**Decision:**
Use Flutter's widget composition model with a state management approach (Provider pattern or similar). Keep UI stateless where possible; manage shared state centrally.

**Rationale:**
- **Widget composition**: Declarative UI; changes naturally flow from state updates
- **Hot reload**: Enables rapid iteration during development
- **Separation**: Business logic remains in backend via gRPC; frontend focuses on presentation
- **Testability**: UI statelessness improves testability

**Alternatives considered:**
- Stateful widgets everywhere – difficult to manage complex state
- Custom state management – reinventing the wheel

**Consequences:**
- Clear data flow from state to UI makes debugging easier
- Hot reload shortens development cycle
- Lower coupling between UI components

---

## ADR-014: Offline-First Data Strategy - Cache with Sync

**Status:** Accepted

**Context:**
Connectivity is intermittent (vehicle may lose signal). Navigation maps, preferences, and vehicle history must remain available offline.

**Decision:**
Backend caches all necessary data locally (SQLite) and syncs with remote services when connectivity is available. UI always reads from cache; background sync keeps cache updated.

**Rationale:**
- **Reliability**: System works without network; critical for in-vehicle use
- **Performance**: Local cache is faster than network requests
- **Resilience**: Graceful degradation when offline; data converges when rejoined

**Alternatives considered:**
- Cloud-only – fails without network; unacceptable for vehicle environment
- No caching – forces network dependency; poor performance

**Consequences:**
- Need to implement sync logic and conflict resolution
- Data consistency complexity (what if offline changes conflict with server state?)
- Excellent user resilience and performance

---

## Decision Rationale Summary

These decisions collectively create a system that is:
- **Safe**: Type-safe languages (Rust, Dart) prevent entire classes of bugs
- **Performant**: Async concurrency and optimized serialization minimize latency
- **Reliable**: Offline-first caching and error handling ensure robustness
- **Maintainable**: Clear module boundaries and strong typing aid long-term development
- **Testable**: Separated frontend/backend and gRPC allow component testing without UI
