%%%-------------------------------------------------------------------
%%% @doc code_lock_erlang_timer - Demonstrates Erlang Timers.
%%%
%%% Uses erlang:start_timer/3 instead of gen_statem timeout actions:
%%%   - Timer reference stored in Data
%%%   - Timeout message arrives as info event
%%%   - Can be cancelled with erlang:cancel_timer/1
%%%   - Most flexible timer approach
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_erlang_timer).
-behaviour(gen_statem).
-define(NAME, code_lock_erlang_timer).

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
            %% Use erlang:start_timer/3 - store timer ref in Data
            Tref = erlang:start_timer(10000, self(), lock),
            {next_state, open, Data#{buttons := [], timer => Tref}};
        true ->
            {next_state, locked, Data#{buttons := NewButtons}}
    end.

%% State: open
%% Timer message arrives as info event: {timeout, Tref, lock}
%% Match Tref from Data to ensure it's our timer
open(info, {timeout, Tref, lock}, #{timer := Tref} = Data) ->
    do_lock(),
    {next_state, locked, maps:remove(timer, Data)};
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
    io:format("~n=== gen_statem Demo: Erlang Timers ===~n~n"),

    {ok, Pid} = start_link([a, b, c]),
    io:format("[1] Started code_lock_erlang_timer, pid=~p~n", [Pid]),
    io:format("    Uses erlang:start_timer/3 for maximum flexibility~n~n"),

    io:format("--- Entering correct code ---~n"),
    button(a), button(b), button(c),
    timer:sleep(50),
    io:format("  Door opened! erlang:start_timer(10000, self(), lock) started~n"),
    io:format("  Timer ref stored in Data map~n"),
    io:format("  Timeout arrives as info event: {timeout, Tref, lock}~n~n"),

    stop(),
    timer:sleep(50),
    io:format("[2] Stopped~n"),
    io:format("~n=== Erlang Timers Demo Complete ===~n~n"),
    ok.
