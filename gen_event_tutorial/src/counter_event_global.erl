%%%-------------------------------------------------------------------
%%% @doc global_event - Demonstrates gen_event with global name
%%%      registration ({global, GlobalName}).
%%%
%%% emgr_ref() type:
%%%   atom() | {atom(), node()} | {global, term()} | {via, atom(), term()} | pid()
%%%
%%% This module demonstrates using a GLOBALLY REGISTERED NAME
%%% ({global, GlobalName}) as the emgr_ref() to locate the event manager.
%%%
%%% After starting with {global, Name}:
%%%   gen_event:start_link({global, my_global_mgr}, [])
%%%   gen_event:notify({global, my_global_mgr}, Event)
%%%   gen_event:call({global, my_global_mgr}, Handler, Request)
%%%   gen_event:stop({global, my_global_mgr})
%%%
%%% The global name is registered via the `global` module, which
%%% maintains a cluster-wide name registry across all connected nodes.
%%% Only ONE process in the entire cluster can hold a given global name.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(counter_event_global).
-behaviour(gen_event).

%% API
-export([demo/0]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

-define(GLOBAL_NAME, my_global_event_mgr).

%%====================================================================
%% API
%%====================================================================

demo() ->
    io:format("~n=== gen_event emgr_ref Demo: Global Name ({global, Name}) ===~n~n"),

    %% Start event manager with a global registered name
    %% After this, the manager can be referenced from ANY connected node
    %% using {global, my_global_event_mgr}
    {ok, Pid} = gen_event:start_link({global, ?GLOBAL_NAME}),
    io:format("[1] Event manager started with global name~n"),
    io:format("    Pid: ~p~n", [Pid]),
    io:format("    Global name: ~p~n", [?GLOBAL_NAME]),
    io:format("    global:whereis_name(~p) = ~p~n~n",
              [?GLOBAL_NAME, global:whereis_name(?GLOBAL_NAME)]),

    %% Add handler — reference manager by {global, Name}
    ok = gen_event:add_handler({global, ?GLOBAL_NAME}, ?MODULE, []),
    io:format("[2] Handler added using {global, ~p}~n~n", [?GLOBAL_NAME]),

    %% Send events — reference manager by {global, Name}
    io:format("--- Sending events via {global, Name} ---~n"),
    gen_event:notify({global, ?GLOBAL_NAME}, {alert, "server overload"}),
    gen_event:notify({global, ?GLOBAL_NAME}, {alert, "memory threshold"}),
    gen_event:notify({global, ?GLOBAL_NAME}, {info, "backup completed"}),
    gen_event:notify({global, ?GLOBAL_NAME}, {error, "node disconnected"}),
    io:format("  Sent 4 events using gen_event:notify({global, ~p}, Event)~n~n",
              [?GLOBAL_NAME]),

    %% Sync notify — also works with {global, Name}
    io:format("--- Sync notify via {global, Name} ---~n"),
    gen_event:sync_notify({global, ?GLOBAL_NAME}, {critical, "disk failure"}),
    io:format("  sync_notify returned (handler processed event synchronously)~n~n"),

    %% Query handler state — reference manager by {global, Name}
    io:format("--- Querying handler via {global, Name} ---~n"),
    Count = gen_event:call({global, ?GLOBAL_NAME}, ?MODULE, get_count),
    io:format("  gen_event:call({global, ~p}, ~p, get_count) = ~p~n",
              [?GLOBAL_NAME, ?MODULE, Count]),
    Events = gen_event:call({global, ?GLOBAL_NAME}, ?MODULE, get_events),
    io:format("  gen_event:call({global, ~p}, ~p, get_events):~n", [?GLOBAL_NAME, ?MODULE]),
    lists:foreach(fun({Type, Msg}) ->
        io:format("    {~p, ~p}~n", [Type, Msg])
    end, Events),
    io:format("~n"),

    %% Also works with Pid directly
    io:format("--- Also works with Pid ---~n"),
    Count2 = gen_event:call(Pid, ?MODULE, get_count),
    io:format("  gen_event:call(Pid, ~p, get_count) = ~p~n~n", [?MODULE, Count2]),

    %% List handlers
    Handlers = gen_event:which_handlers({global, ?GLOBAL_NAME}),
    io:format("[3] which_handlers({global, ~p}) = ~p~n~n", [?GLOBAL_NAME, Handlers]),

    %% Stop — reference by {global, Name}
    gen_event:stop({global, ?GLOBAL_NAME}),
    io:format("[4] Event manager stopped via gen_event:stop({global, ~p})~n",
              [?GLOBAL_NAME]),
    io:format("    global:whereis_name(~p) = ~p~n~n",
              [?GLOBAL_NAME, global:whereis_name(?GLOBAL_NAME)]),

    io:format("=== Global Name Demo Complete ===~n~n"),
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
