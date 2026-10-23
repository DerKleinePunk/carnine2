# 10 Quality Requirements

List the quality attributes (performance, security, maintainability, etc.) and how they are addressed.

## Quality Goals (Priority Order)

| # | Quality Attribute | Target | Rationale |
|---|-------------------|--------|-----------|
| 1 | **Reliability** | Backend availability ≥ 99.5% | UI fully depends on backend; loss of backend = system failure |
| 2 | **Responsiveness** | Connection loss detected within ≤ 500ms | User must immediately know of backend disconnect |
| 3 | **Performance** | UI remains responsive during operations | Raspberry Pi 4 is resource-constrained |
| 4 | **Security** | Encrypted and authenticated communication for network-exposed endpoints | Remote control and diagnostics can carry sensitive vehicle data |
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
- **Trigger:** Network sniffing or unauthorized access attempt on LAN-exposed control endpoints
- **Expected Response:** Encrypted transport and authentication enforced; unauthorized requests rejected
- **Success Criterion:** No sensitive data exposed in transit

---

## Quality Measures

### Reliability
- **How:** Heartbeat from the frontend (`backend_heartbeat.dart`: every 5 s `GetServiceVersion` with a 3 s deadline; the first failure closes the channel hard and the reconnect loop takes over, #58); systemd restarts a failed backend. The long-lived channels run without HTTP/2 keepalive, which never noticed a frozen backend
- **Tool:** Connection banner in Flutter; no separate timeout handler in the Rust backend. A frozen backend is noticed after at most about 8 s
- **Success Metric:** 99.5% uptime in production over 30 days

### Responsiveness
- **How:** gRPC with a heartbeat call that has a deadline
- **Metric:** Connection loss detected and UI updated within 500ms
- **Testing:** Unit tests + integration tests with simulated network failure

#### Rear camera latency (measured 2026-10-21 and 2026-10-23, jeep-pi)

Measured on a Pi 4 (kernel 6.18.50) with CarNine 0.19.1, without a person in the loop: the Pi switches a trigger
itself and measures when the change shows up in the picture. Each run takes 60 s with 75–90 changes; every change
was detected. Where a row has two runs, they are given as "run 1 / run 2". The tools are in
[resources/tools/camera-latency/](../resources/tools/camera-latency/LIESMICH.md) (`latency_panel.py` for the
grabbers, `latency_led.py` for the USB camera).

Analog grabbers. The trigger is the panel turning black or white, the analog camera (NTSC) looks at the panel.
Measured: panel → camera → grabber → Pi, without CarNine.

| Grabber | Median | 10 % | 90 % | Frames/s |
|---|---|---|---|---|
| STK1160 | 68 / 71 ms | 39–40 ms | 98–103 ms | 31.2 |
| Somagic SMI-2021 (EasyCAP002) | 69 / 70 ms | 50–52 ms | 83–84 ms | 31.0 |

USB camera (Jieli 1224:2a25), 640 × 480. The trigger is the green ACT LED of the Pi, the camera looks at it.
On 2026-10-21 in low light, on 2026-10-23 with more light.

| Date | Path | Format | Median | 10 % | 90 % | Frames/s |
|---|---|---|---|---|---|---|
| 10-21 | Camera alone (V4L2, CarNine stopped) | YUYV | 103 / 103 ms | 46–54 ms | 154–164 ms | 12.5 |
| 10-21 | Camera → CarNine → display output | YUYV | 115 / 112 ms | 57–61 ms | 167–173 ms | 12.6 |
| 10-23 | Camera alone (V4L2, CarNine stopped) | YUYV | 148 ms | 126 ms | 174 ms | 24.8 |
| 10-23 | Camera → CarNine → display output | YUYV | 154 ms | 132 ms | 177 ms | 24.1 |
| 10-23 | Camera alone, decoded with ffmpeg | MJPG | 85 ms | 74 ms | 97 ms | 31.2 |
| 10-23 | Camera → CarNine → display output | MJPG | 57 / 60 / 58 ms | 43–45 ms | 73–78 ms | 30.4–30.5 |
| 10-23, less light | Camera → CarNine → display output | MJPG | 93 ms | 60 ms | 121 ms | 16.6 |

- **CarNine itself** (video_grabber up to the hardware plane) adds about **10 ms** (6–12 ms in the three YUYV pairs).
- Both analog grabbers are equally fast on average, about two frames at NTSC. The Somagic varies less.
  Of the two, CarNine supports only the STK1160 so far; the Somagic is #160.
- The frame rate does not explain the USB camera's delay: with more light it ran at 25 instead of 12.5 frames/s
  but was slower in YUYV (148 instead of 103 ms). It seems to buffer frames itself in YUYV; the cause is open.
- Through CarNine, MJPG took 57–60 ms instead of 154 ms in YUYV, decoding included (the first two runs with a
  drop-in before and after 30 min on the camera page, the third with the build that has MJPEG as default). So
  CarNine prefers MJPEG for a USB camera since video_grabber 14e3a66 (carnine2 5ce03e5,
  [docs/07](07-deployment.md#reversing-camera)). The "camera alone" MJPG run used a one-off wrapper around
  ffmpeg, which costs time of its own; the tools in the repo read YUYV only.
- In MJPG less light does cost time: the last row is the build with MJPEG as default, without a drop-in,
  later the same day in a darker scene. The camera exposed longer and delivered fewer frames.
- Not included: the way from the display output to the light of the panel, up to 16 ms at 60 Hz.

### Performance
- **How:** Monitor CPU/Memory usage on RPi4; profile hot paths
- **Metric:** App startup < 3s; API responses < 200ms; UI frame rate ≥ 60 FPS
- **Tools:** Flutter DevTools; Cargo profiling

### Security
- **How:**
	- Local frontend-backend IPC uses Unix domain sockets with strict filesystem permissions
	- LAN-exposed remote endpoints use TLS plus authentication/authorization
	- No internet exposure of control interfaces (LAN-only policy)
	- Input validation on all RPC messages
- **Metric:** No Critical finding with an available fix in the dependency scan (CI fails on it); other findings are reviewed from the report
- **Tools:** SBOM with syft and CVE check with grype in CI and in `build_pi.sh` (#41, accepted findings in `.grype.yaml`); Flutter security best practices

### Maintainability
- **How:** Code style enforcement; comprehensive tests
- **Metric:** ≥ 80% code coverage (target; coverage is not measured yet); CI checks `cargo fmt`, clippy and `flutter analyze` on each PR
- **Tools:** `cargo test`; `flutter test`; `cargo fmt`; `dart format` (run locally, not in CI)

### Robustness
- **How:** Error handling with user-friendly messages; fallback UI states
- **Metric:** No unhandled exceptions in production; all errors logged
- **Tools:** Structured logging; error tracking

### Communication Protocol Strategy (linked to ADR-015)
- **Decision:** Use gRPC/protobuf as unified protocol for local IPC and future remote APIs
- **Reason:** Minimize complexity and maintenance risk while keeping sufficient performance on Raspberry Pi 4
- **Transport guideline:** Prefer Unix domain sockets for local IPC, streaming for high-frequency updates, channel reuse for low overhead

#### Protocol Decision Matrix

| Criterion | Weight | gRPC (single protocol) | Hybrid (gRPC remote + Cap'n Proto local) | Notes |
|---|---:|---:|---:|---|
| Maintainability | 30% | 5/5 | 2/5 | One IDL and one codegen pipeline vs. two protocol stacks |
| Flutter/Dart ecosystem maturity | 25% | 5/5 | 2/5 | gRPC Dart is mature; Cap'n Proto Dart path is limited |
| Raspberry Pi 4 local IPC performance headroom | 20% | 4/5 | 5/5 | Hybrid may win in extreme throughput cases |
| Mobile remote-control readiness | 15% | 5/5 | 3/5 | gRPC contracts are directly reusable for remote app |
| Integration/testing complexity | 10% | 5/5 | 2/5 | Single protocol reduces contract drift and test matrix size |
| **Weighted total** | **100%** | **4.8 / 5** | **2.7 / 5** | Choose gRPC-first unless measurements force re-evaluation |

#### Re-evaluation Triggers (when to consider Cap'n Proto)

Revisit the protocol strategy only if all of the following are true on Raspberry Pi 4:

1. **Measured bottleneck:** IPC path is a top contributor to end-to-end latency or CPU
2. **Threshold breach (sustained):**
	 - Backend CPU attributable to IPC serialization/transport > 20% average during representative load, or
	 - p95 IPC round-trip latency for control commands > 50ms on local link, or
	 - Telemetry path cannot sustain target update rate (>= 10Hz) without visible UI degradation
3. **gRPC tuning exhausted:** UDS transport, channel reuse, streaming strategy, payload sizing, and backpressure handling already optimized
4. **Operational readiness:** A production-viable Dart strategy for Cap'n Proto is available and team accepts long-term dual-protocol ownership

#### Verification Plan for Protocol Fitness

- **Test setup:** Run representative navigation/media/CAN workloads on target Raspberry Pi 4
- **Metrics to record:** CPU%, RSS memory, p95/p99 local RPC latency, dropped/late telemetry updates, UI frame pacing
- **Pass criteria (stay on gRPC):**
	- UI remains responsive (target >= 60 FPS where applicable)
	- Command RPC p95 < 50ms locally
	- No sustained IPC-induced CPU pressure violating system targets
- **Cadence:** Re-run profiling after major feature additions affecting telemetry or command throughput

---

## Non-Functional Constraints

- **Deployment Platform:** Raspberry Pi 4 (4 GB RAM, ARM processor)
- **Backend Language:** Rust (must handle async I/O efficiently)
- **Frontend Language:** Flutter (cross-platform; must work on ARM Linux)
- **Network:** No guaranteed high-bandwidth connection; assume potential latency/packet loss
- **Remote Access Boundary:** Remote control reachable only from local network (LAN), not from public internet
- **Battery:** N/A (plugged into car power)

---

## Trade-offs & Decisions

1. **UI depends 100% on backend** → Prioritize connection reliability over graceful offline mode
2. **Immediate error notification** → Accept minimal latency cost for heartbeat mechanism
3. **Resource constraints (RPi4)** → Optimize hot paths; prefer efficient algorithms over feature-richness
