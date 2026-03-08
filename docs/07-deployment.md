# 07 Deployment View

## Overview

The CarPC system is deployed on an embedded Linux device (Raspberry Pi 4) with two main service components:
- **Rust backend service** (headless) – handles business logic, CAN communication, and data operations
- **Flutter frontend application** – runs in a windowed GUI environment with touchscreen input

The deployment architecture emphasizes reliability, minimal resource consumption, and support for over-the-air (OTA) updates.

---

## 7.1 Hardware Environment

### Target Platform
- **Hardware**: Raspberry Pi 4 Model B (4GB or 8GB RAM recommended)
- **Processor**: ARM Cortex-A72 (4x 1.5 GHz cores)
- **Storage**:
  - Root filesystem: microSD card (64 GB minimum; consider industrial‑grade cards for embedded reliability)
  - Optional: SSD via USB 3.0 for extended logging and media cache
- **RAM**: 4GB minimum (8GB recommended to avoid swap pressure)

### Peripherals and Interfaces
- **Display**: Waveshare 7" HDMI touchscreen ([wiki](https://www.waveshare.com/wiki/7inch_HDMI_LCD_(H)_(with_case)))
  - Connection: HDMI video + USB for touch input
  - Resolution: 1024×600 (native)
  - Requires correct HDMI modes in `/boot/config.txt`
- **CAN Interface**:
  • Adapter: MCP2515 (SPI) or isolated CAN HAT (e.g. PiCAN 2, Kvaser)
  • Protocol: CAN 2.0B, 500 kbps or 1 Mbps (vehicle‑specific)
  • Connection: SPI bus or USB
- **Power Supply**:
  • USB‑C: 5 V/3 A minimum (ensure quality supply to avoid voltage sag)
  • Optional: battery backup (UPS HAT) for graceful shutdown on power loss
- **Networking**:
  • Ethernet: recommended for reliable initial deployment and updates
  • Wi‑Fi: built‑in 802.11ac for remote diagnostics/OTA updates

### System Integration
- **Cooling**: Active cooling (fan) required for automotive environment; passive heatsink insufficient for sustained operation in vehicle
- **Mounting**: DIN‑rail or vehicle‑specific enclosure with vibration damping
- **Environmental**: automotive temp range (0 °C–50 °C); mitigate electrical noise with shielded CAN harnesses

---

## 7.2 Software Prerequisites

### Raspberry Pi (Runtime Only)

#### Operating System
- **OS**: Raspberry Pi OS (Debian‑based, 64‑bit preferred)
  • Kernel 5.10+ with `CONFIG_CAN=y`
  • `systemd` for service management

#### Runtime Dependencies (on Pi)
- **CAN Driver**: `socketcan` kernel module loaded (`modprobe can`, `modprobe can_raw`)
- **System libraries**:
  - `libgl1-mesa-glx` (Mesa OpenGL for flutter_pi)
  - `libssl3` (OpenSSL runtime)
  - `curl` (for OTA updates)

### Workstation (x86_64 Linux)

#### Build Dependencies (Workstation Only)

**Rust Backend Cross‑Compilation**
- Rust toolchain with `aarch64-unknown-linux-gnu` target (installed via `rustup`)
- `protobuf-compiler` 3.20+
- Standard build tools (gcc, make, pkg‑config)

**Flutter Frontend Cross‑Compilation**
- Flutter SDK 3.10.5+
- `flutterpi_tool` ([GitHub](https://github.com/ardera/flutterpi_tool)) build engine
- Standard build tools

#### System Packages (apt) on Workstation

```bash
sudo apt-get update && sudo apt-get install -y \
  build-essential \
  pkg-config \
  libssl-dev \
  protobuf-compiler \
  git \
  curl
```

#### Development & Debugging Tools
- **SSH client** (for deploying binaries to Pi)
- **gdb‑multiarch** or **lldb** (remote debugging on Pi)
- **IDE with Rust/Dart support**:
  - VS Code + Rust Analyzer + Dart extensions
  - JetBrains IntelliJ / CLion / Android Studio
- **Remote debugging setup**: IDE extensions for remote debugging over SSH

---

## 7.3 Installation Steps

### 3.1 Operating System Setup

1. **Write OS image** to microSD card:

   ```bash
   # on workstation
   sudo dd if=2024-12-05-raspios-bookworm-arm64.img \
       of=/dev/sdX bs=4M status=progress
   sync
   ```

2. **Enable kernel modules/interfaces**:

   ```bash
   sudo raspi-config
   # enable SPI, I2C, disable serial console if using hardware UART for CAN,
   # set boot to Desktop.
   ```

3. **Configure CAN (socketcan)**:

   ```bash
   sudo tee /etc/network/interfaces.d/can0 > /dev/null <<'EOF'
   auto can0
   iface can0 can static
       bitrate 500000
       up ip link set \$IFACE type can bitrate 500000 restart-ms 100
       down ip link set \$IFACE down
   EOF

   sudo systemctl restart networking
   ip link show can0  # should be UP
   ```

4. **Update packages**:

   ```bash
   sudo apt-get update && sudo apt-get upgrade -y
   ```

### 3.2 Build Backend (Rust)

**Build on workstation (Linux), then transfer to Pi.**

1. Install Rust toolchain:

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   rustup target add aarch64-unknown-linux-gnu
   ```

2. Build:

   ```bash
   cd src/backend
   cargo build --release --target aarch64-unknown-linux-gnu
   mkdir -p build/backend
   cp target/aarch64-unknown-linux-gnu/release/carnine-backend build/backend/
   ```

### 3.3 Build Frontend (Flutter via flutterpi_tool)

**Build on workstation (Linux), then transfer to Pi.**

1. **Install flutterpi_tool** on workstation:

   ```bash
   flutter pub global activate flutterpi_tool
   ```

2. **Build Flutter app** with flutterpi_tool:

   ```bash
   cd src/frontend
   flutterpi_tool build --arch=arm64 --cpu=pi4 --output-dir build/frontend
   ```

3. **Transfer binaries to Raspberry Pi**:

   ```bash
   rsync -avz build/ pi@<pi-ip>:/opt/carnine/
   ```

4. **Run on Pi**:

   ```bash
   # SSH into Pi
   ssh pi@<pi-ip>
   /opt/carnine/carpc_frontend
   ```
