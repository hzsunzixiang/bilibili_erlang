%%%-------------------------------------------------------------------
%%% @doc code_lock_complex - Demonstrates Complex State.
%%%
%%% In handle_event_function mode, state can be any term.
%%% Here we use {StateName, LockButton} as the state:
%%%   - StateName: locked | open
%%%   - LockButton: a button that can quickly lock the door
%%%
%%% Features:
%%%   - Complex state tuple {StateName, LockButton}
%%%   - state_enter with complex state
%%%   - set_lock_button/1 to change the lock button at runtime
%%%   - Pressing LockButton in open state immediately locks
%%%   - Other buttons in open state are postponed
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_complex).
-behaviour(gen_statem).
-define(NAME, code_lock_complex).

%% API
-export([start_link/2, button/1, set_lock_button/1, stop/0, demo/0]).

%% gen_statem callbacks
-export([init/1, callback_mode/0, terminate/3, code_change/4]).
-export([handle_event/4]).

%%====================================================================
%% API
%%====================================================================

start_link(Code, LockButton) ->
    gen_statem:start_link({local, ?NAME}, ?MODULE, {Code, LockButton}, []).

button(Button) ->
    gen_statem:cast(?NAME, {button, Button}).

set_lock_button(LockButton) ->
    gen_statem:call(?NAME, {set_lock_button, LockButton}).

stop() ->
    gen_statem:stop(?NAME).

%%====================================================================
%% gen_statem callbacks
%%====================================================================

init({Code, LockButton}) ->
    process_flag(trap_exit, true),
    Data = #{code => Code, length => length(Code), buttons => []},
    %% State is a tuple: {StateName, LockButton}
    {ok, {locked, LockButton}, Data}.

callback_mode() ->
    [handle_event_function, state_enter].

%%--------------------------------------------------------------------
%% State: {locked, LockButton}
%%--------------------------------------------------------------------

handle_event(enter, _OldState, {locked, _}, Data) ->
    do_lock(),
    {keep_state, Data#{buttons := []}};

handle_event(state_timeout, button, {locked, _}, Data) ->
    {keep_state, Data#{buttons := []}};

%% Button press in locked state - try to unlock
handle_event(cast, {button, Button}, {locked, LockButton},
             #{code := Code, length := Length, buttons := Buttons} = Data) ->
    NewButtons =
        if
            length(Buttons) < Length -> Buttons;
            true -> tl(Buttons)
        end ++ [Button],
    if
        NewButtons =:= Code ->
            {next_state, {open, LockButton}, Data};
        true ->
            {keep_state, Data#{buttons := NewButtons},
             [{state_timeout, 30000, button}]}
    end;

%%--------------------------------------------------------------------
%% State: {open, LockButton}
%%--------------------------------------------------------------------

handle_event(enter, _OldState, {open, _}, _Data) ->
    do_unlock(),
    {keep_state_and_data, [{state_timeout, 10000, lock}]};

handle_event(state_timeout, lock, {open, LockButton}, Data) ->
    {next_state, {locked, LockButton}, Data};

%% Pressing the LockButton in open state immediately locks!
handle_event(cast, {button, LockButton}, {open, LockButton}, Data) ->
    {next_state, {locked, LockButton}, Data};

%% Other buttons in open state are postponed
handle_event(cast, {button, _}, {open, _}, _Data) ->
    {keep_state_and_data, [postpone]};

%%--------------------------------------------------------------------
%% Common events (work in any state)
%%--------------------------------------------------------------------

%% Change the lock button at runtime
handle_event({call, From}, {set_lock_button, NewLockButton},
             {StateName, OldLockButton}, Data) ->
    {next_state, {StateName, NewLockButton}, Data,
     [{reply, From, OldLockButton}]}.

%%====================================================================
%% Internal functions
%%====================================================================

do_lock() ->
    io:format("Locked~n", []).

do_unlock() ->
    io:format("Open~n", []).

terminate(_Reason, State, _Data) ->
    State =/= locked andalso do_lock(),
    ok.

code_change(_OldVsn, State, Data, _Extra) ->
    {ok, State, Data}.

%%====================================================================
%% Demo
%%====================================================================

demo() ->
    io:format("~n=== gen_statem Demo: Complex State ===~n~n"),

    {ok, Pid} = start_link([a, b, c], x),
    io:format("[1] Started code_lock_complex, pid=~p~n", [Pid]),
    io:format("    State = {locked, x}, Code = [a, b, c]~n"),
    io:format("    LockButton = x (pressing x in open state locks immediately)~n~n"),

    %% Unlock
    io:format("--- Entering correct code ---~n"),
    button(a), button(b), button(c),
    timer:sleep(50),
    io:format("  State: {locked, x} -> {open, x}~n~n"),

    %% Press lock button to immediately lock
    io:format("--- Pressing lock button (x) while open ---~n"),
    button(x),
    timer:sleep(50),
    io:format("  State: {open, x} -> {locked, x} (immediate lock!)~n~n"),

    %% Unlock again
    button(a), button(b), button(c),
    timer:sleep(50),
    io:format("--- Door opened again ---~n"),

    %% Change lock button at runtime
    OldBtn = set_lock_button(y),
    io:format("[2] set_lock_button(y), old button was: ~p~n", [OldBtn]),
    io:format("    State is now {open, y}~n~n"),

    %% Now y is the lock button
    io:format("--- Pressing new lock button (y) ---~n"),
    button(y),
    timer:sleep(50),
    io:format("  State: {open, y} -> {locked, y}~n~n"),

    stop(),
    timer:sleep(50),
    io:format("[3] Stopped~n"),
    io:format("~n=== Complex State Demo Complete ===~n~n"),
    ok.
