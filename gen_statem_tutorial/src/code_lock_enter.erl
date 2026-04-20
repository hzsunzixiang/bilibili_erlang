%%%-------------------------------------------------------------------
%%% @doc code_lock_enter - Demonstrates State Enter Actions.
%%%
%%% state_enter:
%%%   - Enabled by returning [state_functions, state_enter] from callback_mode/0
%%%   - gen_statem calls the state callback with event (enter, OldState, ...)
%%%     whenever a state change occurs
%%%   - State enter actions centralize state initialization logic
%%%   - In enter handler, must return keep_state (not next_state)
%%%   - Can use repeat_state to re-trigger enter action
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_enter).
-behaviour(gen_statem).
-define(NAME, code_lock_enter).

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
    process_flag(trap_exit, true),
    Data = #{code => Code, length => length(Code)},
    %% Note: no do_lock() here! It's handled by state enter
    {ok, locked, Data}.

callback_mode() ->
    [state_functions, state_enter].

%% State: locked
%% Enter action: lock the door and clear buttons
locked(enter, _OldState, Data) ->
    do_lock(),
    {keep_state, Data#{buttons => []}};

locked(cast, {button, Button},
       #{code := Code, length := Length, buttons := Buttons} = Data) ->
    NewButtons =
        if
            length(Buttons) < Length -> Buttons;
            true -> tl(Buttons)
        end ++ [Button],
    if
        NewButtons =:= Code ->
            %% No need to call do_unlock() here - open's enter handles it
            {next_state, open, Data};
        true ->
            {next_state, locked, Data#{buttons := NewButtons}}
    end.

%% State: open
%% Enter action: unlock the door and set state timeout
open(enter, _OldState, _Data) ->
    do_unlock(),
    {keep_state_and_data, [{state_timeout, 10000, lock}]};

open(state_timeout, lock, Data) ->
    %% No need to call do_lock() here - locked's enter handles it
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
    io:format("~n=== gen_statem Demo: State Enter Actions ===~n~n"),

    {ok, Pid} = start_link([a, b, c]),
    io:format("[1] Started code_lock_enter, pid=~p~n", [Pid]),
    io:format("    callback_mode() -> [state_functions, state_enter]~n"),
    io:format("    Lock/Unlock logic is in enter handlers, not in init~n~n"),

    io:format("--- Entering correct code ---~n"),
    button(a), button(b), button(c),
    timer:sleep(50),
    io:format("  State changed: locked -> open~n"),
    io:format("  open(enter, locked, Data) called -> do_unlock()~n~n"),

    io:format("--- Advantages of state_enter: ---~n"),
    io:format("  1. init/1 doesn't need to call do_lock()~n"),
    io:format("  2. State initialization is centralized in enter handler~n"),
    io:format("  3. Can use repeat_state to re-trigger enter action~n~n"),

    stop(),
    timer:sleep(50),
    io:format("[2] Stopped~n"),
    io:format("~n=== State Enter Actions Demo Complete ===~n~n"),
    ok.
