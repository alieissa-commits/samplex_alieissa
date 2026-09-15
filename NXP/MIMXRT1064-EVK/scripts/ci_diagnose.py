#!/usr/bin/env python3
#
# Copyright (c) 2026 Eclipse ThreadX contributors
# SPDX-License-Identifier: MIT
#
"""
Automated Granular Diagnostic Script for NXP MIMXRT1064-EVK Renode CI.

Executes Renode monitor commands one-by-one with explicit logging checkpoints.
If a command freezes or fails, captures kernel stack traces and strace before exiting.
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


def reader_thread(pipe, q):
    try:
        for line in iter(pipe.readline, ""):
            q.put(line)
    except Exception:
        pass
    finally:
        pipe.close()


def dump_linux_diagnostics(pid):
    print(f"\n[DIAG] === Linux Process Inspection for PID {pid} ===")
    try:
        ps_out = subprocess.run(["ps", "-fp", str(pid)], capture_output=True, text=True, timeout=5)
        print(ps_out.stdout)
    except Exception as e:
        print(f"[DIAG] ps failed: {e}")

    try:
        stack_path = f"/proc/{pid}/stack"
        if os.path.isfile(stack_path):
            with open(stack_path, "r") as f:
                print(f"[DIAG] /proc/{pid}/stack:\n{f.read()}")
    except Exception as e:
        print(f"[DIAG] /proc/stack read failed: {e}")

    try:
        task_dir = f"/proc/{pid}/task"
        if os.path.isdir(task_dir):
            threads = os.listdir(task_dir)
            print(f"[DIAG] Threads found ({len(threads)}): {threads}")
            for tid in threads[:5]:
                t_stack = f"/proc/{pid}/task/{tid}/stack"
                if os.path.isfile(t_stack):
                    with open(t_stack, "r") as f:
                        content = f.read().strip()
                        if content:
                            print(f"[DIAG] Thread {tid} stack:\n{content}")
    except Exception as e:
        print(f"[DIAG] thread stacks failed: {e}")

    try:
        fd_out = subprocess.run(["ls", "-l", f"/proc/{pid}/fd"], capture_output=True, text=True, timeout=5)
        print(f"[DIAG] Open file descriptors:\n{fd_out.stdout}")
    except Exception as e:
        print(f"[DIAG] ls fd failed: {e}")

    try:
        print(f"[DIAG] Running 1s strace sample on PID {pid}...")
        strace_cmd = ["strace", "-p", str(pid), "-s", "256"]
        s_proc = subprocess.Popen(strace_cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        time.sleep(1.5)
        s_proc.terminate()
        try:
            out, _ = s_proc.communicate(timeout=2)
            print(f"[DIAG] strace sample:\n{out[:2000]}")
        except Exception:
            s_proc.kill()
    except Exception as e:
        print(f"[DIAG] strace failed: {e}")


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    board_dir = os.path.dirname(script_dir)
    renode = find_renode()

    elf_path = os.path.join(board_dir, "build", "app", "demos", "threadx_basic", "mimxrt1064_threadx.elf")
    if not os.path.isfile(elf_path):
        elf_path = os.path.join(board_dir, "build", "mimxrt1064_threadx.elf")

    elf_rel = os.path.relpath(elf_path, board_dir).replace("\\", "/")

    script_commands = [
        "log '=== DIAG STEP 1: CREATING MACHINE ==='",
        "mach create 'mimxrt1064-evk'",
        "log '=== DIAG STEP 2: MACHINE CREATED OK ==='",
        "log '=== DIAG STEP 3: LOADING PLATFORM DESCRIPTION ==='",
        "machine LoadPlatformDescription @renode/mimxrt1064-evk.repl",
        "log '=== DIAG STEP 4: PLATFORM LOADED OK ==='",
        "log '=== DIAG STEP 5: CONFIGURING SHOWANALYZER ==='",
        "showAnalyzer sysbus.lpuart1",
        "log '=== DIAG STEP 6: SHOWANALYZER CONFIGURED OK ==='",
        f"log '=== DIAG STEP 7: LOADING ELF ({elf_rel}) ==='",
        f"sysbus LoadELF @{elf_rel}",
        "log '=== DIAG STEP 8: ELF LOADED OK ==='",
        "log '=== DIAG STEP 9: SETTING VTOR AND REGISTERS ==='",
        "cpu VectorTableOffset 0x70002000",
        "cpu PC `sysbus ReadDoubleWord 0x70002004`",
        "cpu SP `sysbus ReadDoubleWord 0x70002000`",
        "log '=== DIAG STEP 10: STARTING EMULATION FOR 2 SECONDS ==='",
        "emulation RunFor '2'",
        "log '=== DIAG STEP 11: EMULATION FINISHED OK ==='",
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
    overall_timeout = 60.0

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
