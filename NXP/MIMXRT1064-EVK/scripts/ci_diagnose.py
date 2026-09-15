#!/usr/bin/env python3
#
# Copyright (c) 2026 Eclipse ThreadX contributors
# SPDX-License-Identifier: MIT
#
"""
Automated Granular Diagnostic Script for NXP MIMXRT1064-EVK Renode CI.

Executes isolated platform load tests and inspects kernel thread stacks with sudo if stalled.
"""

import glob
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


def reader_thread(pipe, q):
    try:
        for line in iter(pipe.readline, ""):
            q.put(line)
    except Exception:
        pass
    finally:
        pipe.close()


def print_environment_layout():
    print("\n=== Inspecting Renode Installation Filesystem ===")
    renode_dir = os.path.expanduser("~/renode")
    if os.path.isdir(renode_dir):
        print(f"[FS] Contents of {renode_dir}: {os.listdir(renode_dir)}")
        for sub in ["scripts", "platforms", "platforms/cpus", "platforms/boards"]:
            p = os.path.join(renode_dir, sub)
            if os.path.exists(p):
                print(f"[FS] Found {p}")
            else:
                print(f"[FS] MISSING {p}")

        # Search for imxrt1064 and pydev
        try:
            res = subprocess.run(["find", renode_dir, "-name", "*imxrt1064*"], capture_output=True, text=True, timeout=5)
            print(f"[FS] imxrt1064 files in renode:\n{res.stdout.strip()}")
            res2 = subprocess.run(["find", renode_dir, "-name", "*ticker*"], capture_output=True, text=True, timeout=5)
            print(f"[FS] ticker files in renode:\n{res2.stdout.strip()}")
        except Exception as e:
            print(f"[FS] find failed: {e}")
    else:
        print(f"[FS] {renode_dir} is not a directory.")
    print("=================================================\n")


