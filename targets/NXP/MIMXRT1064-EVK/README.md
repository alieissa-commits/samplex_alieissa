# NXP i.MX RT1064-EVK Board Enablement Demos

This directory contains the Board Support Package (BSP) and build configurations for running the **Eclipse ThreadX RTOS** and **NetX Duo TCP/IP stack** on the **NXP i.MX RT1064-EVK** evaluation board (ARM Cortex-M7 @ 600 MHz).

The project features a decoupled Board Support Package (`board_bsp`) that hides all low-level hardware initializations (clocks, power, caches, MPU regions, pin muxing, Ethernet MAC/PHY descriptors, and on-chip cryptographic peripherals) from the high-level application code.

> [!NOTE]
> **Hardware Verification Status**: *Simulated in Renode, Pending Physical Hardware Verification*
>
> All peripheral drivers, hardware cryptographic subsystems, and network stacks documented in this repository have been fully verified under multi-node system emulation in Antmicro Renode. Flashing instructions for physical silicon follow standard NXP OpenSDA, Segger J-Link, pyOCD, and MCUXpresso workflows as detailed in the [Physical Board Deployment & Flashing](#physical-board-deployment--flashing) section below.

---

## Supported Demos

Each demo outputs into its own isolated directory in `build/app/demos/<demo_name>/`:

| Demo Name | Description | Output Directory |
| :--- | :--- | :--- |
| **`threadx_basic`** | Core ThreadX RTOS demo: preemptive thread scheduling, timer callbacks, and User LED D18 heartbeat blinking. | `build/app/demos/threadx_basic/` |
| **`netx_echo`** | NetX Duo networking demo: KSZ8081 Ethernet PHY, ARP, ICMP Ping responder, UDP echo (port 7), and TCP echo server (port 7). | `build/app/demos/netx_echo/` |
| **`netx_trng_console`** *(Default)* | Hardware cryptographic True Random Number Generator (TRNG @ `0x400CC000`) with an interactive TCP diagnostic management shell on port 23. | `build/app/demos/netx_trng_console/` |

---

## Hardware Overview

* **Evaluation Board**: NXP MIMXRT1064-EVK (ARM Cortex-M7 @ 600 MHz)
* **Memory**: 4 MB on-chip FlexSPI NOR Flash (`0x70000000`), 1 MB on-chip SRAM (ITCM, DTCM, NonCacheable OCRAM)
* **Serial Console**: LPUART1 via OpenSDA micro-USB (`J41`), 115,200 baud, 8N1
* **User LED & Button**: Green LED `D18` (`GPIO1_IO09`), SW8 WAKEUP button (`GPIO5_IO00`)
* **Ethernet**: ENET MAC + Microchip KSZ8081RNA PHY via RMII
* **TRNG Hardware**: On-chip True Random Number Generator (`0x400CC000`)

---

## Prerequisites

* **ARM GNU Toolchain** (`arm-none-eabi-gcc` 10.3+)
* **CMake** (3.20+) and **Ninja** (recommended) or Make
* **Git** (for downloading SDK dependencies)
* **Antmicro Renode** (1.15.3+, for simulation)

---

## Quick Start Guide

### 1. Download SDK Dependencies
Download the stock NXP MCUXpresso SDK drivers, CMSIS headers, and board files:

* **Windows**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\fetch_sdk.ps1
  ```
* **Linux / macOS**:
  ```bash
  chmod +x ./scripts/fetch_sdk.sh && ./scripts/fetch_sdk.sh
  ```

### 2. Build the Demos

#### Option A: Build All Demos (Default & Recommended)
Build all three demos at once. Once built, you can switch between simulations instantly without rebuilding!

* **Windows**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\build.ps1
  ```
* **Linux / macOS**:
  ```bash
  chmod +x ./scripts/build.sh && ./scripts/build.sh
  ```
* **Direct CMake**:
  ```bash
  cmake -B build -G Ninja -DACTIVE_DEMO=all
  cmake --build build
  ```

#### Option B: Build a Specific Demo
To build only one specific demo:

```powershell
# Windows PowerShell
.\scripts\build.ps1 -Demo threadx_basic
.\scripts\build.ps1 -Demo netx_echo
.\scripts\build.ps1 -Demo netx_trng_console
```

```bash
# Linux / macOS Bash
./scripts/build.sh -d threadx_basic
./scripts/build.sh -d netx_echo
./scripts/build.sh -d netx_trng_console
```

Each demo's artifacts (`.elf`, `.bin`, `.hex`, `.map`) are placed in `build/app/demos/<demo_name>/`.

---

## Renode Simulation

The project includes preconfigured Renode emulation environments for both single-node and multi-node scenarios.

### 1. Interactive Simulation
Simulate any demo simply by passing the `-Demo` configuration variable:

* **Windows (PowerShell)**:
  ```powershell
  # ThreadX Core Basic (single node)
  powershell -ExecutionPolicy Bypass -File .\scripts\simulate.ps1 -Demo threadx_basic

  # NetX Duo Network Echo (multi-node server + client)
  powershell -ExecutionPolicy Bypass -File .\scripts\simulate.ps1 -Demo netx_echo

  # Hardware TRNG Diagnostic Console (multi-node server + client)
  powershell -ExecutionPolicy Bypass -File .\scripts\simulate.ps1 -Demo netx_trng_console
  ```

* **Linux / macOS (Bash)**:
  ```bash
  ./scripts/simulate.sh -d threadx_basic
  ./scripts/simulate.sh -d netx_echo
  ./scripts/simulate.sh -d netx_trng_console
  ```

#### Deterministic Seeding Option:
For deterministic execution and repeatable TRNG random sequences in simulation, pass `-Seed <number>`:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\simulate.ps1 -Demo netx_trng_console -Seed 12345
```
```bash
./scripts/simulate.sh -d netx_trng_console -s 12345
```

### 2. Headless Automated Regression Testing (CI/CD)
The project provides headless test runners (`test_headless.ps1` and `test_headless.sh`) designed for continuous integration pipelines without a graphical display. The runner boots the simulation, monitors the virtual UART logs, and exits with code `0` on success or code `1` on timeout/failure.

* **Windows (PowerShell)**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\test_headless.ps1
  ```
* **Linux / macOS (Bash)**:
  ```bash
  chmod +x ./scripts/test_headless.sh
  ./scripts/test_headless.sh
  ```

Test any specific demo headlessly:
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test_headless.ps1 -Demo threadx_basic -TimeoutSeconds 8
```

---

## Physical Board Deployment & Flashing

> [!NOTE]
> *Simulated in Renode, Pending Physical Hardware Verification*

When flashing to physical hardware, ensure the EVK board boot mode switches (`SW7`: `1-OFF, 2-ON, 3-OFF, 4-ON`) are configured for **Internal Boot (FlexSPI NOR Flash)**. Connect your PC to the OpenSDA USB port (`J41`).

### Flashing Method 1: OpenSDA Drag-and-Drop (DAP-Link)
1. Connect the EVK board to your PC via micro-USB connector `J41`.
2. The onboard OpenSDA circuit mounts as a USB mass storage drive (e.g., `RT1064-EVK`).
3. Copy `build/app/demos/<demo_name>/mimxrt1064_threadx.bin` and paste it directly into the `RT1064-EVK` drive.
4. The OpenSDA LED blinks rapidly during programming. Once complete, press the `SW3` (RESET) button to boot.

### Flashing Method 2: SEGGER J-Link
If using a SEGGER J-Link probe (or OpenSDA programmed with J-Link firmware):
1. Connect via J-Link Commander:
   ```text
   JLink.exe -device MIMXRT1064xxx6A -if SWD -speed 4000 -autoconnect 1
   ```
2. Flash the raw binary or hex file:
   ```text
   loadfile build/app/demos/<demo_name>/mimxrt1064_threadx.hex
   r
   g
   ```

### Flashing Method 3: pyOCD Command Line
Using the open-source pyOCD programmer:
1. Install pyOCD and the NXP device pack:
   ```bash
   pip install pyocd && pyocd pack install MIMXRT1064
   ```
2. Program the target:
   ```bash
   pyocd flash -t mimxrt1064 build/app/demos/<demo_name>/mimxrt1064_threadx.hex
   ```

### Flashing Method 4: NXP MCUXpresso IDE / GUI Flash Tool
1. Open MCUXpresso IDE and select **GUI Flash Tool** from the toolbar.
2. Select target device `MIMXRT1064xxxxA` and target memory `PROGRAM_FLASH` (`0x70000000`).
3. Select `build/app/demos/<demo_name>/mimxrt1064_threadx.elf` (or `.bin`) and click **Program**.

---

## Developer Guide: How to Add a New Demo

The decoupled architecture of `board_bsp` makes adding custom applications straightforward:

### Step 1: Create the Demo Directory
Create a folder under `app/demos/` (e.g., `app/demos/my_new_demo/`).

### Step 2: Write Application Code
Create `main.c` utilizing the standard BSP API:
```c
#include <bsp/board.h>
#include <bsp/led.h>
#include <bsp/console.h>
#include "tx_api.h"

int main(void)
{
    /* Initialize MPU, 600 MHz system clocks, pins, LED, and console */
    bsp_board_init();

    /* Enter ThreadX RTOS Kernel */
    tx_kernel_enter();
    return 0;
}
```

### Step 3: Create `CMakeLists.txt`
In your demo directory:
```cmake
set(DEMO_TARGET "demo_my_new_demo")
add_executable(${DEMO_TARGET}
    main.c
)
set_target_properties(${DEMO_TARGET} PROPERTIES OUTPUT_NAME "mimxrt1064_threadx")

target_include_directories(${DEMO_TARGET} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/../..
)

target_link_libraries(${DEMO_TARGET} PRIVATE
    board_bsp
    threadx
    # netxduo             # Uncomment if using network
    # netx_imxrt_driver   # Uncomment if using network
)

set_target_linker(${DEMO_TARGET} "${CMAKE_CURRENT_SOURCE_DIR}/../../startup/MIMXRT1064xxxxx_flexspi_nor.ld")
post_build(${DEMO_TARGET})
```

### Step 4: Build and Simulate
```bash
cmake -DACTIVE_DEMO=my_new_demo -B build -G Ninja
cmake --build build
```
