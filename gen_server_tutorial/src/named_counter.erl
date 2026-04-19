%%%-------------------------------------------------------------------
%%% @doc named_counter - Demonstrates gen_server startup with Pid and
%%%      registered name, matching the gen_server_startup.tex diagram.
%%%
%%% This module shows the TWO ways to start a gen_server:
%%%
%%%   1. Anonymous (returns Pid only):
%%%      {ok, Pid} = gen_server:start_link(?MODULE, Args, [])
%%%
%%%   2. Named (returns Pid AND registers a name):
%%%      {ok, Pid} = gen_server:start_link({local, counter}, ?MODULE, Args, [])
%%%
%%% After startup, the server can be addressed by either:
%%%   - gen_server:call(Pid, Request)       %% using Pid
%%%   - gen_server:call(counter, Request)   %% using registered name
%%%
%%% Architecture Mapping (gen_server_startup.tex):
%%%
%%%   Caller Process              New Server Process
%%%   +-----------+               +------------------+
%%%   | start_link|  ----①---->   | proc_lib:start   |
%%%   |  (blocks) |               | init_it          |
%%%   |           |               | Mod:init(Args)   |
%%%   |           |  <---②----   | init_ack({ok,Pid})|
%%%   | {ok, Pid} |               | register(Name,Pid)|
%%%   +-----------+               | enter loop       |
%%%                               +------------------+
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(named_counter).
-behaviour(gen_server).

