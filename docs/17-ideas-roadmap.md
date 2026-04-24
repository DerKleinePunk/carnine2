# Ideas & Roadmap

## Feature Ideas

### Short-term Ideas
- [ ] Define first stable `.proto` contract for core control and telemetry messages
- [ ] Implement minimal end-to-end vertical slice (frontend button -> backend RPC -> response)
- [ ] Add backend health endpoint and frontend connection banner handling
- [ ] Create reproducible local build scripts for backend and frontend

### Medium-term Ideas
- [ ] Integrate CAN telemetry ingestion with bounded update rates and UI throttling
- [ ] Add offline cache synchronization strategy for navigation/media metadata
- [ ] Introduce authenticated LAN remote control endpoint (no WAN exposure)
- [ ] Add systemd unit files and service recovery behavior on power cycles

### Long-term Vision
- [ ] Companion app operating only inside trusted LAN/VPN boundary
- [ ] OTA update hardening with staged rollout and rollback validation
- [ ] Field diagnostics package (logs, metrics snapshot, health report export)

## Enhancement Suggestions

### Frontend (Flutter)
- [ ] Standardize error-state widgets and recovery CTAs
- [ ] Add performance instrumentation for frame pacing on Raspberry Pi 4
- [ ] Define responsive layout constraints for 1024x600 and fallback sizes

### Backend (Rust)
- [ ] Finalize UDS-based gRPC transport behavior and reconnect policy
- [ ] Add structured error taxonomy and context propagation
- [ ] Add configuration layering (defaults, file, env overrides)

### Infrastructure / DevOps
- [ ] Establish GitHub Actions pipeline (lint, test, cross-build checks)
- [ ] Add deployment checklist and script templates for Pi provisioning
- [ ] Add firewall baseline enforcement test (LAN-only inbound policy)

## Notes
Roadmap items must reference one of: quality goals, ADRs, or risk entries.
Any feature that changes protocol boundaries requires ADR update before implementation.
