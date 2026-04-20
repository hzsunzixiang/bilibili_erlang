%%%-------------------------------------------------------------------
%%% @doc code_lock_state - Basic gen_statem with state_functions mode.
%%%
%%% Demonstrates the simplest gen_statem usage:
%%%   - callback_mode() -> state_functions
%%%   - Each state (locked, open) has its own callback function
%%%   - Uses state_timeout to auto-lock after 10 seconds
%%%
%%% State Diagram:
%%%   locked ---(correct code)---> open
%%%   open   ---(state_timeout)--> locked
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_state).
-behaviour(gen_statem).
-define(NAME, code_lock_state).

%% API
-export([start_link/1, button/1, stop/0, demo/0]).

%% gen_statem callbacks
-export([init/1, callback_mode/0, terminate/3, code_change/4]).
-export([locked/3, open/3]).

%%====================================================================
%% API
%%====================================================================

start_link(Code) ->
    gen_statem:start_link({local, ?NAME}, ?MODULE, Code, []).

button(Button) ->
    gen_statem:cast(?NAME, {button, Button}).

stop() ->
    gen_statem:stop(?NAME).

%%====================================================================
%% gen_statem callbacks
%%====================================================================

init(Code) ->
    do_lock(),
    Data = #{code => Code, length => length(Code), buttons => []},
    {ok, locked, Data}.

%% state_functions: each state has its own handler function
callback_mode() ->
    state_functions.

%% State: locked
%% Module:StateName(EventType, EventContent, Data) -> StateFunctionResult
locked(cast, {button, Button},
       #{code := Code, length := Length, buttons := Buttons} = Data) ->
    NewButtons =
        if
            length(Buttons) < Length -> Buttons;
            true -> tl(Buttons)
        end ++ [Button],
    if
        NewButtons =:= Code -> % Correct code
            do_unlock(),
            {next_state, open, Data#{buttons := []},
             [{state_timeout, 10000, lock}]};
        true -> % Incomplete or incorrect
            {next_state, locked, Data#{buttons := NewButtons}}
    end.

%% State: open
open(state_timeout, lock, Data) ->
    do_lock(),
    {next_state, locked, Data};
open(cast, {button, _}, Data) ->
    {next_state, open, Data}.

%%====================================================================
%% Internal functions
%%====================================================================

do_lock() ->
    io:format("Lock~n", []).

do_unlock() ->
    io:format("Unlock~n", []).

terminate(_Reason, State, _Data) ->
    State =/= locked andalso do_lock(),
    ok.

code_change(_OldVsn, State, Data, _Extra) ->
    {ok, State, Data}.

%%====================================================================
%% Demo
%%====================================================================

demo() ->
    io:format("~n=== gen_statem Demo: state_functions (Basic) ===~n~n"),

    {ok, Pid} = start_link([a, b, c]),
    io:format("[1] Started code_lock_state, pid=~p~n", [Pid]),
    io:format("    State: locked, Code: [a, b, c]~n~n"),

    io:format("--- Entering wrong code ---~n"),
    button(x),
    button(y),
    button(z),
    timer:sleep(50),
    io:format("  Sent [x, y, z] - wrong code, still locked~n~n"),

    io:format("--- Entering correct code ---~n"),
    button(a),
    button(b),
    button(c),
    timer:sleep(50),
    io:format("  Sent [a, b, c] - correct! Door opened~n~n"),

    io:format("--- Pressing button while open ---~n"),
    button(x),
    timer:sleep(50),
    io:format("  Button ignored while open~n~n"),

    io:format("--- Waiting for state_timeout (2s for demo) ---~n"),
    %% Note: actual timeout is 10s, we stop early for demo
    timer:sleep(100),

    stop(),
    timer:sleep(50),
    io:format("~n[2] Stopped code_lock_state~n"),
    io:format("~n=== state_functions Demo Complete ===~n~n"),
    ok.
