# 15 Appendices

Supplementary information and quick reference material.

## Appendix A - Important Paths

- Backend source: `src/backend`
- Frontend source: `src/frontend`
- Architecture docs: `docs`
- Runtime config target (planned): `/etc/carnine/`
- Runtime logs target (planned): `/var/log/carnine/`
- Deployment target root (planned): `/opt/carnine/`

## Appendix B - Core Build and Validation Commands

### Backend (Rust)

```bash
cd src/backend
cargo fmt --all
cargo clippy --all-targets --all-features -- -D warnings
cargo test
```

### Frontend (Flutter)

```bash
cd src/frontend
flutter pub get
flutter analyze
flutter test
```

## Appendix C - Documentation Acceptance Checklist

- [ ] Requirements reflect all agreed major features (navigation, media, telemetry, rear camera, OTA).
- [ ] At least one ADR exists for each major architectural decision area.
- [ ] Runtime view contains executable interaction scenarios.
- [ ] Deployment view covers target hardware and installation flow.
- [ ] Risks and technical debt include mitigation and owners.
- [ ] References are up-to-date and reachable.
