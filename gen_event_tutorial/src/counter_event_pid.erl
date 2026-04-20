%%%-------------------------------------------------------------------
%%% @doc pid_event - Demonstrates gen_event with anonymous start
%%%      (Pid only, no name registration).
%%%
%%% emgr_ref() type:
%%%   atom() | {atom(), node()} | {global, term()} | {via, atom(), term()} | pid()
%%%
%%% This module demonstrates using a PID as the emgr_ref() to locate
%%% the event manager. This is the simplest form — no name registration.
%%%
%%% After starting without a name:
%%%   {ok, Pid} = gen_event:start_link()
%%%   gen_event:notify(Pid, Event)
%%%   gen_event:call(Pid, Handler, Request)
%%%   gen_event:stop(Pid)
%%%
%%% The Pid is only valid on the local node. If the process dies,
%%% the Pid becomes invalid. There is no way to look up the manager
%%% by name — you must keep track of the Pid yourself.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(counter_event_pid).
-behaviour(gen_event).

%% API
-export([demo/0]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

%%====================================================================
%% API
%%====================================================================

demo() ->
    io:format("~n=== gen_event emgr_ref Demo: Pid (Anonymous, No Name) ===~n~n"),

    %% Start event manager without any name registration
    %% The only way to reference it is via the returned Pid
    {ok, Pid} = gen_event:start_link(),
    io:format("[1] Event manager started (anonymous)~n"),
    io:format("    Pid: ~p~n", [Pid]),
    io:format("    No registered name — must use Pid directly~n~n"),

    %% Add handler — reference manager by Pid
    ok = gen_event:add_handler(Pid, ?MODULE, []),
    io:format("[2] Handler added using Pid: ~p~n~n", [Pid]),

    %% Send events — reference manager by Pid
    io:format("--- Sending events via Pid ---~n"),
    gen_event:notify(Pid, {login, "alice"}),
    gen_event:notify(Pid, {login, "bob"}),
    gen_event:notify(Pid, {logout, "alice"}),
    gen_event:notify(Pid, {error, "invalid token"}),
    gen_event:notify(Pid, {login, "charlie"}),
    io:format("  Sent 5 events using gen_event:notify(Pid, Event)~n~n"),

    %% Sync notify — also works with Pid
    io:format("--- Sync notify via Pid ---~n"),
    gen_event:sync_notify(Pid, {critical, "system shutdown"}),
    io:format("  sync_notify returned (handler processed event synchronously)~n~n"),

    %% Query handler state — reference manager by Pid
    io:format("--- Querying handler via Pid ---~n"),
    Count = gen_event:call(Pid, ?MODULE, get_count),
    io:format("  gen_event:call(Pid, ~p, get_count) = ~p~n", [?MODULE, Count]),
    Events = gen_event:call(Pid, ?MODULE, get_events),
    io:format("  gen_event:call(Pid, ~p, get_events):~n", [?MODULE]),
    lists:foreach(fun({Type, Msg}) ->
        io:format("    {~p, ~p}~n", [Type, Msg])
    end, Events),
    io:format("~n"),

    %% Demonstrate that Pid is just a process identifier
    io:format("--- Pid is a regular process ---~n"),
    io:format("  is_pid(~p) = ~p~n", [Pid, is_pid(Pid)]),
    io:format("  is_process_alive(Pid) = ~p~n", [is_process_alive(Pid)]),
    io:format("  process_info(Pid, registered_name) = ~p~n",
              [process_info(Pid, registered_name)]),
    io:format("~n"),

    %% List handlers
    Handlers = gen_event:which_handlers(Pid),
    io:format("[3] which_handlers(Pid) = ~p~n~n", [Handlers]),

    %% Delete handler explicitly (alternative to stop)
    io:format("--- Delete handler before stopping ---~n"),
    gen_event:delete_handler(Pid, ?MODULE, normal),
    io:format("  Handler deleted~n"),
    HandlersAfter = gen_event:which_handlers(Pid),
    io:format("  which_handlers(Pid) = ~p (empty)~n~n", [HandlersAfter]),

    %% Stop — reference by Pid
    gen_event:stop(Pid),
    io:format("[4] Event manager stopped via gen_event:stop(Pid)~n"),
    io:format("    is_process_alive(Pid) = ~p~n~n", [is_process_alive(Pid)]),

    io:format("=== Pid Demo Complete ===~n~n"),
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
