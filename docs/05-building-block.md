# 05 Building Block View

The Building Block View describes the static structure of the system by decomposing it into hierarchical building blocks. These building blocks represent modules, components, and their relationships. The view starts with a blackbox view of the entire system and refines into levels down to detailed components.

## Level 1: Overall System (Blackbox View)

The CarPC system runs as a standalone unit on the Raspberry Pi 4. It consists of two main building blocks:

- **Flutter Frontend**: Responsible for the user interface and interaction.
- **Rust Backend**: Handles business logic, data processing, and external interfaces.

Relationship: Communication via gRPC over local sockets.

## Level 2: Flutter Frontend (Whitebox View)

The Flutter Frontend is a Dart application running in a Linux window and utilizing the touchscreen.

- **UI Widgets**: Components for navigation (map, routing), media player, vehicle telemetry display, settings.
- **State Management**: Manages application state and synchronizes with the backend.
- **gRPC Client**: Sends requests to the backend and receives responses.

Relationships: Widgets interact with state management; gRPC client connects to the backend.

## Level 2: Rust Backend (Whitebox View)

The Rust Backend is a headless service executing the core logic.

- **CAN-Bus Handler**: Reads and writes vehicle data over the CAN bus.
- **Data Storage**: Local database or filesystem for caching and configuration.
- **Network Manager**: Handles internet connections for updates and external APIs.
- **gRPC Server**: Provides APIs for the frontend and processes requests.
- **Media Processor**: Manages audio/video decoding and playback.
- **I²C Relay Controller**: Manages 8 relays connected via I²C bus to switch power consumers (e.g., lights, fans, or other vehicle accessories).

Relationships: All components communicate internally; gRPC server connects to the frontend; CAN-Bus Handler and Network Manager access hardware/external systems; Power Management interacts with the RS232-connected power supply and system shutdown APIs; I²C Relay Controller interacts with I²C hardware and receives commands via gRPC Server.

## Level 3: Detailed Components (Examples)

- **Navigation Service** (in Backend): Calculates routes, integrates map data.
- **Media Library** (in Backend): Indexes local media and streams content.
- **Settings Manager** (in Backend): Stores and loads user preferences.

This level can be further refined depending on implementation complexity.
