%%%-------------------------------------------------------------------
%%% lock_state_local - gen_statem with local registered name.
%%%-------------------------------------------------------------------
-module(lock_state_local).
-behaviour(gen_statem).

%% API
-export([start_link/2, button/2, stop/1, demo/0]).

%% gen_statem callbacks
-export([init/1, callback_mode/0, terminate/3, code_change/4]).
-export([locked/3, open/3]).

%%====================================================================
%% API
%%====================================================================

%% start_link(ServerName, Module, Args, Opts), ServerName={local, atom()}
start_link(Name, Code) when is_atom(Name) ->
    gen_statem:start_link({local, Name}, ?MODULE, Code, []).

button(Name, Button) when is_atom(Name) ->
    gen_statem:cast(Name, {button, Button}).

stop(Name) when is_atom(Name) ->
    gen_statem:stop(Name).

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
    io:format("~n=== Demo: lock_state_local ===~n~n"),

    Name = lock_state_local_demo,
    {ok, _Pid} = start_link(Name, [a, b, c]),
    io:format("[1] Started lock_state_local, name=~p~n", [Name]),

    button(Name, a),
    button(Name, b),
    button(Name, c),
    timer:sleep(50),

    stop(Name),
    timer:sleep(50),
    io:format("[2] Stopped lock_state_local~n~n"),
    ok.
