%%% @doc event_bus_handler - Default gen_event handler for event_bus.
%%%
%%% Logs all received events to stdout with timestamps.
%%% Tracks the total number of events processed.
%%%
%%% This handler is automatically installed when event_bus starts.
-module(event_bus_handler).
-behaviour(gen_event).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {
    count = 0 :: non_neg_integer()
}).

%%====================================================================
%% gen_event callbacks
%%====================================================================

init([]) ->
    io:format("[event_bus_handler] init~n"),
    {ok, #state{}}.

handle_event(Event, #state{count = N} = State) ->
    Timestamp = format_time(),
    io:format("[event_bus ~s] event #~p: ~p~n", [Timestamp, N + 1, Event]),
    {ok, State#state{count = N + 1}};
handle_event(_Event, State) ->
    {ok, State}.

handle_call(get_count, #state{count = N} = State) ->
    {ok, N, State};
handle_call(_Request, State) ->
    {ok, {error, unknown_request}, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(Reason, #state{count = N}) ->
    io:format("[event_bus_handler] terminate: reason=~p, processed ~p events~n",
              [Reason, N]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Internal functions
%%====================================================================

format_time() ->
    {{_Y, _M, _D}, {H, Mi, S}} = calendar:local_time(),
    lists:flatten(io_lib:format("~2..0w:~2..0w:~2..0w", [H, Mi, S])).
