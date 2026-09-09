# NXP i.MX RT1064-EVK Board Support Package & Demos

This directory contains the Board Support Package (BSP) and build environment for running the **Eclipse ThreadX RTOS** and **NetX Duo** on the **NXP i.MX RT1064-EVK** evaluation board (ARM Cortex-M7 @ 600 MHz).

The project is designed to run seamlessly both in the **Antmicro Renode** simulation framework and on physical silicon.

---

## Hardware Configuration

* **Development Board**: MIMXRT1064-EVK
* **Microcontroller**: NXP i.MX RT1064 (MIMXRT1064DVL6A, ARM Cortex-M7 @ 600 MHz)
* **Flash Memory**: 4 MB internal FlexSPI NOR Flash (XIP)
* **Internal SRAM**: 1 MB on-chip RAM (Configurable as ITCM, DTCM, and OCRAM)
* **Debug Serial Console**: LPUART1 (115,200 baud, 8N1)
* **User LED**: GPIO9 Pin 3 (`GPIO_AD_B0_09`) / User LED (Green)
* **Virtual Networking**: ENET1 (10/100M Fast Ethernet MAC via KSZ8081 PHY)

---

## Project Structure

```text
NXP/MIMXRT1064-EVK/
├── CMakeLists.txt              # Top-level CMake build configuration
├── NOTICE.md                   # Third-party licensing notices (NXP BSD-3 & CMSIS)
├── README.md                   # This documentation file
├── cmake/
│   ├── arm-gcc-cortex-m7.cmake         # CPU architecture and FPU definitions
│   ├── arm-gcc-cortex-toolchain.cmake  # GNU toolchain discovery and compiler flags
│   └── utilities.cmake                 # Elf-to-bin/hex conversion and linker macros
├── lib/
│   ├── threadx/
│   │   └── tx_user.h           # ThreadX configuration (hardware FPU enabled)
│   └── mcux-sdk/               # Official NXP SDK drivers (fetched via script)
└── scripts/
    ├── fetch_sdk.ps1 / .sh     # Download official NXP drivers, device headers & CMSIS
    └── build.ps1 / .sh         # One-command build script with Ninja/CMake
```

---

## Prerequisites

Before building, ensure the following cross-compilation tools are installed and present on your `PATH`:

* **ARM GNU Toolchain** (`arm-none-eabi-gcc` 10.3 or newer)
* **CMake** (version 3.5 or newer)
* **Ninja** (or **Make**)
* **Git** (for downloading SDK dependencies)
* **Antmicro Renode** (v1.15 or newer, for simulation)

---

## Quick Start Guide

### 1. Download SDK Dependencies
Run the driver fetcher script to retrieve official NXP MCUXpresso SDK drivers, CMSIS device headers, and board files:

* **On Windows (PowerShell)**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\fetch_sdk.ps1
  ```
* **On Linux / macOS (Bash)**:
  ```bash
  chmod +x ./scripts/fetch_sdk.sh
  ./scripts/fetch_sdk.sh
  ```

### 2. Build the Project
Compile the application, vendor drivers, and Eclipse ThreadX kernel:

* **On Windows (PowerShell)**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1 -Rebuild
  ```
* **On Linux / macOS (Bash)**:
  ```bash
  chmod +x ./scripts/build.sh
  ./scripts/build.sh --rebuild
  ```

---

## Hardware Verification Status

> [!NOTE]
> This Board Support Package is developed and validated using **Antmicro Renode simulation**. Physical hardware verification on the EVK-MIMXRT1064 evaluation board is welcome and encouraged!
