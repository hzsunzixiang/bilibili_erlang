%%%-------------------------------------------------------------------
%%% @doc code_lock_selective - Selective Receive implementation.
%%%
%%% This is a plain Erlang implementation (no gen_statem) showing
%%% how a state machine can be built using selective receive.
%%% This is what gen_statem replaces and improves upon.
%%%
%%% The state is implicit in which function is currently executing:
%%%   - locked/3 function = locked state
%%%   - open/2 function = open state
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_selective).
-define(NAME, code_lock_selective).

%% API
-export([start_link/1, button/1, demo/0]).

%%====================================================================
%% API
%%====================================================================

start_link(Code) ->
    spawn_link(
      fun() ->
              true = register(?NAME, self()),
              do_lock(),
              locked(Code, length(Code), [])
      end).

button(Button) ->
    ?NAME ! {button, Button}.

%%====================================================================
%% State functions (using selective receive)
%%====================================================================

locked(Code, Length, Buttons) ->
    receive
        {button, Button} ->
            NewButtons =
                if
                    length(Buttons) < Length -> Buttons;
                    true -> tl(Buttons)
                end ++ [Button],
            if
                NewButtons =:= Code ->
                    do_unlock(),
                    open(Code, Length);
                true ->
                    locked(Code, Length, NewButtons)
            end
    end.

open(Code, Length) ->
    receive
    after 10000 ->
            do_lock(),
            locked(Code, Length, [])
    end.

%%====================================================================
%% Internal functions
%%====================================================================

do_lock() ->
    io:format("Locked~n", []).

do_unlock() ->
    io:format("Open~n", []).

%%====================================================================
%% Demo
%%====================================================================

demo() ->
    io:format("~n=== Selective Receive Demo (No gen_statem) ===~n~n"),

    Pid = start_link([a, b, c]),
    io:format("[1] Started plain process, pid=~p~n", [Pid]),
    io:format("    State is implicit in which function is executing~n"),
    io:format("    locked/3 = locked state, open/2 = open state~n~n"),

    io:format("--- Entering correct code ---~n"),
    button(a),
    button(b),
    button(c),
    timer:sleep(50),
    io:format("  Door opened!~n~n"),

    io:format("--- Limitations of this approach: ---~n"),
    io:format("  1. No supervision tree integration~n"),
    io:format("  2. No sys module support (tracing, statistics)~n"),
    io:format("  3. No code_change support~n"),
    io:format("  4. No built-in timeout types~n"),
    io:format("  5. No postpone mechanism~n"),
    io:format("  6. No state enter actions~n"),
    io:format("  -> Use gen_statem instead!~n~n"),

    %% Stop the process
    unregister(?NAME),
    exit(Pid, normal),
    timer:sleep(50),
    io:format("[2] Process stopped~n"),
    io:format("~n=== Selective Receive Demo Complete ===~n~n"),
    ok.
