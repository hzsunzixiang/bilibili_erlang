%%%-------------------------------------------------------------------
%%% @doc code_lock_postpone - Demonstrates Postponing Events.
%%%
%%% postpone action:
%%%   - Saves the current event to be retried after a state change
%%%   - Postponed events are replayed when state changes
%%%   - Useful when an event can't be handled in current state
%%%     but will be handleable in another state
%%%
%%% In this example, button presses in open state are postponed
%%% and replayed when the lock transitions back to locked state.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_postpone).
-behaviour(gen_statem).
-define(NAME, code_lock_postpone).

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

callback_mode() ->
    state_functions.

%% State: locked
locked(cast, {button, Button},
       #{code := Code, length := Length, buttons := Buttons} = Data) ->
    NewButtons =
        if
            length(Buttons) < Length -> Buttons;
            true -> tl(Buttons)
        end ++ [Button],
    if
        NewButtons =:= Code ->
            do_unlock(),
            {next_state, open, Data#{buttons := []},
             [{state_timeout, 10000, lock}]};
        true ->
            {next_state, locked, Data#{buttons := NewButtons}}
    end.

%% State: open
open(state_timeout, lock, Data) ->
    do_lock(),
    {next_state, locked, Data};

%% Instead of ignoring button presses, POSTPONE them!
%% They will be replayed when we transition back to locked
open(cast, {button, _}, Data) ->
    io:format("    [postpone] Button press postponed in open state~n"),
    {keep_state, Data, [postpone]}.

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
    io:format("~n=== gen_statem Demo: Postponing Events ===~n~n"),

    {ok, Pid} = start_link([a, b, c]),
    io:format("[1] Started code_lock_postpone, pid=~p~n", [Pid]),
    io:format("    Code: [a, b, c]~n~n"),

    %% Unlock
    io:format("--- Entering correct code to open ---~n"),
    button(a), button(b), button(c),
    timer:sleep(50),
    io:format("  Door opened!~n~n"),

    %% Press buttons while open - they get postponed
    io:format("--- Pressing buttons while open (will be postponed) ---~n"),
    button(a),
    button(b),
    timer:sleep(50),
    io:format("  Buttons [a, b] are postponed, waiting for state change~n~n"),

    io:format("--- When state_timeout fires and door locks: ---~n"),
    io:format("  Postponed events [a, b] will be replayed in locked state~n"),
    io:format("  (In real scenario, wait 10s for state_timeout)~n~n"),

    stop(),
    timer:sleep(50),
    io:format("[2] Stopped~n"),
    io:format("~n=== Postponing Events Demo Complete ===~n~n"),
    ok.
