"""
gen_server.py  –  A Python implementation of the Erlang/OTP gen_server behaviour.

Architecture Mapping (from gen_server_architecture.tex):

  +---------------------+-----------------------------+
  | Client API          | Generic Server              |
  | (call, cast, stop)  | (gen_server.py)             |
  |                     | message loop, routing, ...  |
  +---------------------+-----------------------------+
  | User / Developer    | Callback Module  (Your Code)|
  | writes this module  | init, handle_call, ...      |
  +---------------------+-----------------------------+

This file implements the **right column** – the Generic Server that:
  ① Stores the callback module reference (equivalent to ?MODULE)
  ② Caches function references (bound callbacks)
  ③ Runs the receive loop dispatching to Mod.handle_call/handle_cast/handle_info
  ④ Returns replies to callers

Usage:
    pid = gen_server.start_link(CounterServer, init_args)
    result = gen_server.call(pid, request)
    gen_server.cast(pid, message)
    gen_server.stop(pid)
"""

from __future__ import annotations

import threading
import queue
import traceback
import time
from dataclasses import dataclass, field
from typing import Any, Optional, Tuple, Type
from abc import ABC, abstractmethod


# ============================================================
# Callback Behaviour (abstract base class)
# Equivalent to: -behaviour(gen_server).
# ============================================================

class GenServerBehaviour(ABC):
    """
    Abstract base class defining the gen_server callback interface.

    Users must subclass this and implement the callback methods,
    just like implementing -behaviour(gen_server) in Erlang.

    Callback Module (bottom-left quadrant in the architecture diagram):
        -module(counter_server).
        -behaviour(gen_server).
        init/1, handle_call/3, handle_cast/2, handle_info/2,
        handle_continue/2, terminate/2
    """

    @abstractmethod
    def init(self, args: Any) -> Tuple[str, Any]:
        """
        Initialize server state.

        Returns:
            ('ok', initial_state)
            ('ok', initial_state, {'continue', term})
            ('stop', reason)
        """
        ...

    @abstractmethod
    def handle_call(self, request: Any, from_ref: Any, state: Any) -> Tuple:
        """
        Handle synchronous call.

        Returns:
            ('reply', reply, new_state)
            ('noreply', new_state)   — caller blocks until a manual reply
            ('stop', reason, reply, new_state)
        """
        ...

    @abstractmethod
    def handle_cast(self, msg: Any, state: Any) -> Tuple:
        """
        Handle asynchronous cast.

        Returns:
            ('noreply', new_state)
            ('stop', reason, new_state)
        """
        ...

    def handle_info(self, info: Any, state: Any) -> Tuple:
        """
        Handle other messages (default: ignore).

        Returns:
            ('noreply', new_state)
            ('stop', reason, new_state)
        """
        print(f"[gen_server] unexpected info: {info!r}")
        return ('noreply', state)

    def handle_continue(self, continue_arg: Any, state: Any) -> Tuple:
        """
        Handle continue after init or other callbacks.

        Returns:
            ('noreply', new_state)
            ('stop', reason, new_state)
        """
        return ('noreply', state)

    def terminate(self, reason: Any, state: Any) -> None:
        """Called when the server is about to terminate."""
        pass

    def code_change(self, old_vsn: Any, state: Any, extra: Any) -> Tuple[str, Any]:
        """Hot code upgrade (placeholder)."""
        return ('ok', state)


# ============================================================
# Internal message types (the "mailbox" protocol)
# ============================================================

@dataclass
class _CallMsg:
    """Synchronous call message: client blocks for reply."""
    request: Any
    reply_queue: queue.Queue  # one-shot queue for the reply


@dataclass
class _CastMsg:
    """Asynchronous cast message: fire-and-forget."""
    msg: Any


@dataclass
class _InfoMsg:
    """Generic info message (like Erlang ! operator)."""
    info: Any


@dataclass
class _StopMsg:
    """Request to stop the server."""
    reason: Any
    reply_queue: Optional[queue.Queue] = None


