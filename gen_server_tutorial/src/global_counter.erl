%%%-------------------------------------------------------------------
%%% @doc global_counter - Demonstrates gen_server with global name
%%%      registration ({global, GlobalName}).
%%%
%%% This module shows TWO ways to identify a gen_server with global scope:
%%%
%%%   1. Anonymous (returns Pid only):
%%%      {ok, Pid} = gen_server:start_link(?MODULE, Args, [])
%%%      gen_server:call(Pid, Request)
%%%
%%%   2. Global name (registers across all connected nodes):
%%%      {ok, Pid} = gen_server:start_link({global, GName}, ?MODULE, Args, [])
%%%      gen_server:call({global, GName}, Request)
%%%
%%% From the gen_server:call/3 documentation:
%%%
%%%   call(ServerRef, Request, Timeout) -> Reply
%%%   ServerRef = Name | {Name,Node} | {global,GlobalName}
%%%             | {via,Module,ViaName} | pid()
%%%
%%% The global name is registered via the `global` module, which
%%% maintains a cluster-wide name registry across all connected nodes.
%%% Only ONE process in the entire cluster can hold a given global name.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(global_counter).
-behaviour(gen_server).

%% ============================================================
%% Client API
%% ============================================================
-export([
    %% Anonymous start (returns Pid)
    start_link/0, start_link/1,
    %% Global named start (registers name globally across nodes)
    start_link_global/0, start_link_global/1, start_link_global/2,
    %% Operations (accept Pid or {global, Name})
    increment/1, decrement/1, get_count/1, get_info/1,
    reset/1, stop/1,
    %% Demo
    demo/0
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

-define(DEFAULT_NAME, counter_global).

%% Type for ServerRef accepted by all API functions
-type server_ref() :: pid() | {global, term()}.

%%% ============================================================
%%% Client API
%%% ============================================================

%% ---- Mode 1: Anonymous start (Pid only) ----

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    start_link(0).

-spec start_link(InitCount :: integer()) -> {ok, pid()} | {error, term()}.
start_link(InitCount) ->
    gen_server:start_link(?MODULE, InitCount, []).

%% ---- Mode 2: Global named start ({global, GlobalName}) ----
%% After startup, the server can be called from ANY connected node:
%%   gen_server:call({global, GlobalName}, Request)
%%
%% The global name is registered via the `global` module, which
%% maintains a cluster-wide name registry across all connected nodes.
%% Only ONE process in the entire cluster can hold a given global name.

-spec start_link_global() -> {ok, pid()} | {error, term()}.
start_link_global() ->
    start_link_global(?DEFAULT_NAME, 0).

-spec start_link_global(InitCount :: integer()) -> {ok, pid()} | {error, term()}.
start_link_global(InitCount) ->
    start_link_global(?DEFAULT_NAME, InitCount).

-spec start_link_global(GlobalName :: term(), InitCount :: integer()) ->
    {ok, pid()} | {error, term()}.
start_link_global(GlobalName, InitCount) ->
    gen_server:start_link({global, GlobalName}, ?MODULE, InitCount, []).

%% ---- Operations (ServerRef = Pid | {global, Name}) ----

-spec increment(server_ref()) -> integer().
increment(ServerRef) ->
    gen_server:call(ServerRef, increment).

-spec decrement(server_ref()) -> integer().
decrement(ServerRef) ->
    gen_server:call(ServerRef, decrement).

-spec get_count(server_ref()) -> integer().
get_count(ServerRef) ->
    gen_server:call(ServerRef, get_count).

-spec get_info(server_ref()) -> map().
get_info(ServerRef) ->
    gen_server:call(ServerRef, get_info).

-spec reset(server_ref()) -> ok.
reset(ServerRef) ->
    gen_server:cast(ServerRef, reset).

-spec stop(server_ref()) -> ok.
stop(ServerRef) ->
    gen_server:stop(ServerRef).

%%% ============================================================
%%% gen_server callbacks
%%% ============================================================

%% @doc init/1 — Called in the NEW process during startup.
init(InitCount) when is_integer(InitCount) ->
    process_flag(trap_exit, true),

    Pid = self(),

    %% Check if globally registered
    GlobalName = case global:registered_names() of
        Names ->
            case lists:filter(fun(N) -> global:whereis_name(N) =:= Pid end, Names) of
                [GN | _] -> GN;
                []        -> undefined
            end
    end,

    io:format("[global_counter] init: count=~p, pid=~p, global_name=~p~n",
              [InitCount, Pid, GlobalName]),

    State = #{
        count => InitCount,
        pid => Pid,
        global_name => GlobalName,
        started_at => erlang:system_time(millisecond)
    },
    {ok, State}.

%% @doc handle_call/3 — Synchronous request handling.
handle_call(increment, _From, #{count := C} = State) ->
    NewCount = C + 1,
    {reply, NewCount, State#{count := NewCount}};

handle_call(decrement, _From, #{count := C} = State) ->
    NewCount = C - 1,
    {reply, NewCount, State#{count := NewCount}};

handle_call(get_count, _From, #{count := C} = State) ->
    {reply, C, State};

handle_call(get_info, _From, State) ->
    Info = #{
        pid => maps:get(pid, State),
        global_name => maps:get(global_name, State, undefined),
        count => maps:get(count, State),
        started_at => maps:get(started_at, State),
        uptime_ms => erlang:system_time(millisecond) -
                     maps:get(started_at, State)
    },
    {reply, Info, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

%% @doc handle_cast/2 — Asynchronous message handling.
handle_cast(reset, State) ->
    io:format("[global_counter] reset to 0~n"),
    {noreply, State#{count := 0}};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% @doc handle_info/2 — Other messages.
handle_info(Info, State) ->
    io:format("[global_counter] unexpected info: ~p~n", [Info]),
    {noreply, State}.

%% @doc terminate/2 — Cleanup.
terminate(Reason, #{count := C, pid := Pid} = State) ->
    GlobalName = maps:get(global_name, State, undefined),
    io:format("[global_counter] terminating: reason=~p, pid=~p, "
              "global_name=~p, final_count=~p~n",
              [Reason, Pid, GlobalName, C]),
    ok.

%%% ============================================================
%%% Demo
%%% ============================================================

%% @doc demo/0 — Demonstrates anonymous and global named startup modes.
demo() ->
    io:format("~n=== Mode 1: Anonymous start (Pid only) ===~n~n"),
    {ok, Pid1} = start_link(10),
    io:format("Returned: {ok, ~p}~n", [Pid1]),
    io:format("increment(Pid): ~p~n", [increment(Pid1)]),
    io:format("get_count(Pid): ~p~n", [get_count(Pid1)]),
    io:format("get_info(Pid):  ~p~n", [get_info(Pid1)]),
    gen_server:stop(Pid1),
    timer:sleep(50),

    io:format("~n=== Mode 2: Global named start ({global, Name}) ===~n~n"),
    {ok, Pid2} = start_link_global(my_global_counter, 100),
    io:format("Returned: {ok, ~p}~n", [Pid2]),
    io:format("get_count(Pid):            ~p~n", [get_count(Pid2)]),
    io:format("get_count({global, Name}): ~p~n", [get_count({global, my_global_counter})]),
    io:format("increment({global, Name}): ~p~n", [increment({global, my_global_counter})]),
    io:format("decrement({global, Name}): ~p~n", [decrement({global, my_global_counter})]),
    io:format("get_info({global, Name}):  ~p~n", [get_info({global, my_global_counter})]),
    gen_server:stop({global, my_global_counter}),
    timer:sleep(50),

    io:format("~nGlobal counter demos completed.~n"),
    ok.
