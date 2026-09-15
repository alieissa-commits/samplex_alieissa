#!/usr/bin/env python3
#
# Copyright (c) 2026 Eclipse ThreadX contributors
# SPDX-License-Identifier: MIT
#
"""
Automated Granular Diagnostic Script for NXP MIMXRT1064-EVK Renode CI.

Isolates each suspect delta between upstream working REPL and our REPL.
"""

import os
import queue
import shutil
import subprocess
import sys
import threading
import time


def find_renode():
    renode_bin = shutil.which("renode")
    if renode_bin:
        return renode_bin

    candidates = [
        r"C:\Program Files\Renode\renode.exe",
        os.path.expanduser(r"~\AppData\Local\Programs\Renode\renode.exe"),
        os.path.expanduser(r"~/renode/renode"),
        "/opt/renode/renode",
        "/usr/bin/renode",
    ]
    for path in candidates:
        if os.path.isfile(path):
            return path

    return "renode"


def run_renode_test(name, command_str, timeout_s=10.0):
    renode = find_renode()
    script_dir = os.path.dirname(os.path.abspath(__file__))
    board_dir = os.path.dirname(script_dir)

    print(f"\n---> [START TEST] {name}")
    cmd = [
        renode,
        "--plain",
        "--disable-gui",
        "--port", "-1",
        "-e", command_str,
    ]

    start = time.time()
    proc = subprocess.Popen(
        cmd,
        cwd=board_dir,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    try:
        stdout, _ = proc.communicate(timeout=timeout_s)
        elapsed = time.time() - start
        print(f"---> [PASS {elapsed:.2f}s] {name}")
        for line in stdout.strip().splitlines():
            if "[INFO]" in line or "[WARNING]" in line or "[ERROR]" in line or "===" in line:
                print(f"     {line}")
        return True
    except subprocess.TimeoutExpired:
        elapsed = time.time() - start
        print(f"\n---> [FAIL / HANG DETECTED after {elapsed:.2f}s] {name}!!!")
        try:
            # Sudo stack trace of hung process
            print(f"[DIAG] Thread stacks for hung PID {proc.pid}:")
            cmd_st = f"for s in /proc/{proc.pid}/task/*/stack; do echo \"--- Thread $s ---\"; cat $s; done"
            res = subprocess.run(["sudo", "bash", "-c", cmd_st], capture_output=True, text=True, timeout=5)
            print(res.stdout)
        except Exception as e:
            print(f"[DIAG] Stack dump error: {e}")

        try:
            proc.terminate()
            proc.wait(timeout=2)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass
        return False


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    board_dir = os.path.dirname(script_dir)
    renode_dir = os.path.join(board_dir, "renode")
    os.makedirs(renode_dir, exist_ok=True)

    # 1. Base upstream board REPL (Known passing)
    f_base = os.path.join(renode_dir, "diag_base.repl")
    with open(f_base, "w") as f:
        f.write('using "platforms/boards/mimxrt1064_evk.repl"\n')

    # 2. Test candidate: Missing flex_spi override (Does omitting flex_spi hang?)
    f_noflex = os.path.join(renode_dir, "diag_noflexspi.repl")
    with open(f_noflex, "w") as f:
        f.write(
            'using "platforms/cpus/imxrt1064.repl"\n'
            'sdram0: Memory.MappedMemory @ sysbus 0x80000000\n'
            '    size: 0x2000000\n'
            'flash_mem: Memory.MappedMemory @ sysbus 0x70000000\n'
            '    size: 0x400000\n'
            'user_button: Miscellaneous.Button @ gpio5\n'
            '    invert: true\n'
            '    -> gpio5@0\n'
            'green_led: Miscellaneous.LED @ gpio1 9\n'
            '    invert: true\n'
            'adc1:\n'
            '    referenceVoltage: 3.3\n'
            'adc2:\n'
            '    referenceVoltage: 3.3\n'
        )

    # 3. Test candidate: Custom user_led + gpio1 wiring
    f_gpio = os.path.join(renode_dir, "diag_gpio.repl")
    with open(f_gpio, "w") as f:
        f.write(
            'using "platforms/boards/mimxrt1064_evk.repl"\n'
            'gpio1:\n'
            '    9 -> user_led@0\n'
            'user_led: Miscellaneous.LED @ gpio1 9\n'
            '    invert: true\n'
        )

    # 4. Test candidate: Ethernet PHY on upstream board
    f_phy = os.path.join(renode_dir, "diag_phy.repl")
    with open(f_phy, "w") as f:
        f.write(
            'using "platforms/boards/mimxrt1064_evk.repl"\n'
            'phy: Network.EthernetPhysicalLayer @ enet 2\n'
            '    Id1: 0x0022\n'
            '    Id2: 0x1560\n'
            '    BasicControl: 0x3100\n'
            '    BasicStatus: 0x782D\n'
            '    AutoNegotiationAdvertisement: 0x01E1\n'
            '    AutoNegotiationLinkPartnerBasePageAbility: 0x01E1\n'
            '    VendorSpecific14: 0x0116\n'
            '    VendorSpecific15: 0x0080\n'
        )

    # 5. Test candidate: Upstream board + flex_spi + phy + user_led
    f_combined = os.path.join(renode_dir, "diag_combined.repl")
    with open(f_combined, "w") as f:
        f.write(
            'using "platforms/boards/mimxrt1064_evk.repl"\n'
            'user_led: Miscellaneous.LED @ gpio1 9\n'
            '    invert: true\n'
            'phy: Network.EthernetPhysicalLayer @ enet 2\n'
            '    Id1: 0x0022\n'
            '    Id2: 0x1560\n'
            '    BasicControl: 0x3100\n'
            '    BasicStatus: 0x782D\n'
            '    AutoNegotiationAdvertisement: 0x01E1\n'
            '    AutoNegotiationLinkPartnerBasePageAbility: 0x01E1\n'
            '    VendorSpecific14: 0x0116\n'
            '    VendorSpecific15: 0x0080\n'
        )

    tests = [
        ("1. Upstream Board (baseline)", 'mach create "m"; machine LoadPlatformDescription @renode/diag_base.repl; quit'),
        ("2. Omit flex_spi override (suspect A)", 'mach create "m"; machine LoadPlatformDescription @renode/diag_noflexspi.repl; quit'),
        ("3. GPIO double-wiring (suspect B)", 'mach create "m"; machine LoadPlatformDescription @renode/diag_gpio.repl; quit'),
        ("4. Ethernet PHY added to Upstream Board (suspect C)", 'mach create "m"; machine LoadPlatformDescription @renode/diag_phy.repl; quit'),
        ("5. Clean Combined (Upstream Board + flex_spi + PHY + user_led)", 'mach create "m"; machine LoadPlatformDescription @renode/diag_combined.repl; quit'),
        ("6. Original mimxrt1064-evk.repl", 'mach create "m"; machine LoadPlatformDescription @renode/mimxrt1064-evk.repl; quit'),
    ]

    results = {}
    for name, cmd_str in tests:
        ok = run_renode_test(name, cmd_str, timeout_s=10.0)
        results[name] = ok
        if not ok:
            print(f"\n>>> IDENTIFIED FAILING REPL CONFIGURATION: {name} <<<")
            # Don't abort immediately, let us see if combined works!

    print("\n==================================================")
    print("DIAGNOSTIC TEST MATRIX SUMMARY:")
    for name, ok in results.items():
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}")
    print("==================================================")

    # Return 0 so CI displays the full matrix
    sys.exit(0)


if __name__ == "__main__":
    main()