# ============================================================
# ServerData — equivalent to Erlang's #server_data{}
# Stores ?MODULE info and cached function references
# ============================================================

@dataclass
class _ServerData:
    """
    Internal server state container.

    Equivalent to the #server_data{} record in gen_server.erl:
      - mod: the callback module (?MODULE)
      - state: the user-defined state managed by the callback module
      - callbacks: cached function references (fun Mod:F/A)
    """
    mod: GenServerBehaviour          # ?MODULE — the callback module instance
    mod_class: Type                  # the class itself (for display)
    state: Any = None                # user state from init/1
    callbacks: dict = field(default_factory=dict)  # cached fun references


# ============================================================
# GenServer Process — the "receive" loop running in a thread
# ============================================================

class GenServerProcess:
    """
    Represents a running gen_server process (like an Erlang pid).

    This is the **Generic Server** (right-top quadrant):
      - Startup: start_link → spawn thread → init_it → Mod.init()
      - Runtime: receive → Mod.handle_call/3 …
      - Stores ?MODULE info → caches function references

    The 6 arrows in the architecture diagram:
      ① start_link(Module, Args) — binds callback module
      ② Function registration — Module → fun Mod:F/A
      ③ call / cast / send_request — client → server
      ④ callback invocation — server → bound callbacks
      ⑤ return value — callbacks → server
      ⑥ Reply — server → client
    """

    def __init__(self):
        self._mailbox: queue.Queue = queue.Queue()
        self._thread: Optional[threading.Thread] = None
        self._server_data: Optional[_ServerData] = None
        self._alive = threading.Event()
        self._started = threading.Event()
        self._start_error: Optional[Any] = None
        self._name: Optional[str] = None

    @property
    def is_alive(self) -> bool:
        return self._alive.is_set()

    def __repr__(self):
        cls_name = self._server_data.mod_class.__name__ if self._server_data else "?"
        tid = self._thread.ident if self._thread else "?"
        return f"<GenServerProcess {cls_name} tid={tid} alive={self.is_alive}>"

    # ---- Internal: the main loop (equivalent to gen_server loop/receive) ----

    def _init_it(self, mod_class: Type[GenServerBehaviour], args: Any):
        """
        Startup sequence (Arrow ①②):
          start_link → proc_lib:start_link → init_it → Mod:init/1

        Steps:
          1. Instantiate the callback module (equivalent to ?MODULE binding)
          2. Cache function references (fun Mod:init/1, fun Mod:handle_call/3, …)
          3. Call Mod.init(args)
          4. Enter the receive loop
        """
        # Step 1: Instantiate callback module — equivalent to ?MODULE
        mod_instance = mod_class()

        # Step 2: Cache function references — Arrow ②: function registration
        #   fun counter_server:init/1
        #   fun counter_server:handle_call/3
        #   fun counter_server:handle_cast/2
        #   fun counter_server:handle_info/2
        #   fun counter_server:handle_continue/2
        #   fun counter_server:terminate/2
        callbacks = {
            'init':             mod_instance.init,
            'handle_call':      mod_instance.handle_call,
            'handle_cast':      mod_instance.handle_cast,
            'handle_info':      mod_instance.handle_info,
            'handle_continue':  mod_instance.handle_continue,
            'terminate':        mod_instance.terminate,
        }

        self._server_data = _ServerData(
            mod=mod_instance,
            mod_class=mod_class,
            callbacks=callbacks,
        )

        # Step 3: Call Mod:init/1 — Arrow ④⑤ (first callback invocation)
        try:
            init_result = callbacks['init'](args)
        except Exception as e:
            self._start_error = e
            self._started.set()
            return

        if init_result[0] == 'ok':
            self._server_data.state = init_result[1]
            self._alive.set()
            self._started.set()

            # Handle {continue, Term} from init
            if len(init_result) >= 3 and isinstance(init_result[2], dict):
                cont = init_result[2]
                if 'continue' in cont:
                    self._handle_continue(cont['continue'])

            # Step 4: Enter the receive loop
            self._loop()

        elif init_result[0] == 'stop':
            self._start_error = init_result[1] if len(init_result) > 1 else 'init_stop'
            self._started.set()
            return
        else:
            self._start_error = f"bad init return: {init_result}"
            self._started.set()
            return

    def _loop(self):
        """
        The main receive loop — Runtime Core of Generic Server.

        Equivalent to:
            receive → Mod:handle_call/3 …

        Processes messages from the mailbox and dispatches to
        the appropriate cached callback function.
        """
        sd = self._server_data
        while self._alive.is_set():
            try:
                msg = self._mailbox.get(timeout=0.1)
            except queue.Empty:
                continue

            try:
                if isinstance(msg, _CallMsg):
                    # Arrow ③→④: dispatch call to callback
                    result = sd.callbacks['handle_call'](
                        msg.request, msg.reply_queue, sd.state
                    )
                    self._process_call_result(result, msg.reply_queue)

                elif isinstance(msg, _CastMsg):
                    # Arrow ③→④: dispatch cast to callback
                    result = sd.callbacks['handle_cast'](msg.msg, sd.state)
                    self._process_noreply_result(result)

                elif isinstance(msg, _InfoMsg):
                    result = sd.callbacks['handle_info'](msg.info, sd.state)
                    self._process_noreply_result(result)

                elif isinstance(msg, _StopMsg):
                    self._do_terminate(msg.reason)
                    if msg.reply_queue:
                        msg.reply_queue.put(('ok',))
                    return

            except Exception as e:
                print(f"[gen_server] process crashed: {e}")
                traceback.print_exc()
                self._do_terminate(('error', e))
                return

    def _process_call_result(self, result: Tuple, reply_queue: queue.Queue):
        """Process the return value from handle_call — Arrow ⑤⑥."""
        sd = self._server_data
        if result[0] == 'reply':
            # ('reply', reply, new_state)
            reply = result[1]
            sd.state = result[2]
            # Arrow ⑥: Reply back to client
            reply_queue.put(reply)

            # Handle optional continue
            if len(result) >= 4 and isinstance(result[3], dict) and 'continue' in result[3]:
                self._handle_continue(result[3]['continue'])

        elif result[0] == 'noreply':
            sd.state = result[1]
            # Caller will block — manual reply needed

        elif result[0] == 'stop':
            # ('stop', reason, reply, new_state)
            reason = result[1]
            reply = result[2]
            sd.state = result[3]
            reply_queue.put(reply)
            self._do_terminate(reason)

    def _process_noreply_result(self, result: Tuple):
        """Process the return value from handle_cast / handle_info — Arrow ⑤."""
        sd = self._server_data
        if result[0] == 'noreply':
            sd.state = result[1]

            # Handle optional continue
            if len(result) >= 3 and isinstance(result[2], dict) and 'continue' in result[2]:
                self._handle_continue(result[2]['continue'])

        elif result[0] == 'stop':
            # ('stop', reason, new_state)
            reason = result[1]
            sd.state = result[2]
            self._do_terminate(reason)

    def _handle_continue(self, continue_arg: Any):
        """Dispatch handle_continue callback."""
        sd = self._server_data
        result = sd.callbacks['handle_continue'](continue_arg, sd.state)
        self._process_noreply_result(result)

    def _do_terminate(self, reason: Any):
        """Call terminate callback and mark process as dead."""
        sd = self._server_data
        self._alive.clear()
        try:
            sd.callbacks['terminate'](reason, sd.state)
        except Exception as e:
            print(f"[gen_server] error in terminate: {e}")


