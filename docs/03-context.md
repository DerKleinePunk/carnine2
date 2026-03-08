# 03 Context and Scope

The CarPC system runs as a standalone unit inside the vehicle. Its primary actors include:

* **Driver/Passenger** – interacts with the touchscreen UI for navigation, media, and settings.
* **Vehicle** – provides sensor data via the CAN bus and receives control commands (e.g., display backlighting).
* **External services** – map APIs, update servers, and media streaming sources accessed over Wi‑Fi or mobile tethering.

Scope of this documentation is limited to the software architecture; hardware details (mounts, wiring) are out of scope. It also focuses on the on‑device components; companion mobile apps or cloud backend are not covered.

The system consists of two main blocks:

* **Flutter frontend** – UI layer running in a Linux window with access to touchscreen input.
* **Rust backend** – headless service handling business logic, CAN communication, data storage, and network I/O.

Interaction between the two uses gRPC over a local socket (Unix domain socket or TCP loopback) to enable strongly‑typed messages and better performance.
