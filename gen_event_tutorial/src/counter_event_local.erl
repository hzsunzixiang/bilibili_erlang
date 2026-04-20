%%%-------------------------------------------------------------------
%%% @doc local_event - Demonstrates gen_event with local name
%%%      registration ({local, Name}).
%%%
%%% emgr_ref() type:
%%%   atom() | {atom(), node()} | {global, term()} | {via, atom(), term()} | pid()
%%%
%%% This module demonstrates using a LOCALLY REGISTERED NAME (atom)
%%% as the emgr_ref() to locate the event manager.
%%%
%%% After starting with {local, Name}:
%%%   gen_event:start_link({local, my_event_mgr}, [])
%%%   gen_event:notify(my_event_mgr, Event)
%%%   gen_event:call(my_event_mgr, Handler, Request)
%%%   gen_event:stop(my_event_mgr)
%%%
%%% The local name is scoped to the current Erlang node only.
%%% Each node in a cluster can register the same name independently.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(counter_event_local).
-behaviour(gen_event).

%% API
-export([demo/0]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

-define(MGR_NAME, my_local_event_mgr).

%%====================================================================
%% API
%%====================================================================

demo() ->
    io:format("~n=== gen_event emgr_ref Demo: Local Name ({local, Name}) ===~n~n"),

    %% Start event manager with a local registered name
    %% After this, the manager can be referenced by the atom 'my_local_event_mgr'
    {ok, Pid} = gen_event:start_link({local, ?MGR_NAME}),
    io:format("[1] Event manager started~n"),
    io:format("    Pid: ~p~n", [Pid]),
    io:format("    Registered name: ~p~n", [?MGR_NAME]),
    io:format("    whereis(~p) = ~p~n~n", [?MGR_NAME, whereis(?MGR_NAME)]),

    %% Add handler — reference manager by local name (atom)
    ok = gen_event:add_handler(?MGR_NAME, ?MODULE, []),
    io:format("[2] Handler added using local name: ~p~n~n", [?MGR_NAME]),

    %% Send events — reference manager by local name
    io:format("--- Sending events via local name ---~n"),
    gen_event:notify(?MGR_NAME, {info, "user logged in"}),
    gen_event:notify(?MGR_NAME, {error, "connection timeout"}),
    gen_event:notify(?MGR_NAME, {warning, "disk 80% full"}),
    io:format("  Sent 3 events using gen_event:notify(~p, Event)~n~n", [?MGR_NAME]),

    %% Query handler state — reference manager by local name
    io:format("--- Querying handler via local name ---~n"),
    Count = gen_event:call(?MGR_NAME, ?MODULE, get_count),
    io:format("  gen_event:call(~p, ~p, get_count) = ~p~n", [?MGR_NAME, ?MODULE, Count]),
    Events = gen_event:call(?MGR_NAME, ?MODULE, get_events),
    io:format("  gen_event:call(~p, ~p, get_events) = ~p~n~n", [?MGR_NAME, ?MODULE, Events]),

    %% Also works with Pid directly (both are valid emgr_ref)
    io:format("--- Also works with Pid ---~n"),
    Count2 = gen_event:call(Pid, ?MODULE, get_count),
    io:format("  gen_event:call(Pid, ~p, get_count) = ~p~n~n", [?MODULE, Count2]),

    %% List handlers — reference by local name
    Handlers = gen_event:which_handlers(?MGR_NAME),
    io:format("[3] which_handlers(~p) = ~p~n~n", [?MGR_NAME, Handlers]),

    %% Stop — reference by local name
    gen_event:stop(?MGR_NAME),
    io:format("[4] Event manager stopped via gen_event:stop(~p)~n", [?MGR_NAME]),
    io:format("    whereis(~p) = ~p~n~n", [?MGR_NAME, whereis(?MGR_NAME)]),

    io:format("=== Local Name Demo Complete ===~n~n"),
    ok.

%%====================================================================
%% gen_event callbacks
%%====================================================================

init([]) ->
    io:format("    [~p] init: handler installed~n", [?MODULE]),
    {ok, #{events => [], count => 0}}.

handle_event({Type, Msg}, #{events := Events, count := C} = _State) ->
    io:format("    [~p] handle_event: {~p, ~p}~n", [?MODULE, Type, Msg]),
    NewState = #{events => [{Type, Msg} | Events], count => C + 1},
    {ok, NewState};
handle_event(_Event, State) ->
    {ok, State}.

handle_call(get_count, #{count := C} = State) ->
    {ok, C, State};
handle_call(get_events, #{events := Events} = State) ->
    {ok, lists:reverse(Events), State};
handle_call(_Request, State) ->
    {ok, {error, unknown}, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(Reason, #{count := C}) ->
    io:format("    [~p] terminate: reason=~p, handled ~p events~n",
              [?MODULE, Reason, C]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