# ============================================================
# Public API — the Client API (left-top quadrant)
# These are the "thin wrappers" that send messages to the server.
# ============================================================

def start_link(mod_class: Type[GenServerBehaviour], args: Any = None,
               opts: dict = None) -> GenServerProcess:
    """
    Start a gen_server process linked to the caller.

    Equivalent to:
        gen_server:start_link(?MODULE, Args, Opts)

    This is Arrow ① in the architecture diagram:
        Pass module name → bind callback functions

    Args:
        mod_class: The callback module class (equivalent to ?MODULE)
        args: Arguments passed to Mod.init/1
        opts: Options (reserved for future use)

    Returns:
        GenServerProcess (equivalent to pid())

    Raises:
        RuntimeError: if init/1 fails
    """
    proc = GenServerProcess()
    proc._thread = threading.Thread(
        target=proc._init_it,
        args=(mod_class, args),
        daemon=True,
        name=f"gen_server:{mod_class.__name__}",
    )
    proc._thread.start()

    # Wait for init to complete (like proc_lib:start_link synchronous handshake)
    proc._started.wait(timeout=10)

    if proc._start_error is not None:
        raise RuntimeError(f"gen_server start failed: {proc._start_error}")

    return proc


def start(mod_class: Type[GenServerBehaviour], args: Any = None,
          opts: dict = None) -> GenServerProcess:
    """
    Start a standalone gen_server process (not linked).

    Equivalent to: gen_server:start(?MODULE, Args, Opts)
    """
    # In this Python implementation, start and start_link behave the same
    # since Python threads don't have Erlang-style linking.
    return start_link(mod_class, args, opts)


