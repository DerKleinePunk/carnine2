# Future Work

## Planned Improvements

### Performance Optimizations
- [ ] Measure IPC p95/p99 latency on Raspberry Pi 4 under representative load
- [ ] Profile backend CPU hotspots (telemetry stream, serialization, storage I/O)
- [ ] Establish target budgets per subsystem (backend CPU, UI frame time, memory RSS)

### Refactoring Tasks
- [ ] Consolidate protocol contracts into a versioned schema workflow
- [ ] Introduce clear module boundaries for CAN, storage, network, and control services
- [ ] Align frontend state boundaries between ephemeral UI state and app state

### Testing Coverage
- [ ] Reach >= 70% backend test coverage for core services
- [ ] Reach >= 60% frontend unit/widget coverage for critical screens
- [ ] Add hardware-in-the-loop smoke tests on Raspberry Pi 4 for startup and reconnect

## Technical Debt

### Known Issues
- [ ] Build artifacts and project scaffolding are not yet present in repository
- [ ] CI/CD pipeline is not yet implemented
- [ ] Deployment instructions are documented but not fully automated

### Deprecated Patterns
- [ ] Avoid introducing internet-exposed remote control endpoints
- [ ] Avoid protocol split unless ADR-015 re-evaluation triggers are met

## Nice-to-Haves

### User Experience
- [ ] Add contextual degraded-mode UX when backend features are partially unavailable
- [ ] Add startup diagnostics screen for connectivity and service readiness

### Developer Experience
- [ ] Add one-command developer bootstrap scripts per platform
- [ ] Add local contract-check command to validate generated RPC stubs

### Monitoring & Observability
- [ ] Add structured log correlation IDs across frontend/backend requests
- [ ] Add periodic health snapshot export for field troubleshooting

## Priority Matrix

### High Impact, Low Effort
- [ ] Add CI lint/test skeleton workflows
- [ ] Add deployment and rollback checklists

### High Impact, High Effort
- [ ] Implement robust LAN-authenticated remote control stack
- [ ] Build full hardware-in-the-loop regression suite

### Low Impact, Low Effort
- [ ] Add architecture glossary examples for common error scenarios
- [ ] Add commit template for ADR-affecting changes

### Low Impact, High Effort
- [ ] Optional cloud telemetry dashboard (out of current scope)