%% ============================================================
%% Client API — Two startup modes
%% ============================================================
-export([
    %% Anonymous start (returns Pid)
    start_link/0, start_link/1,
    %% Named start (registers atom name, returns Pid)
    start_link_named/0, start_link_named/1, start_link_named/2,
    %% Operations (accept both Pid and Name)
    increment/1, decrement/1, get_count/1, get_info/1,
    reset/1, stop/1,
    %% Demo
    demo/0
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

-define(DEFAULT_NAME, counter).

%%% ============================================================
%%% Client API
%%% ============================================================

%% ---- Mode 1: Anonymous start (Pid only) ----
%% Diagram Arrow ①: start_link(?MODULE, Args)
%% Diagram Arrow ②: returns {ok, Pid}

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    start_link(0).

-spec start_link(InitCount :: integer()) -> {ok, pid()} | {error, term()}.
start_link(InitCount) ->
    %% Anonymous: no name registration
    %% The caller gets {ok, Pid} and must keep Pid to communicate.
    gen_server:start_link(?MODULE, InitCount, []).

%% ---- Mode 2: Named start (Pid + registered name) ----
%% Diagram Arrow ①: start_link({local, Name}, ?MODULE, Args, [])
%% Diagram Arrow ②: returns {ok, Pid} AND registers Name
%% Diagram Arrow ③: register(Name, Pid)

-spec start_link_named() -> {ok, pid()} | {error, term()}.
start_link_named() ->
    start_link_named(?DEFAULT_NAME, 0).

-spec start_link_named(InitCount :: integer()) -> {ok, pid()} | {error, term()}.
start_link_named(InitCount) ->
    start_link_named(?DEFAULT_NAME, InitCount).

-spec start_link_named(Name :: atom(), InitCount :: integer()) ->
    {ok, pid()} | {error, term()}.
start_link_named(Name, InitCount) ->
    %% Named: registers the process locally under `Name`.
    %% After this, gen_server:call(Name, Req) works without Pid.
    gen_server:start_link({local, Name}, ?MODULE, InitCount, []).

%% ---- Operations (ServerRef = Pid | Name) ----
%% Diagram Arrow ④⑤: runtime communication via Pid or Name

-spec increment(ServerRef :: pid() | atom()) -> integer().
increment(ServerRef) ->
    gen_server:call(ServerRef, increment).

-spec decrement(ServerRef :: pid() | atom()) -> integer().
decrement(ServerRef) ->
    gen_server:call(ServerRef, decrement).

-spec get_count(ServerRef :: pid() | atom()) -> integer().
get_count(ServerRef) ->
    gen_server:call(ServerRef, get_count).

-spec get_info(ServerRef :: pid() | atom()) -> map().
get_info(ServerRef) ->
    gen_server:call(ServerRef, get_info).

-spec reset(ServerRef :: pid() | atom()) -> ok.
reset(ServerRef) ->
    gen_server:cast(ServerRef, reset).

-spec stop(ServerRef :: pid() | atom()) -> ok.
stop(ServerRef) ->
    gen_server:stop(ServerRef).

%%% ============================================================
%%% gen_server callbacks
%%% ============================================================

%% @doc init/1 — Called in the NEW process during startup.
%%
%% This is the critical moment shown in the diagram:
%%   proc_lib:start_link → init_it → Mod:init(Args)
%%
%% After init/1 returns {ok, State}, gen_server calls
%% proc_lib:init_ack({ok, self()}) to unblock the caller.
%%
%% The caller then receives {ok, Pid} — Arrow ② in the diagram.
init(InitCount) when is_integer(InitCount) ->
    %% trap_exit so we get EXIT messages instead of dying
    process_flag(trap_exit, true),

    %% self() here is the NEW process's Pid — this is what gets
    %% returned to the caller as {ok, Pid}
    Pid = self(),
    RegisteredName = case process_info(Pid, registered_name) of
        {registered_name, Name} -> Name;
        []                      -> undefined
    end,

    io:format("[named_counter] init: count=~p, pid=~p, name=~p~n",
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
    %% Return full process identity info — demonstrates that
    %% the server knows its own Pid and registered name
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
    io:format("[named_counter] reset to 0~n"),
    {noreply, State#{count := 0}};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% @doc handle_info/2 — Other messages.
handle_info(Info, State) ->
    io:format("[named_counter] unexpected info: ~p~n", [Info]),
    {noreply, State}.

%% @doc terminate/2 — Cleanup.
terminate(Reason, #{count := C, pid := Pid, registered_name := Name}) ->
    io:format("[named_counter] terminating: reason=~p, pid=~p, "
              "name=~p, final_count=~p~n",
              [Reason, Pid, Name, C]),
    ok.

%%% ============================================================
%%% Demo
%%% ============================================================

%% @doc demo/0 — Demonstrates both startup modes.
demo() ->
    io:format("~n=== Mode 1: Anonymous start (Pid only) ===~n~n"),
    {ok, Pid1} = start_link(10),
    io:format("Returned: {ok, ~p}~n", [Pid1]),
    io:format("increment: ~p~n", [increment(Pid1)]),
    io:format("get_count: ~p~n", [get_count(Pid1)]),
    io:format("get_info:  ~p~n", [get_info(Pid1)]),
    gen_server:stop(Pid1),
    timer:sleep(50),

    io:format("~n=== Mode 2: Named start (Pid + registered name) ===~n~n"),
    {ok, Pid2} = start_link_named(my_counter, 42),
    io:format("Returned: {ok, ~p}~n", [Pid2]),
    io:format("Call by Pid:  ~p~n", [get_count(Pid2)]),
    io:format("Call by Name: ~p~n", [get_count(my_counter)]),
    io:format("increment by Name: ~p~n", [increment(my_counter)]),
    io:format("get_info by Name:  ~p~n", [get_info(my_counter)]),
    gen_server:stop(my_counter),
    timer:sleep(50),

    io:format("~n=== Mode 3: Default name (counter) ===~n~n"),
    {ok, Pid3} = start_link_named(5),
    io:format("Returned: {ok, ~p}~n", [Pid3]),
    io:format("Call by default name 'counter': ~p~n", [get_count(counter)]),
    gen_server:stop(counter),
    timer:sleep(50),

    io:format("~nAll startup demos completed.~n"),
    ok.
