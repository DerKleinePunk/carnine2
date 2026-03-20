# 10 Quality Requirements

List the quality attributes (performance, security, maintainability, etc.) and how they are addressed.

## Quality Goals (Priority Order)

| # | Quality Attribute | Target | Rationale |
|---|-------------------|--------|-----------|
| 1 | **Reliability** | Backend availability ≥ 99.5% | UI fully depends on backend; loss of backend = system failure |
| 2 | **Responsiveness** | Connection loss detected within ≤ 500ms | User must immediately know of backend disconnect |
| 3 | **Performance** | UI remains responsive during operations | Raspberry Pi 4 is resource-constrained |
| 4 | **Security** | Encrypted communication (Backend ↔ UI) | CarPC may contain sensitive vehicle data |
| 5 | **Maintainability** | Code follows style guides (Rust/Flutter) | Two separate Code bases need clear conventions |
| 6 | **Robustness** | Graceful degradation on failures | Show error states instead of crashes |

---

## Quality Scenarios

### Scenario 1: Backend Connection Loss
- **Trigger:** Backend process crashes or network disconnects
- **Expected Response:** UI detects loss within 500ms and displays error banner
- **Success Criterion:** User is informed immediately; no hanging UI or silent failures

### Scenario 2: Startup Dependency
- **Trigger:** UI starts before backend is ready
- **Expected Response:** UI waits/retries connection with visual feedback
- **Success Criterion:** Clear error message; user knows what to do (restart backend)

### Scenario 3: High-Frequency Updates
- **Trigger:** Backend sends many sensor/state updates (10+ Hz)
- **Expected Response:** UI stays responsive; no frame drops or stuttering
- **Success Criterion:** Frame rate ≥ 60 FPS on Raspberry Pi 4

### Scenario 4: Security Threat
- **Trigger:** Network sniffing attempt on Backend ↔ UI communication
- **Expected Response:** All messages encrypted; unencrypted requests rejected
- **Success Criterion:** No sensitive data exposed in transit

---

## Quality Measures

### Reliability
- **How:** Heartbeat mechanism (ping/pong every 5-10s)
- **Tool:** Connection monitor in Flutter; timeout handler in Rust backend
- **Success Metric:** 99.5% uptime in production over 30 days

### Responsiveness
- **How:** WebSocket or gRPC with connection timeout detection
- **Metric:** Connection loss detected and UI updated within 500ms
- **Testing:** Unit tests + integration tests with simulated network failure

### Performance
- **How:** Monitor CPU/Memory usage on RPi4; profile hot paths
- **Metric:** App startup < 3s; API responses < 200ms; UI frame rate ≥ 60 FPS
- **Tools:** Flutter DevTools; Cargo profiling

### Security
- **How:** TLS/SSL encryption for all communication; input validation
- **Metric:** Zero security vulnerabilities in dependency scan
- **Tools:** `cargo audit`; Flutter security best practices

### Maintainability
- **How:** Code style enforcement; comprehensive tests
- **Metric:** ≥ 80% code coverage; CI/CD checks style compliance
- **Tools:** `cargo test`; `flutter test`; `cargo fmt` / `dart_format`

### Robustness
- **How:** Error handling with user-friendly messages; fallback UI states
- **Metric:** No unhandled exceptions in production; all errors logged
- **Tools:** Structured logging; error tracking

---

## Non-Functional Constraints

- **Deployment Platform:** Raspberry Pi 4 (4 GB RAM, ARM processor)
- **Backend Language:** Rust (must handle async I/O efficiently)
- **Frontend Language:** Flutter (cross-platform; must work on ARM Linux)
- **Network:** No guaranteed high-bandwidth connection; assume potential latency/packet loss
- **Battery:** N/A (plugged into car power)

---

## Trade-offs & Decisions

1. **UI depends 100% on backend** → Prioritize connection reliability over graceful offline mode
2. **Immediate error notification** → Accept minimal latency cost for heartbeat mechanism
3. **Resource constraints (RPi4)** → Optimize hot paths; prefer efficient algorithms over feature-richness
