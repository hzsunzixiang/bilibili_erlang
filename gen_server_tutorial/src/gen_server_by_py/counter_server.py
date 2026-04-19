"""
counter_server.py  –  A Python gen_server callback module (counter example).

Architecture Mapping (from gen_server_architecture.tex):

  This file implements BOTH:
    - Left-Top:    Client API (thin wrappers around gen_server.call/cast/stop)
    - Left-Bottom: Callback Module (user-written callbacks)

  Equivalent to counter_server.erl:
    -module(counter_server).
    -behaviour(gen_server).

  After start_link(CounterServer, ...):
    fun counter_server:init/1
    fun counter_server:handle_call/3
    fun counter_server:handle_cast/2
    fun counter_server:handle_info/2
    fun counter_server:handle_continue/2
    fun counter_server:terminate/2

  The ?MODULE info is cached in the GenServerProcess (≈ #server_data{}).
"""

from __future__ import annotations

import threading
from typing import Any, Tuple

import gen_server
from gen_server import GenServerBehaviour, GenServerProcess


# ============================================================
# Callback Module (bottom-left quadrant)
# Equivalent to:
#   -module(counter_server).
#   -behaviour(gen_server).
# ============================================================

class CounterServer(GenServerBehaviour):
    """
    A minimal gen_server callback module — counter example.

    State: {'count': int, 'history': list}

    Callbacks:
        init/1            → initialize counter
        handle_call/3     → increment, decrement, get_count, slow_op
        handle_cast/2     → reset, crash
        handle_info/2     → custom messages
        handle_continue/2 → post_init
        terminate/2       → cleanup
    """

    # ---- init/1 ----
    def init(self, args: Any) -> Tuple:
        """
        Initialize the counter state.

        Equivalent to:
            init(InitCount) when is_integer(InitCount) ->
                process_flag(trap_exit, true),
                {ok, #{count => InitCount, history => []},
                 {continue, post_init}}.
        """
        init_count = args if isinstance(args, int) else 0
        print(f"[counter] init: count={init_count}, "
              f"tid={threading.current_thread().ident}")

        state = {'count': init_count, 'history': []}
        return ('ok', state, {'continue': 'post_init'})

    # ---- handle_continue/2 ----
    def handle_continue(self, continue_arg: Any, state: Any) -> Tuple:
        """
        Post-initialization hook.

        Equivalent to:
            handle_continue(post_init, State) ->
                io:format("[counter] post_init complete~n"),
                {noreply, State}.
        """
        if continue_arg == 'post_init':
            print("[counter] post_init complete")
        return ('noreply', state)

    # ---- handle_call/3 ----
    def handle_call(self, request: Any, from_ref: Any, state: Any) -> Tuple:
        """
        Handle synchronous requests.

        Equivalent to:
            handle_call(increment, _From, #{count := C} = State) -> ...
            handle_call(decrement, _From, #{count := C} = State) -> ...
            handle_call(get_count, _From, #{count := C} = State) -> ...
            handle_call({slow_op, Duration}, _From, State) -> ...
        """
        if request == 'increment':
            new_count = state['count'] + 1
            state['count'] = new_count
            state['history'].append(('increment', new_count))
            return ('reply', new_count, state)

        elif request == 'decrement':
            new_count = state['count'] - 1
            state['count'] = new_count
            state['history'].append(('decrement', new_count))
            return ('reply', new_count, state)

        elif request == 'get_count':
            return ('reply', state['count'], state)

        elif isinstance(request, tuple) and request[0] == 'slow_op':
            import time
            duration = request[1]
            time.sleep(duration)
            return ('reply', ('ok', 'done_after', duration), state)

        else:
            return ('reply', ('error', 'unknown_request'), state)

    # ---- handle_cast/2 ----
    def handle_cast(self, msg: Any, state: Any) -> Tuple:
        """
        Handle asynchronous messages.

        Equivalent to:
            handle_cast(reset, State) -> {noreply, State#{count := 0}}.
            handle_cast(crash, _State) -> error(deliberate_crash).
        """
        if msg == 'reset':
            print("[counter] reset to 0")
            state['count'] = 0
            state['history'] = []
            return ('noreply', state)

        elif msg == 'crash':
            raise RuntimeError("deliberate_crash")

        else:
            return ('noreply', state)

    # ---- handle_info/2 ----
    def handle_info(self, info: Any, state: Any) -> Tuple:
        """
        Handle raw messages.

        Equivalent to:
            handle_info({custom_msg, Payload}, State) -> ...
            handle_info(Info, State) -> ...
        """
        if isinstance(info, tuple) and len(info) == 2 and info[0] == 'custom_msg':
            print(f"[counter] received custom_msg: {info[1]!r}")
            return ('noreply', state)

        print(f"[counter] unexpected info: {info!r}")
        return ('noreply', state)

    # ---- terminate/2 ----
    def terminate(self, reason: Any, state: Any) -> None:
        """
        Cleanup on shutdown.

        Equivalent to:
            terminate(Reason, #{count := C}) ->
                io:format("[counter] terminating: reason=~p, final_count=~p~n",
                          [Reason, C]).
        """
        print(f"[counter] terminating: reason={reason!r}, "
              f"final_count={state.get('count', '?')}")


# ============================================================
# Client API (top-left quadrant)
# Thin wrappers around gen_server library functions.
#
# Equivalent to:
#   start_link() -> gen_server:start_link(?MODULE, 0, []).
#   increment(Server) -> gen_server:call(Server, increment).
#   ...
# ============================================================

def start_link(init_count: int = 0) -> GenServerProcess:
    """
    Start a linked counter server.

    Equivalent to:
        start_link() -> gen_server:start_link(?MODULE, 0, []).
        start_link(InitCount) -> gen_server:start_link(?MODULE, InitCount, []).

    Arrow ①: Pass module name (?MODULE = CounterServer) → bind callbacks
    """
    return gen_server.start_link(CounterServer, init_count)


def start(init_count: int = 0) -> GenServerProcess:
    """Start a standalone counter server."""
    return gen_server.start(CounterServer, init_count)


def increment(server: GenServerProcess) -> int:
    """
    Increment the counter.

    Equivalent to:
        increment(Server) -> gen_server:call(Server, increment).
    """
    return gen_server.call(server, 'increment')


def decrement(server: GenServerProcess) -> int:
    """
    Decrement the counter.

    Equivalent to:
        decrement(Server) -> gen_server:call(Server, decrement).
    """
    return gen_server.call(server, 'decrement')


def get_count(server: GenServerProcess) -> int:
    """
    Get the current count.

    Equivalent to:
        get_count(Server) -> gen_server:call(Server, get_count).
    """
    return gen_server.call(server, 'get_count')


def reset(server: GenServerProcess) -> str:
    """
    Reset the counter to 0.

    Equivalent to:
        reset(Server) -> gen_server:cast(Server, reset).
    """
    return gen_server.cast(server, 'reset')


def slow_operation(server: GenServerProcess, duration: float) -> Any:
    """
    Perform a slow operation (blocks for duration seconds).

    Equivalent to:
        slow_operation(Server, Duration) ->
            gen_server:call(Server, {slow_op, Duration}).
    """
    return gen_server.call(server, ('slow_op', duration), timeout=duration + 5)


def crash(server: GenServerProcess) -> str:
    """
    Deliberately crash the server.

    Equivalent to:
        crash(Server) -> gen_server:cast(Server, crash).
    """
    return gen_server.cast(server, 'crash')
