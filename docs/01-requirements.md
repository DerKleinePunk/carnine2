# 01 Requirements and Goals

**Functional requirements**

* Display real‑time navigation/map data with routing and traffic information.
* Play audio and video from local storage and network sources.
* Display rear camera feed when available.
* Show vehicle telemetry (speed, RPM, temperatures) by reading the CAN bus.
* Provide a settings UI for user preferences and system configuration.
* Offer OTA updates when connected to the internet.

**Non‑functional requirements**

* **Performance**: UI should remain responsive with <50 ms input latency.
* **Reliability**: System must recover gracefully from power loss and network outages.
* **Resource constraints**: Run on Raspberry Pi 4 with limited memory/CPU.
* **Security**: Protect local data and restrict access to diagnostics APIs.

**Architectural goals**

* Separate frontend and backend concerns with a clear IPC boundary.
* Use technologies that facilitate cross‑platform testing and future mobile ports.
* Keep the backend lightweight with minimal dependencies to ease deployment.
