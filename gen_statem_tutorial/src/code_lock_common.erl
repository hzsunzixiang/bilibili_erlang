%%%-------------------------------------------------------------------
%%% @doc code_lock_common - Demonstrates All State Events handling.
%%%
%%% Shows how to handle events that are common to all states
%%% using a shared handle_common/3 function.
%%%
%%% The code_length/0 call works in both locked and open states
%%% by delegating to handle_common/3.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_common).
-behaviour(gen_statem).
-define(NAME, code_lock_common).

%% API
-export([start_link/1, button/1, code_length/0, stop/0, demo/0]).

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

%% This call works in any state via handle_common
code_length() ->
    gen_statem:call(?NAME, code_length).

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
    end;
%% Delegate all other events to handle_common
locked(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

%% State: open
open(state_timeout, lock, Data) ->
    do_lock(),
    {next_state, locked, Data};
open(cast, {button, _}, Data) ->
    {next_state, open, Data};
%% Delegate all other events to handle_common
open(EventType, EventContent, Data) ->
    handle_common(EventType, EventContent, Data).

%%====================================================================
%% Common event handler (shared by all states)
%%====================================================================

handle_common({call, From}, code_length, #{code := Code} = Data) ->
    {keep_state, Data, [{reply, From, length(Code)}]}.

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
    io:format("~n=== gen_statem Demo: All State Events (Common Handler) ===~n~n"),

    {ok, Pid} = start_link([a, b, c]),
    io:format("[1] Started code_lock_common, pid=~p~n~n", [Pid]),

    %% Call code_length in locked state
    Len1 = code_length(),
    io:format("[2] code_length() in locked state = ~p~n", [Len1]),

    %% Unlock
    button(a), button(b), button(c),
    timer:sleep(50),
    io:format("[3] Door opened~n"),

    %% Call code_length in open state - same handler!
    Len2 = code_length(),
    io:format("[4] code_length() in open state = ~p~n", [Len2]),
    io:format("    Both calls handled by handle_common/3~n~n"),

    stop(),
    timer:sleep(50),
    io:format("[5] Stopped~n"),
    io:format("~n=== All State Events Demo Complete ===~n~n"),
    ok.