def call(server: GenServerProcess, request: Any, timeout: float = 5.0) -> Any:
    """
    Make a synchronous call to the server.

    Equivalent to: gen_server:call(Server, Request)

    Arrow ③: Client API → Generic Server (call)
    Arrow ⑥: Generic Server → Client API (Reply)

    Args:
        server: The server process (pid)
        request: The request term
        timeout: Timeout in seconds (default 5.0)

    Returns:
        The reply from handle_call

    Raises:
        RuntimeError: if server is not alive or timeout
    """
    if not server.is_alive:
        raise RuntimeError("gen_server: call to dead process")

    reply_q = queue.Queue(maxsize=1)
    server._mailbox.put(_CallMsg(request=request, reply_queue=reply_q))

    try:
        reply = reply_q.get(timeout=timeout)
        return reply
    except queue.Empty:
        raise RuntimeError(f"gen_server:call timeout after {timeout}s")


def cast(server: GenServerProcess, msg: Any) -> str:
    """
    Send an asynchronous message to the server.

    Equivalent to: gen_server:cast(Server, Msg)

    Arrow ③: Client API → Generic Server (cast)

    Returns:
        'ok' (always succeeds, fire-and-forget)
    """
    server._mailbox.put(_CastMsg(msg=msg))
    return 'ok'


def send_info(server: GenServerProcess, info: Any) -> str:
    """
    Send a raw info message to the server.

    Equivalent to: Server ! Info (Erlang's send operator)
    """
    server._mailbox.put(_InfoMsg(info=info))
    return 'ok'


def stop(server: GenServerProcess, reason: Any = 'normal',
         timeout: float = 5.0) -> str:
    """
    Stop the server.

    Equivalent to: gen_server:stop(Server)

    Args:
        server: The server process
        reason: Stop reason (default 'normal')
        timeout: Timeout in seconds

    Returns:
        'ok'
    """
    if not server.is_alive:
        return 'ok'

    reply_q = queue.Queue(maxsize=1)
    server._mailbox.put(_StopMsg(reason=reason, reply_queue=reply_q))

    try:
        reply_q.get(timeout=timeout)
    except queue.Empty:
        raise RuntimeError(f"gen_server:stop timeout after {timeout}s")

    return 'ok'


def reply(from_ref: queue.Queue, reply_msg: Any) -> str:
    """
    Send a reply to a caller manually.

    Equivalent to: gen_server:reply(From, Reply)

    Used when handle_call returns {noreply, State} and the reply
    is sent later.
    """
    from_ref.put(reply_msg)
    return 'ok'
