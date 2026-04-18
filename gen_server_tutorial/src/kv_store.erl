%%%-------------------------------------------------------------------
%%% @doc Demonstrates gen_server with different registration methods:
%%%      1. {local, Name}  - local registration
%%%      2. {global, Name} - global registration across nodes
%%%      3. {via, Module, Name} - custom registration via module
%%%      4. No registration (use PID directly)
%%%
%%%      Also demonstrates distributed node communication with
%%%      different process IDs across nodes.
%%% @end
%%%-------------------------------------------------------------------
-module(kv_store).
-behaviour(gen_server).

%% Client API
-export([start_link/0, start_link_global/0, start_link_unnamed/0]).
-export([put/2, get/1, delete/1, get_all/0, stop/0]).
-export([put_global/2, get_global/1, get_all_global/0, stop_global/0]).
-export([put_by_pid/3, get_by_pid/2, get_all_by_pid/1, stop_by_pid/1]).
-export([demo_local/0, demo_global/0, demo_unnamed/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%====================================================================
%% Client API - Local Registration
%%====================================================================

%% @doc Start with local name registration.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Put a key-value pair (synchronous).
put(Key, Value) ->
    gen_server:call(?MODULE, {put, Key, Value}).

%% @doc Get a value by key (synchronous).
get(Key) ->
    gen_server:call(?MODULE, {get, Key}).

%% @doc Delete a key (asynchronous).
delete(Key) ->
    gen_server:cast(?MODULE, {delete, Key}).

%% @doc Get all key-value pairs.
get_all() ->
    gen_server:call(?MODULE, get_all).

%% @doc Stop the server.
stop() ->
    gen_server:call(?MODULE, stop).

%%====================================================================
%% Client API - Global Registration
%%====================================================================

%% @doc Start with global name registration (visible across all connected nodes).
start_link_global() ->
    gen_server:start_link({global, kv_store_global}, ?MODULE, [], []).

%% @doc Put via global name.
put_global(Key, Value) ->
    gen_server:call({global, kv_store_global}, {put, Key, Value}).

%% @doc Get via global name.
get_global(Key) ->
    gen_server:call({global, kv_store_global}, {get, Key}).

%% @doc Get all via global name.
get_all_global() ->
    gen_server:call({global, kv_store_global}, get_all).

%% @doc Stop via global name.
stop_global() ->
    gen_server:call({global, kv_store_global}, stop).

%%====================================================================
%% Client API - Unnamed (by PID)
%%====================================================================

%% @doc Start without name registration (returns PID).
start_link_unnamed() ->
    gen_server:start_link(?MODULE, [], []).

%% @doc Put by PID.
put_by_pid(Pid, Key, Value) ->
    gen_server:call(Pid, {put, Key, Value}).

%% @doc Get by PID.
get_by_pid(Pid, Key) ->
    gen_server:call(Pid, {get, Key}).

%% @doc Get all by PID.
get_all_by_pid(Pid) ->
    gen_server:call(Pid, get_all).

%% @doc Stop by PID.
stop_by_pid(Pid) ->
    gen_server:call(Pid, stop).

%%====================================================================
%% gen_server Callbacks
%%====================================================================

init(_Args) ->
    io:format("[kv_store] Initialized on node ~p, PID=~p~n",
              [node(), self()]),
    {ok, #{}}.

handle_call({put, Key, Value}, _From, State) ->
    NewState = maps:put(Key, Value, State),
    {reply, ok, NewState};

handle_call({get, Key}, _From, State) ->
    Reply = maps:get(Key, State, undefined),
    {reply, Reply, State};

handle_call(get_all, _From, State) ->
    {reply, State, State};

handle_call(stop, _From, State) ->
    {stop, normal, ok, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast({delete, Key}, State) ->
    NewState = maps:remove(Key, State),
    {noreply, NewState};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, State) ->
    io:format("[kv_store] Terminating on node ~p. Reason=~p, Data=~p~n",
              [node(), Reason, State]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Demo - Local Registration
%%====================================================================

demo_local() ->
    io:format("~n=== KV Store - Local Registration Demo ===~n~n"),
    {ok, Pid} = kv_store:start_link(),
    io:format("Server PID: ~p~n", [Pid]),
    io:format("Node: ~p~n~n", [node()]),

    ok = kv_store:put(name, "Erlang"),
    ok = kv_store:put(version, "OTP 26"),
    ok = kv_store:put(type, "functional"),

    io:format("Get 'name': ~p~n", [kv_store:get(name)]),
    io:format("Get 'version': ~p~n", [kv_store:get(version)]),
    io:format("Get 'missing': ~p~n", [kv_store:get(missing)]),
    io:format("All data: ~p~n~n", [kv_store:get_all()]),

    kv_store:delete(type),
    timer:sleep(100),
    io:format("After delete 'type': ~p~n", [kv_store:get_all()]),

    kv_store:stop(),
    timer:sleep(100),
    io:format("~n=== Demo Complete ===~n"),
    ok.

%%====================================================================
%% Demo - Global Registration
%%====================================================================

demo_global() ->
    io:format("~n=== KV Store - Global Registration Demo ===~n~n"),
    {ok, Pid} = kv_store:start_link_global(),
    io:format("Server PID: ~p~n", [Pid]),
    io:format("Node: ~p~n", [node()]),
    io:format("Global name: ~p~n~n", [global:whereis_name(kv_store_global)]),

    ok = kv_store:put_global(language, "Erlang"),
    ok = kv_store:put_global(paradigm, "concurrent"),
    io:format("Get 'language': ~p~n", [kv_store:get_global(language)]),
    io:format("All data: ~p~n", [kv_store:get_all_global()]),

    kv_store:stop_global(),
    timer:sleep(100),
    io:format("~n=== Demo Complete ===~n"),
    ok.

%%====================================================================
%% Demo - Unnamed (by PID)
%%====================================================================

demo_unnamed() ->
    io:format("~n=== KV Store - Unnamed (PID) Demo ===~n~n"),

    %% Start multiple unnamed instances
    {ok, Pid1} = kv_store:start_link_unnamed(),
    {ok, Pid2} = kv_store:start_link_unnamed(),
    io:format("Instance 1 PID: ~p~n", [Pid1]),
    io:format("Instance 2 PID: ~p~n~n", [Pid2]),

    %% They are independent!
    ok = kv_store:put_by_pid(Pid1, color, red),
    ok = kv_store:put_by_pid(Pid2, color, blue),

    io:format("Instance 1 color: ~p~n", [kv_store:get_by_pid(Pid1, color)]),
    io:format("Instance 2 color: ~p~n", [kv_store:get_by_pid(Pid2, color)]),

    kv_store:stop_by_pid(Pid1),
    kv_store:stop_by_pid(Pid2),
    timer:sleep(100),
    io:format("~n=== Demo Complete ===~n"),
    ok.
