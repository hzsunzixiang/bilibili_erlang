%%%-------------------------------------------------------------------
%%% @doc code_lock_event_timeout - Demonstrates Event Time-Outs.
%%%
%%% Event timeout is inherited from gen_fsm:
%%%   - ANY event arriving cancels the timer
%%%   - You get either an event or a timeout, but not both
%%%   - Set via {timeout, Time, EventContent} or just an integer Time
%%%
%%% In this example, if no button is pressed within 20 seconds,
%%% the entered buttons are cleared.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_event_timeout).
-behaviour(gen_statem).
-define(NAME, code_lock_event_timeout).

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

%% Event timeout expired - clear buttons
%% This fires if no event arrives within the timeout period
locked(timeout, _, Data) ->
    io:format("    [event_timeout] No input for too long, clearing buttons~n"),
    {next_state, locked, Data#{buttons := []}};

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
            %% Set event timeout: if no button pressed within 20s, clear
            %% Using the short form: just an integer
            {next_state, locked, Data#{buttons := NewButtons}, 20000}
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
    io:format("~n=== gen_statem Demo: Event Time-Outs ===~n~n"),

    {ok, Pid} = start_link([a, b, c]),
    io:format("[1] Started code_lock_event_timeout, pid=~p~n", [Pid]),
    io:format("    Event timeout = 20s (clears buttons if no input)~n~n"),

    io:format("--- Entering partial code ---~n"),
    button(a),
    button(b),
    timer:sleep(50),
    io:format("  Sent [a, b] - partial code entered~n"),
    io:format("  Event timeout started (20s)~n"),
    io:format("  If another button arrives, timeout resets~n~n"),

    io:format("--- Completing the code before timeout ---~n"),
    button(c),
    timer:sleep(50),
    io:format("  Sent [c] - code complete! Door opened~n~n"),

    stop(),
    timer:sleep(50),
    io:format("[2] Stopped~n"),
    io:format("~n=== Event Time-Outs Demo Complete ===~n~n"),
    ok.
