# 12 Glossary

Key terms used throughout the architecture documentation.

| Term | Definition |
|------|------------|
| **ADR** | Architecture Decision Record: documented technical decision with context, alternatives, and consequences. |
| **A/B Update** | Update strategy with two system partitions, enabling rollback if a new version fails. |
| **Arc42** | Template structure used to document software architecture in a consistent way. |
| **CAN Bus** | Vehicle communication bus used to transport telemetry and control messages between ECUs. |
| **CarPC** | The in-vehicle computer system described in this documentation. |
| **Delta Update** | OTA update containing only changed parts between software versions to reduce download size. |
| **Flutter** | UI framework used for the frontend application in this project. |
| **gRPC** | Typed RPC framework using Protocol Buffers, used for frontend-backend communication. |
| **Heartbeat** | Periodic liveness signal between components to detect disconnects quickly. |
| **I2C** | Two-wire bus protocol used here to control external relay hardware. |
| **IPC** | Inter-process communication between frontend and backend processes on the same device. |
| **OTA** | Over-the-air update mechanism for deploying software updates via network connection. |
| **Protocol Buffers (Protobuf)** | Interface definition and binary serialization format used by gRPC. |
| **RPi4** | Raspberry Pi 4, the target hardware platform for this system. |
| **RS232** | Serial communication interface used for power/ignition signaling in this setup. |
| **SocketCAN** | Linux CAN networking subsystem used to access CAN interfaces. |
| **Stitch** | UI/UX design tool used as source of truth for screen and component templates. |
| **Tokio** | Rust async runtime used in the backend for concurrent I/O and task scheduling. |
| **Unix Domain Socket (UDS)** | Local IPC socket type used as preferred transport for gRPC on-device communication. |
