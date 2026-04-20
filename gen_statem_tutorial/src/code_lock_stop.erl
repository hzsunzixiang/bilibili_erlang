%%%-------------------------------------------------------------------
%%% @doc code_lock_stop - Demonstrates stopping a gen_statem.
%%%
%%% Shows:
%%%   - gen_statem:stop/1 for standalone stop
%%%   - process_flag(trap_exit, true) for supervision tree
%%%   - terminate/3 callback for cleanup
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_stop).
-behaviour(gen_statem).
-define(NAME, code_lock_stop).

%% API
-export([start_link/1, button/1, code_length/0, stop/0, demo/0]).

%% gen_statem callbacks
-export([init/1, callback_mode/0, terminate/3, code_change/4]).
-export([handle_event/4]).

%%====================================================================
%% API
%%====================================================================

start_link(Code) ->
    gen_statem:start_link({local, ?NAME}, ?MODULE, Code, []).

button(Button) ->
    gen_statem:cast(?NAME, {button, Button}).

code_length() ->
    gen_statem:call(?NAME, code_length).

stop() ->
    gen_statem:stop(?NAME).

%%====================================================================
%% gen_statem callbacks
%%====================================================================

init(Code) ->
    %% trap_exit is important for supervision tree
    process_flag(trap_exit, true),
    do_lock(),
    Data = #{code => Code, length => length(Code), buttons => []},
    {ok, locked, Data}.

callback_mode() ->
    handle_event_function.

handle_event(cast, {button, Button}, State, #{code := Code} = Data) ->
    case State of
        locked ->
            #{length := Length, buttons := Buttons} = Data,
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
                    {keep_state, Data#{buttons := NewButtons}}
            end;
        open ->
            keep_state_and_data
    end;
handle_event(state_timeout, lock, open, Data) ->
    do_lock(),
    {next_state, locked, Data};
handle_event({call, From}, code_length, _State, #{code := Code} = Data) ->
    {keep_state, Data, [{reply, From, length(Code)}]}.

%%====================================================================
%% Internal functions
%%====================================================================

do_lock() ->
    io:format("Lock~n", []).

do_unlock() ->
    io:format("Unlock~n", []).

terminate(Reason, State, _Data) ->
    io:format("    [terminate] reason=~p, state=~p~n", [Reason, State]),
    State =/= locked andalso do_lock(),
    ok.

code_change(_OldVsn, State, Data, _Extra) ->
    {ok, State, Data}.

%%====================================================================
%% Demo
%%====================================================================

demo() ->
    io:format("~n=== gen_statem Demo: Stopping ===~n~n"),

    {ok, Pid} = start_link([a, b, c]),
    io:format("[1] Started code_lock_stop, pid=~p~n", [Pid]),
    io:format("    process_flag(trap_exit, true) set~n~n"),

    %% Unlock first
    button(a), button(b), button(c),
    timer:sleep(50),
    io:format("[2] Door opened~n~n"),

    %% Stop while in open state - terminate/3 will be called
    io:format("--- Calling gen_statem:stop/1 while in open state ---~n"),
    stop(),
    timer:sleep(50),
    io:format("[3] Process stopped, terminate/3 was called~n"),
    io:format("    (terminate locked the door before exit)~n"),
    io:format("~n=== Stopping Demo Complete ===~n~n"),
    ok.
