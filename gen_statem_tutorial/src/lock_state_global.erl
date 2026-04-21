%%%-------------------------------------------------------------------
%%% lock_state_global - gen_statem with global registered name.
%%%-------------------------------------------------------------------
-module(lock_state_global).
-behaviour(gen_statem).

%% API
-export([start_link/2, button/2, stop/1, demo/0]).

%% gen_statem callbacks
-export([init/1, callback_mode/0, terminate/3, code_change/4]).
-export([locked/3, open/3]).

%%====================================================================
%% API
%%====================================================================

%% start_link(ServerName, Module, Args, Opts), ServerName={global, GlobalName}
start_link(GlobalName, Code) ->
    gen_statem:start_link({global, GlobalName}, ?MODULE, Code, []).

button(GlobalName, Button) ->
    gen_statem:cast({global, GlobalName}, {button, Button}).

stop(GlobalName) ->
    gen_statem:stop({global, GlobalName}).

%%====================================================================
%% gen_statem callbacks
%%====================================================================

init(Code) ->
    do_lock(),
    Data = #{code => Code, length => length(Code), buttons => []},
    {ok, locked, Data}.

callback_mode() ->
    state_functions.

locked(cast, {button, Button},
       #{code := Code, length := Length, buttons := Buttons} = Data) ->
    NewButtons =
        (if
             length(Buttons) < Length -> Buttons;
             true -> tl(Buttons)
         end) ++ [Button],
    if
        NewButtons =:= Code ->
            do_unlock(),
            {next_state, open, Data#{buttons := []},
             [{state_timeout, 10000, lock}]};
        true ->
            {next_state, locked, Data#{buttons := NewButtons}}
    end.

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
    io:format("~n=== Demo: lock_state_global ===~n~n"),

    GlobalName = {lock_state_global, node()},
    {ok, _Pid} = start_link(GlobalName, [a, b, c]),
    io:format("[1] Started lock_state_global, global=~p~n", [GlobalName]),

    button(GlobalName, a),
    button(GlobalName, b),
    button(GlobalName, c),
    timer:sleep(50),

    stop(GlobalName),
    timer:sleep(50),
    io:format("[2] Stopped lock_state_global~n~n"),
    ok.
