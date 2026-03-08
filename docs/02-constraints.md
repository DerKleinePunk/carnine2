# 02 Constraints

* **Hardware**: Target platform is Raspberry Pi 4; CPU and RAM are limited compared to desktop machines.
* **Operating environment**: Car electrical system can supply noisy power; software must be robust against sudden shutdowns.
* **Connectivity**: Internet access is intermittent; application must work offline with cached data.
* **Regulatory**: While not certified for production vehicles, design should avoid features that could distract the driver.
* **Language & toolchain**: Frontend in Flutter (Dart), backend in Rust; bridging between them introduces a need for stable IPC.
* **Time**: Project being developed in spare time—architecture should avoid unnecessary complexity.
