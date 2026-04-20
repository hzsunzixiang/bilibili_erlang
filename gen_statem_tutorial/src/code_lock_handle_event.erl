%%%-------------------------------------------------------------------
%%% @doc code_lock_handle_event - gen_statem with handle_event_function mode.
%%%
%%% Demonstrates:
%%%   - callback_mode() -> handle_event_function
%%%   - All events handled in Module:handle_event/4
%%%   - Event-centered approach: first branch on event, then on state
%%%   - Adds code_length/0 as a {call, From} example
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(code_lock_handle_event).
-behaviour(gen_statem).
-define(NAME, code_lock_handle_event).

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
    do_lock(),
    Data = #{code => Code, length => length(Code), buttons => []},
    {ok, locked, Data}.

%% handle_event_function: all events handled in handle_event/4
callback_mode() ->
    handle_event_function.

%% Event-centered approach: first branch on event, then on state
%%
%% handle_event(EventType, EventContent, State, Data) -> Result

%% Handle button press - branch by state
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
                NewButtons =:= Code -> % Correct
                    do_unlock(),
                    {next_state, open, Data#{buttons := []},
                     [{state_timeout, 10000, lock}]};
                true -> % Incomplete | Incorrect
                    {keep_state, Data#{buttons := NewButtons}}
            end;
        open ->
            keep_state_and_data
    end;

%% Handle state timeout
handle_event(state_timeout, lock, open, Data) ->
    do_lock(),
    {next_state, locked, Data};

%% Handle synchronous call - works in any state
handle_event({call, From}, code_length, _State, #{code := Code} = Data) ->
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
    io:format("~n=== gen_statem Demo: handle_event_function ===~n~n"),

    {ok, Pid} = start_link([a, b, c]),
    io:format("[1] Started code_lock_handle_event, pid=~p~n", [Pid]),

    %% Query code length (works in any state)
    Len = code_length(),
    io:format("[2] code_length() = ~p (call works in any state)~n~n", [Len]),

    io:format("--- Entering correct code ---~n"),
    button(a),
    button(b),
    button(c),
    timer:sleep(50),
    io:format("  Door opened!~n~n"),

    %% Query code length while open
    Len2 = code_length(),
    io:format("[3] code_length() while open = ~p~n~n", [Len2]),

    io:format("--- Button while open (ignored) ---~n"),
    button(x),
    timer:sleep(50),
    io:format("  Button ignored in open state~n~n"),

    stop(),
    timer:sleep(50),
    io:format("[4] Stopped~n"),
    io:format("~n=== handle_event_function Demo Complete ===~n~n"),
    ok.
