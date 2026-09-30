# 16 Conclusion

The documented architecture defines a clear split between a Flutter frontend and a Rust backend, connected via gRPC as typed IPC. This structure supports fast UI iteration, high-performance backend processing, and a modular path for future growth on Raspberry Pi 4 hardware.

The project has a strong architecture baseline across solution strategy, runtime behavior, deployment planning, quality goals, and risk management. UI/UX governance is explicitly anchored in Stitch and linked to the implementation workflow.

The system runs on the target hardware: Debian packages and SD-card images are built with scripts (`build_pi.sh`, `deploy_pi.sh`, the debos recipe), CI checks lint, tests and an arm64 build on every pull request, and the API contract lives in `src/proto/carnine.proto`. Open priorities are:
- CAN integration (adapter depends on the vehicle, docs/23)
- Automated tests on the device (today the device checks are done by hand)
- Measuring test coverage
- OTA updates

## Next Documentation Steps

1. Add missing planned diagrams from the figures catalog.
2. Keep ADRs updated whenever architecture-significant changes are made.
3. Expand API contract details as proto files stabilize.
4. Revisit quality targets after first on-device performance measurements.
5. Keep risk/debt tables synchronized with roadmap and implementation milestones.
