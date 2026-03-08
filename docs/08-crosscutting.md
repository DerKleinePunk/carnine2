# 08 Cross-cutting Concepts

This section describes architectural principles, patterns, and technologies that apply across multiple system components, ensuring consistency, maintainability, and reliability.

## 8.1 Logging and Monitoring

### Centralized Logging
- **Framework**: Rust backend uses `tracing` with JSON output to systemd journal
- **Flutter Frontend**: Uses `dart:developer` for debug logs, forwarded to backend via gRPC
- **Aggregation**: All logs collected in `/var/log/carnine/` with rotation via `logrotate`
- **Levels**: ERROR, WARN, INFO, DEBUG, VERBOSE (DEBUG/VERBOSE optional aktivierbar in Produktion für Troubleshooting)

### Health Monitoring
- **Backend Health Checks**: gRPC health service endpoint for liveness/readiness probes
- **System Metrics**: CPU, RAM, CAN bus status collected by a lightweight Rust daemon (no Node/Prometheus) writing to local journal
- **Alerting**: Critical errors are displayed on the UI and logged; user is notified directly rather than via external channels

## 8.2 Error Handling and Resilience

### Exception Handling
- **Rust Backend**: Result<T, E> pattern with custom error types; panics converted to controlled shutdowns
- **Flutter Frontend**: try-catch blocks with user-friendly error dialogs
- **Recovery Strategies**: Automatic restart on transient failures; graceful degradation for non-critical features

### Fault Tolerance
- **CAN Bus Failures**: Fallback to cached data; alert driver if communication lost >30s
- **Network Issues**: gRPC retries with exponential backoff; offline mode for navigation
- **Power Interruptions**: systemd service restart on boot; state persistence to avoid data loss

## 8.3 Security

### Authentication and Authorization
- **Local Access**: No authentication required (embedded device)
- **OTA Updates**: Signed packages with GPG verification
- **Network Security**: gRPC over local socket (no external exposure); SSH for remote access

### Data Protection
- **Sensitive Data**: Vehicle telemetry encrypted at rest using AES-256
- **Input Validation**: All gRPC messages validated against protobuf schemas
- **Secure Boot**: Raspberry Pi secure boot enabled for firmware integrity

## 8.4 Performance and Resource Management

### Resource Constraints
- **Memory**: <200MB RAM usage target; no memory leaks (Rust guarantees)
- **CPU**: <20% average load; real-time CAN processing prioritized
- **Storage**: <1GB app data; compressed logs and media cache

### Optimization Patterns
- **Async Processing**: Tokio runtime for non-blocking I/O
- **Caching**: In-memory LRU cache for navigation data; persistent SQLite for settings
- **Lazy Loading**: UI components loaded on-demand to reduce startup time

## 8.5 Communication Protocols

### Inter-Process Communication
- **gRPC**: Primary IPC between frontend/backend; protobuf for type safety
- **Unix Domain Sockets**: Local communication for security and performance
- **CAN Bus**: Vehicle data via socketcan; 500kbps bitrate with error detection

### External Interfaces
- **HTTP/REST**: OTA updates and map tiles (with caching)

## 8.6 Configuration Management

### Configuration Sources
- **Static Config**: Compiled-in defaults for hardware-specific settings
- **Runtime Config**: JSON files in `/etc/carnine/` for user preferences
- **Environment Variables**: For deployment-specific overrides (e.g., CAN bitrate)

### Hot Reloading
- **Settings**: Changes applied without restart via gRPC config endpoint
- **Feature Flags**: Runtime toggles for experimental features

## 8.7 Testing and Quality Assurance

### Unit Testing
- **Rust**: `cargo test` with >80% coverage; mocks for hardware interfaces
- **Flutter**: Widget tests and unit tests with Mockito for gRPC mocking

### Integration Testing
- **End-to-End**: Automated tests on target hardware using Flutter Driver
- **CAN Simulation**: Virtual CAN interfaces for testing without real vehicle

### Continuous Integration
- **Build Pipeline**: GitHub Actions for cross-compilation and basic tests
- **Code Quality**: Clippy (Rust), Flutter analyze; pre-commit hooks

## 8.8 Deployment and Updates

### Over-the-Air Updates
- **Mechanism**: Delta updates via HTTP download; A/B partitions for rollback
- **Validation**: Checksum verification and signature validation
- **Scheduling**: Updates applied during ignition off; user notification required

### Rollback Strategy
- **Automatic**: Failed updates trigger rollback to previous version
- **Manual**: SSH access for emergency recovery

## 8.9 Internationalization (i18n)

### Language Support
- **Primary**: German (de) with English (en) fallback
- **Implementation**: Flutter's intl package; Rust uses fluent for backend strings
- **Date/Number Formats**: Locale-aware formatting for vehicle data display
