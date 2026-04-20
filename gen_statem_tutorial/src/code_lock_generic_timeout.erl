%%%-------------------------------------------------------------------
%%% @doc code_lock_generic_timeout - Demonstrates Generic Time-Outs.
%%%
%%% Generic timeout (named timeout):
%%%   - NOT cancelled by events or state changes
%%%   - Only cancelled explicitly via {{timeout, Name}, cancel}
%%%   - Can have multiple named timeouts running simultaneously
%%%   - Set via {{timeout, Name}, Time, EventContent}
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_generic_timeout).
-behaviour(gen_statem).
-define(NAME, code_lock_generic_timeout).

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
            %% Use generic timeout with name 'open'
            %% {{timeout, Name}, Time, EventContent}
            {next_state, open, Data#{buttons := []},
             [{{timeout, open}, 10000, lock}]};
        true ->
            {next_state, locked, Data#{buttons := NewButtons}}
    end.

%% State: open
%% Handle generic timeout - EventType is {timeout, Name}
open({timeout, open}, lock, Data) ->
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
    io:format("~n=== gen_statem Demo: Generic Time-Outs ===~n~n"),

    {ok, Pid} = start_link([a, b, c]),
    io:format("[1] Started code_lock_generic_timeout, pid=~p~n", [Pid]),
    io:format("    Uses {{timeout, open}, 10000, lock} instead of state_timeout~n~n"),

    io:format("--- Entering correct code ---~n"),
    button(a), button(b), button(c),
    timer:sleep(50),
    io:format("  Door opened! Generic timeout 'open' started (10s)~n"),
    io:format("  Unlike state_timeout, this won't cancel on state change~n"),
    io:format("  Unlike event_timeout, this won't cancel on any event~n~n"),

    stop(),
    timer:sleep(50),
    io:format("[2] Stopped~n"),
    io:format("~n=== Generic Time-Outs Demo Complete ===~n~n"),
    ok.
