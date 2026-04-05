# 04 Solution Strategy

The architecture aims to balance rapid UI development and system performance. Key strategies include:

* **Technology split** – Flutter for UI to leverage hot‑reload and a modern widget library; Rust for backend to maximize speed and safety.
* **Modularity** – clearly define the boundary between frontend and backend using gRPC, allowing each to be developed and tested independently with generated stubs and strong typing.
* **Incremental design** – start with core features (navigation and media) and add capabilities such as CAN integration and OTA updates later.
* **Design source of truth** – create and maintain UI design templates in Stitch project 11236860998423822860; implementation in Flutter follows this template.
* **Reuse and standards** – use well‑supported crates in Rust and packages in Dart to minimize custom code; adopt arc42 itself to structure documentation.
* **Offline first** – services should cache necessary data for offline operation and reconcile when connectivity is restored.
