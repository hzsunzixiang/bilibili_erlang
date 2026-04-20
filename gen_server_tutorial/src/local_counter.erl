%%%-------------------------------------------------------------------
%%% @doc local_counter - Demonstrates gen_server with local name
%%%      registration ({local, Name}).
%%%
%%% This module shows TWO ways to identify a gen_server locally:
%%%
%%%   1. Anonymous (returns Pid only):
%%%      {ok, Pid} = gen_server:start_link(?MODULE, Args, [])
%%%      gen_server:call(Pid, Request)
%%%
%%%   2. Local name (registers within the local node):
%%%      {ok, Pid} = gen_server:start_link({local, Name}, ?MODULE, Args, [])
%%%      gen_server:call(Name, Request)
%%%
%%% From the gen_server:call/3 documentation:
%%%
%%%   call(ServerRef, Request, Timeout) -> Reply
%%%   ServerRef = Name | {Name,Node} | {global,GlobalName}
%%%             | {via,Module,ViaName} | pid()
%%%
%%% The local name is scoped to the current Erlang node only.
%%% Each node in a cluster can register the same name independently.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(local_counter).
-behaviour(gen_server).

%% ============================================================
%% Client API
%% ============================================================
-export([
    %% Anonymous start (returns Pid)
    start_link/0, start_link/1,
    %% Local named start (registers atom name locally)
    start_link_local/0, start_link_local/1, start_link_local/2,
    %% Operations (accept Pid or Name)
    increment/1, decrement/1, get_count/1, get_info/1,
    reset/1, stop/1,
    %% Demo
    demo/0
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

-define(DEFAULT_NAME, counter_local).

%% Type for ServerRef accepted by all API functions
-type server_ref() :: pid() | atom().

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

%% ---- Mode 2: Local named start ({local, Name}) ----
%% After startup, the server can be called by Name directly:
%%   gen_server:call(Name, Request)
%%
%% The name is registered via erlang:register/2, which is
%% scoped to the local node only. Other nodes cannot see it.

-spec start_link_local() -> {ok, pid()} | {error, term()}.
start_link_local() ->
    start_link_local(?DEFAULT_NAME, 0).

-spec start_link_local(InitCount :: integer()) -> {ok, pid()} | {error, term()}.
start_link_local(InitCount) ->
    start_link_local(?DEFAULT_NAME, InitCount).

-spec start_link_local(Name :: atom(), InitCount :: integer()) ->
    {ok, pid()} | {error, term()}.
start_link_local(Name, InitCount) ->
    gen_server:start_link({local, Name}, ?MODULE, InitCount, []).

%% ---- Operations (ServerRef = Pid | Name) ----

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
    RegisteredName = case process_info(Pid, registered_name) of
        {registered_name, Name} -> Name;
        []                      -> undefined
    end,

    io:format("[local_counter] init: count=~p, pid=~p, local_name=~p~n",
              [InitCount, Pid, RegisteredName]),

    State = #{
        count => InitCount,
        pid => Pid,
        registered_name => RegisteredName,
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
        registered_name => maps:get(registered_name, State),
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
    io:format("[local_counter] reset to 0~n"),
    {noreply, State#{count := 0}};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% @doc handle_info/2 — Other messages.
handle_info(Info, State) ->
    io:format("[local_counter] unexpected info: ~p~n", [Info]),
    {noreply, State}.

%% @doc terminate/2 — Cleanup.
terminate(Reason, #{count := C, pid := Pid, registered_name := Name}) ->
    io:format("[local_counter] terminating: reason=~p, pid=~p, "
              "local_name=~p, final_count=~p~n",
              [Reason, Pid, Name, C]),
    ok.

%%% ============================================================
%%% Demo
%%% ============================================================

%% @doc demo/0 — Demonstrates anonymous and local named startup modes.
demo() ->
    io:format("~n=== Mode 1: Anonymous start (Pid only) ===~n~n"),
    {ok, Pid1} = start_link(10),
    io:format("Returned: {ok, ~p}~n", [Pid1]),
    io:format("increment(Pid): ~p~n", [increment(Pid1)]),
    io:format("get_count(Pid): ~p~n", [get_count(Pid1)]),
    io:format("get_info(Pid):  ~p~n", [get_info(Pid1)]),
    gen_server:stop(Pid1),
    timer:sleep(50),

    io:format("~n=== Mode 2: Local named start ({local, Name}) ===~n~n"),
    {ok, Pid2} = start_link_local(my_counter, 42),
    io:format("Returned: {ok, ~p}~n", [Pid2]),
    io:format("get_count(Pid):  ~p~n", [get_count(Pid2)]),
    io:format("get_count(Name): ~p~n", [get_count(my_counter)]),
    io:format("increment(Name): ~p~n", [increment(my_counter)]),
    io:format("get_info(Name):  ~p~n", [get_info(my_counter)]),
    gen_server:stop(my_counter),
    timer:sleep(50),

    io:format("~nLocal counter demos completed.~n"),
    ok.
