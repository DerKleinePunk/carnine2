# 11 Risks and Technical Debt

Identify risks and areas of technical debt, along with mitigation strategies.

---

## Risks

### 1. Backend Dependency & Single Point of Failure

| Attribute | Value |
|-----------|-------|
| **Risk** | UI completely depends on backend; if backend crashes, entire system is non-functional |
| **Impact** | High — Complete system failure; user cannot interact with CarPC |
| **Likelihood** | Medium — Process crashes, memory leaks, or infinite loops possible |
| **Mitigation** | • Auto-restart mechanism for backend process<br>• Supervisor/systemd service to manage backend lifecycle<br>• Health check / heartbeat every 5-10s<br>• Clear error UI when backend unavailable |
| **Status** | Partly mitigated — both services run under systemd with `Restart=on-failure`; the frontend detects a lost or frozen backend through a heartbeat (`backend_heartbeat.dart`: every 5 s a `GetServiceVersion` call with a 3 s deadline) and shows a connection banner (#58) |
| **Owner** | Backend Team |

### 2. ARM Architecture Compatibility

| Attribute | Value |
|-----------|-------|
| **Risk** | Rust crates may not have ARM builds; build failures on Raspberry Pi 4 |
| **Impact** | Medium — Project cannot deploy to target hardware |
| **Likelihood** | Medium — Some crates may need custom compilation or alternatives |
| **Mitigation** | • Test all dependencies on ARM64 early<br>• Use `cargo audit` + `cargo tree` to check for ARM-only crates<br>• Maintain compatibility matrix of known-good versions<br>• Have fallback crates if primary ones fail |
| **Status** | Mitigated — CI builds a native arm64 release; backend and frontend run on Pi 4 and Pi 3 |
| **Owner** | Backend Team |

### 3. Resource Constraints on Raspberry Pi 4

| Attribute | Value |
|-----------|-------|
| **Risk** | Memory (4 GB), CPU, and disk space may be insufficient; performance degradation |
| **Impact** | Medium-High — App slowness, unexpected crashes, poor UX |
| **Likelihood** | Medium — Depends on feature scope and optimization effort |
| **Mitigation** | • Profile app early on RPi4 hardware<br>• Set strict performance budgets (CPU, memory, startup time)<br>• Use lazy-loading, pagination, caching where possible<br>• Monitor metrics: RSS, CPU %, frame rate |
| **Status** | Open — Requires profiling |
| **Owner** | DevOps / Performance Team |

### 4. gRPC over Unix Sockets — Custom Transport Implementation

| Attribute | Value |
|-----------|-------|
| **Risk** | Unix socket integration details in chosen gRPC stack may require adapter code and careful testing |
| **Impact** | Medium — Significant complexity; potential bugs in IPC layer; performance implications |
| **Likelihood** | Medium-High — Depends on final library/runtime choices |
| **Mitigation** | • Validate UDS approach with a minimal end-to-end spike early<br>• Test reconnection logic, error handling, and lifecycle behavior<br>• Ensure protobuf code generation is automated in build.rs<br>• Document socket path, permissions, and connection model thoroughly |
| **Status** | Mitigated — `server_transport.rs` serves tonic on a Unix socket, `build.rs` generates the protobuf code, reconnect fixed in #44 |
| **Owner** | Backend Team |

### 5. Dependency Updates & Breaking Changes

| Attribute | Value |
|-----------|-------|
| **Risk** | Minor/patch updates in Rust crates or Flutter packages may introduce breaking changes |
| **Impact** | Medium — Unplanned refactoring; build failures |
| **Likelihood** | Medium — Open-source ecosystem evolves rapidly |
| **Mitigation** | • Lock dependencies to tested minor versions (`Cargo.lock`, `pubspec.lock`)<br>• Regular (monthly) audit: `cargo audit`, `flutter pub outdated`<br>• CI/CD runs dependency checks on each PR<br>• Maintain upgrade changelog / decision log |
| **Status** | Mitigated — lock files are versioned; CI builds an SBOM and checks it with grype on each push and PR, `build_pi.sh` writes an SBOM and CVE report per package and the image recipe one for the image (#41). Upgrades remain a manual decision |
| **Owner** | Infra Team |

### 6. Security: Unix Socket Access Control

| Attribute | Value |
|-----------|-------|
| **Risk** | Unix Socket (local IPC) has incorrect filesystem permissions; other local processes could eavesdrop/hijack communication |
| **Impact** | Medium — If another process on RPi4 is compromised, could intercept vehicle commands |
| **Likelihood** | Low — Sockets are local-only; requires privilege escalation or running untrusted code on RPi4 |
| **Mitigation** | • Set strict permissions on Unix socket: `0600` (owner read/write only)<br>• Enforce that only intended UI process can connect to socket<br>• Use systemd socket activation with user constraints<br>• Validate all IPC messages (don't trust local peers)<br>• Document socket path and access model |
| **Status** | Mitigated — socket mode defaults to `0600` (`CARNINE_SOCKET_MODE` or config to change), runtime directory `0700` |
| **Owner** | Backend Team |

### 7. Cross-Platform Flutter Widget Compatibility

| Attribute | Value |
|-----------|-------|
| **Risk** | Flutter on Linux (ARM64) may have UI/platform differences vs. Android/iOS |
| **Impact** | Medium — Visual bugs, missing features, input handling issues |
| **Likelihood** | Medium — Flutter on Linux desktop is less mature than mobile |
| **Mitigation** | • Test on actual Raspberry Pi Linux environment early<br>• Use Flutter's platform channel only when necessary<br>• Stick to cross-platform widgets; minimize platform-specific code<br>• Monitor Flutter Linux roadmap for deprecations |
| **Status** | Medium — Requires testing on target OS |
| **Owner** | Frontend Team |

---

## Technical Debt

### Backend (Rust)

| Item | Description | Impact | Effort | Priority |
|------|-------------|--------|--------|----------|
| **Error Handling Standardization** | Mix of `.map_err()`, `?`, and `.unwrap()`; no consistent pattern | Medium | Low | Medium |
| **Logging / Observability** | Done: `tracing` to stdout and `backend.log` (capped at 50 MB) | Medium | Medium | Done |
| **Test Coverage** | Coverage is not measured yet; many edge cases untested | High | High | High |
| **API Documentation** | Missing doc comments on public functions; unclear contracts | Medium | Low | Medium |
| **Module Organization** | May need refactoring as complexity grows (mod.rs structure review) | Low | Medium | Low |
| **gRPC + Unix Socket Integration** | Done: `tonic` server & client over Unix sockets (`server_transport.rs`) | Medium | Medium | Done |
| **Protobuf Code Generation** | Done: `build.rs` generates the code from `src/proto` | Medium | Low | Done |
| **Async Runtime Tuning** | `tokio` config (thread pools, timers) not optimized for RPi4 | Medium | Medium | Medium |
| **Configuration Management** | Done: TOML with `config.d` drop-ins and `CARNINE_*` overrides | Medium | Low | Done |

### Frontend (Flutter)

| Item | Description | Impact | Effort | Priority |
|------|-------------|--------|--------|----------|
| **State Management** | Manual ChangeNotifier; may become unwieldy as app grows | Medium | Medium | Medium |
| **Error UI Patterns** | Error handling in multiple places; inconsistent user messaging | Medium | Low | Medium |
| **Test Coverage** | Coverage is not measured yet; no integration tests on the device | High | High | High |
| **Responsive Design** | May need tuning for various screen sizes / orientations | Low | Medium | Low |
| **Performance Profiling** | No baseline metrics for frame rate, memory on RPi4 | High | Medium | High |
| **Navigation Structure** | Router/navigation pattern unclear; may need refactoring | Medium | High | Medium |
| **Localization i18n** | Done: 15 languages in `lib/l10n/translations/` | Low | Medium | Done |

### DevOps / Infrastructure

| Item | Description | Impact | Effort | Priority |
|------|-------------|--------|--------|----------|
| **CI/CD Pipeline** | Done: GitHub Actions runs fmt, clippy, tests, analyze, an arm64 build and an SBOM/CVE check on each PR; deployment is still manual | High | High | Done |
| **Backend Autostart** | Done: `carnine-backend.service` and `carnine-frontend.service` in the Debian packages | High | Low | Done |
| **Deployment Process** | Scripted: `build_pi.sh`, `deploy_pi.sh` and the debos image recipe (`docs/07-deployment.md`) | High | Medium | Medium |
| **Monitoring & Logging** | No centralized logging; hard to diagnose failures in field | Medium | Medium | Medium |
| **Image Management** | Building documented (`resources/debos/`, docs/07); distribution is manual | Medium | Medium | Low |

### Documentation Debt

| Item | Description | Impact | Effort | Priority |
|------|-------------|--------|--------|----------|
| **Architecture Decision Log** | ADRs are available, but consistency checks against quality/risk docs must be maintained continuously | Medium | Low | Medium |
| **API Specification** | Done: `src/proto/carnine.proto`, events in docs/21 | High | Medium | Done |
| **Setup/Deploy Guide** | docs/07 with scripts and the image recipe | High | Low | Low |
| **Code Comments** | Business logic not explained; future maintainers confused | Medium | Low | Medium |

---

## Debt Retirement Plan

### Phase 1 (Immediate — Next Sprint)
- [x] Implement CI/CD pipeline (GitHub Actions or similar)
- [x] Add systemd service for auto-restart backend
- [x] Convert deployment guide into reproducible scripts/checklists
- [ ] Standardize error handling patterns (Rust `anyhow`, Flutter `try-catch`)
- [ ] Enforce and test LAN-only inbound policy (firewall + bind-address checks)

### Phase 2 (Short-term — Next 2-4 Weeks)
- [ ] Achieve ≥ 70% test coverage (Rust + Flutter)
- [x] Set up structured logging (Rust: `tracing`; Flutter: `package:logging`)
- [x] Implement gRPC over Unix sockets with tonic (custom tower transport)
- [x] Finalize `.proto` definitions and automate code generation in `build.rs`
- [x] Profile performance on RPi4 hardware (map frame times and long-run tests on the Pi, see docs/19)

### Phase 3 (Medium-term — Next Month)
- [ ] Document all API contracts (OpenAPI or similar)
- [ ] Refactor state management if complexity exceeds thresholds
- [ ] Security audit & penetration testing
- [ ] Set up production monitoring / alerts

---

## Assumptions & Dependencies

- Assumes Rust dependency ecosystem has ARM64 support for chosen crates
- Assumes Flutter on Linux (ARM64) is stable enough for production
- Assumes CI/CD platform available (GitHub Actions, GitLab CI, etc.)
- Assumes team has access to Raspberry Pi 4 hardware for early testing