def dump_linux_diagnostics(pid):
    print(f"\n[DIAG] === Sudo Linux Process Inspection for PID {pid} ===")
    try:
        ps_out = subprocess.run(["ps", "-fp", str(pid)], capture_output=True, text=True, timeout=5)
        print(ps_out.stdout)
    except Exception as e:
        print(f"[DIAG] ps failed: {e}")

    try:
        # Check task thread stacks with sudo
        cmd = f"for s in /proc/{pid}/task/*/stack; do echo \"--- Thread $s ---\"; cat $s; done"
        stacks = subprocess.run(["sudo", "bash", "-c", cmd], capture_output=True, text=True, timeout=5)
        print(f"[DIAG] All thread kernel stacks:\n{stacks.stdout}")
    except Exception as e:
        print(f"[DIAG] sudo thread stacks failed: {e}")

    try:
        # Check open file descriptors
        fd_out = subprocess.run(["sudo", "ls", "-l", f"/proc/{pid}/fd"], capture_output=True, text=True, timeout=5)
        print(f"[DIAG] Open file descriptors:\n{fd_out.stdout}")
    except Exception as e:
        print(f"[DIAG] ls fd failed: {e}")

    try:
        print(f"[DIAG] Running 2s sudo strace sample on PID {pid}...")
        strace_cmd = ["sudo", "strace", "-p", str(pid), "-s", "256"]
        s_proc = subprocess.Popen(strace_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        time.sleep(2.0)
        s_proc.terminate()
        try:
            out, _ = s_proc.communicate(timeout=2)
            print(f"[DIAG] strace sample:\n{out[:3000]}")
        except Exception:
            s_proc.kill()
    except Exception as e:
        print(f"[DIAG] sudo strace failed: {e}")


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    board_dir = os.path.dirname(script_dir)
    renode = find_renode()

    if sys.platform.startswith("linux"):
        print_environment_layout()

    elf_path = os.path.join(board_dir, "build", "app", "demos", "threadx_basic", "mimxrt1064_threadx.elf")
    if not os.path.isfile(elf_path):
        elf_path = os.path.join(board_dir, "build", "mimxrt1064_threadx.elf")

    elf_rel = os.path.relpath(elf_path, board_dir).replace("\\", "/")

    # Isolated test suite
    script_commands = [
        # TEST A: Built-in CPU description
        "log '=== [TEST A] CREATING TEST MACHINE FOR CPU REPL ==='",
        "mach create 'test-cpu'",
        "log '=== [TEST A] LOADING @platforms/cpus/imxrt1064.repl ==='",
        "machine LoadPlatformDescription @platforms/cpus/imxrt1064.repl",
        "log '=== [TEST A SUCCESS] CPU REPL LOADED OK ==='",
        "mach clear",

        # TEST B: Built-in Board description
        "log '=== [TEST B] CREATING TEST MACHINE FOR BOARD REPL ==='",
        "mach create 'test-board'",
        "log '=== [TEST B] LOADING @platforms/boards/mimxrt1064_evk.repl ==='",
        "machine LoadPlatformDescription @platforms/boards/mimxrt1064_evk.repl",
        "log '=== [TEST B SUCCESS] BOARD REPL LOADED OK ==='",
        "mach clear",

        # TEST C: Custom Platform description
        "log '=== [TEST C] CREATING PRODUCTION MACHINE ==='",
        "mach create 'mimxrt1064-evk'",
        "log '=== [TEST C] LOADING @renode/mimxrt1064-evk.repl ==='",
        "machine LoadPlatformDescription @renode/mimxrt1064-evk.repl",
        "log '=== [TEST C SUCCESS] CUSTOM REPL LOADED OK ==='",

        # Verification run
        "log '=== [TEST D] CONFIGURING SHOWANALYZER ==='",
        "showAnalyzer sysbus.lpuart1",
        f"log '=== [TEST D] LOADING ELF ({elf_rel}) ==='",
        f"sysbus LoadELF @{elf_rel}",
        "cpu VectorTableOffset 0x70002000",
        "cpu PC `sysbus ReadDoubleWord 0x70002004`",
        "cpu SP `sysbus ReadDoubleWord 0x70002000`",
        "log '=== [TEST D] RUNNING EMULATION FOR 2s ==='",
        "emulation RunFor '2'",
        "log '=== [TEST D SUCCESS] ALL TESTS PASSED! ==='",
        "quit",
    ]

    cmd_str = "; ".join(script_commands)

    cmd = [
        renode,
        "--plain",
        "--disable-gui",
        "--port", "-1",
        "-e", cmd_str,
    ]

    print("==================================================")
    print("Renode Step-by-Step Granular Diagnostic Runner")
    print("==================================================")
    print(f"Renode binary: {renode}")
    print(f"Working directory: {board_dir}")
    print(f"Target ELF: {elf_rel} (exists: {os.path.isfile(elf_path)})")
    print("")
    print("Executing granular checkpoint command sequence...")
    print("==================================================")

    proc = subprocess.Popen(
        cmd,
        cwd=board_dir,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    out_q = queue.Queue()
    t = threading.Thread(target=reader_thread, args=(proc.stdout, out_q), daemon=True)
    t.start()

    last_output_time = time.time()
    start_time = time.time()
    hang_detected = False
    inactivity_timeout = 15.0
    overall_timeout = 90.0

    while True:
        try:
            line = out_q.get(timeout=0.2)
            sys.stdout.write(line)
            sys.stdout.flush()
            last_output_time = time.time()
        except queue.Empty:
            pass

        now = time.time()
        if now - last_output_time > inactivity_timeout:
            print(f"\n[CRITICAL DIAGNOSTIC] Renode has been silent for {inactivity_timeout}s! HANG DETECTED.")
            hang_detected = True
            break

        if now - start_time > overall_timeout:
            print(f"\n[CRITICAL DIAGNOSTIC] Overall test timeout ({overall_timeout}s) exceeded!")
            hang_detected = True
            break

        if proc.poll() is not None:
            while not out_q.empty():
                line = out_q.get_nowait()
                sys.stdout.write(line)
                sys.stdout.flush()
            break

    if hang_detected:
        if sys.platform.startswith("linux"):
            dump_linux_diagnostics(proc.pid)

        print("\n[DIAG] Terminating stalled Renode process...")
        try:
            proc.terminate()
            proc.wait(timeout=3)
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass
        sys.exit(1)

    exit_code = proc.returncode
    print(f"\n==================================================")
    print(f"Diagnostic run finished with exit code: {exit_code}")
    print(f"==================================================")
    sys.exit(exit_code if exit_code is not None else 0)


if __name__ == "__main__":
    main()
