#!/usr/bin/env python3
"""
demo.py  –  Demonstrate the Python gen_server implementation.

This script exercises the full gen_server architecture:

  ① start_link(CounterServer, Args)  — bind callback module
  ② Function registration            — CounterServer → fun Mod:F/A
  ③ call / cast                       — client → server
  ④ callback invocation               — server → bound callbacks
  ⑤ return value                      — callbacks → server
  ⑥ Reply                             — server → client

Run:
    cd gen_server_by_py/
    python demo.py
"""

import sys
import os
import time

# Ensure the package directory is on the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gen_server
import counter_server


def separator(title: str):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}\n")


def main():
    # ============================================================
    # 1. Start the server
    #    Arrow ①: start_link(CounterServer, 0)
    #    Arrow ②: Function registration (CounterServer → callbacks)
    # ============================================================
    separator("① ② Start Server (start_link)")

    pid = counter_server.start_link(init_count=0)
    print(f"Server started: {pid}")
    print(f"Server alive: {pid.is_alive}")

    # ============================================================
    # 2. Synchronous calls (call)
    #    Arrow ③: call → server
    #    Arrow ④: server → handle_call
    #    Arrow ⑤: handle_call returns
    #    Arrow ⑥: reply → client
    # ============================================================
    separator("③④⑤⑥ Synchronous Calls (gen_server:call)")

    print(f"get_count  = {counter_server.get_count(pid)}")
    print(f"increment  = {counter_server.increment(pid)}")
    print(f"increment  = {counter_server.increment(pid)}")
    print(f"increment  = {counter_server.increment(pid)}")
    print(f"get_count  = {counter_server.get_count(pid)}")
    print(f"decrement  = {counter_server.decrement(pid)}")
    print(f"get_count  = {counter_server.get_count(pid)}")

    # ============================================================
    # 3. Asynchronous cast
    #    Arrow ③: cast → server (fire-and-forget)
    # ============================================================
    separator("③ Asynchronous Cast (gen_server:cast)")

    counter_server.reset(pid)
    time.sleep(0.1)  # give the cast time to process
    print(f"get_count after reset = {counter_server.get_count(pid)}")

    # ============================================================
    # 4. Send info message (like Erlang's ! operator)
    # ============================================================
    separator("Info Message (Server ! Msg)")

    gen_server.send_info(pid, ('custom_msg', 'hello from Python'))
    time.sleep(0.1)

    gen_server.send_info(pid, 'some_unexpected_message')
    time.sleep(0.1)

    # ============================================================
    # 5. Demonstrate call timeout
    # ============================================================
    separator("Call Timeout Demo")

    print("Calling slow_operation(0.5s) with default timeout...")
    result = counter_server.slow_operation(pid, 0.5)
    print(f"slow_operation result: {result}")

    print("\nCalling slow_operation(3s) with 1s timeout (will timeout)...")
    try:
        gen_server.call(pid, ('slow_op', 3), timeout=1.0)
    except RuntimeError as e:
        print(f"Caught expected timeout: {e}")

    # Wait for the slow op to finish in the server
    time.sleep(2.5)

    # ============================================================
    # 6. Demonstrate crash recovery (server dies)
    # ============================================================
    separator("Crash Demo (gen_server:cast crash)")

    print(f"Server alive before crash: {pid.is_alive}")
    counter_server.crash(pid)
    time.sleep(0.2)
    print(f"Server alive after crash:  {pid.is_alive}")

    # ============================================================
    # 7. Restart and graceful stop
    # ============================================================
    separator("Restart & Graceful Stop (gen_server:stop)")

    pid2 = counter_server.start_link(init_count=42)
    print(f"New server started: {pid2}")
    print(f"get_count = {counter_server.get_count(pid2)}")

    gen_server.stop(pid2, reason='normal')
    print(f"Server alive after stop: {pid2.is_alive}")

    # ============================================================
    # 8. Multiple servers (independent processes)
    # ============================================================
    separator("Multiple Independent Servers")

    s1 = counter_server.start_link(init_count=0)
    s2 = counter_server.start_link(init_count=100)

    counter_server.increment(s1)
    counter_server.increment(s1)
    counter_server.decrement(s2)

    print(f"Server 1 count: {counter_server.get_count(s1)}")
    print(f"Server 2 count: {counter_server.get_count(s2)}")

    gen_server.stop(s1)
    gen_server.stop(s2)

    separator("Demo Complete")
    print("All gen_server architecture arrows demonstrated successfully!")
    print("""
Architecture Recap:
  ① start_link(Module, Args)  — bind callback module (?MODULE)
  ② Function registration     — Module → fun Mod:F/A
  ③ call / cast               — client → server
  ④ callback invocation       — server → bound callbacks
  ⑤ return value              — callbacks → server
  ⑥ Reply                     — server → client
""")


if __name__ == '__main__':
    main()
