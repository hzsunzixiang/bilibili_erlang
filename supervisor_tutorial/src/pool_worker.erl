%%%-------------------------------------------------------------------
%%% @doc pool_worker - A dynamic gen_server worker for pool_sup demo.
%%%
%%% Each pool_worker is identified by a unique Name (atom) and
%%% maintains its own independent counter. Workers are created
%%% dynamically by pool_sup using simple_one_for_one strategy.
%%%
%%% Architecture:
%%%
%%%   pool_sup (supervisor, simple_one_for_one)
%%%       |
%%%       +-- pool_worker:worker_1 (gen_server, transient)
%%%       +-- pool_worker:worker_2 (gen_server, transient)
%%%       +-- pool_worker:worker_N (gen_server, transient)
%%%       +-- ...
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(pool_worker).
-behaviour(gen_server).

%% Client API
-export([start_link/1, increment/1, get_count/1, crash/1, stop/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

%%% ============================================================
%%% Client API
%%% ============================================================

%% @doc Start a pool worker registered with the given Name.
%% Called by supervisor via start_child(pool_sup, [Name]).
-spec start_link(atom()) -> {ok, pid()} | {error, term()}.
start_link(Name) when is_atom(Name) ->
    gen_server:start_link({local, Name}, ?MODULE, Name, []).

%% @doc Increment the counter of the named worker.
-spec increment(atom()) -> integer().
increment(Name) ->
    gen_server:call(Name, increment).

%% @doc Get the current counter value of the named worker.
-spec get_count(atom()) -> integer().
get_count(Name) ->
    gen_server:call(Name, get_count).

%% @doc Deliberately crash the named worker.
-spec crash(atom()) -> ok.
crash(Name) ->
    gen_server:cast(Name, crash).

%% @doc Gracefully stop the named worker.
-spec stop(atom()) -> ok.
stop(Name) ->
    gen_server:stop(Name).

%%% ============================================================
%%% gen_server callbacks
%%% ============================================================

init(Name) ->
    process_flag(trap_exit, true),
    io:format("[pool_worker:~p] started, pid=~p~n", [Name, self()]),
    {ok, #{name => Name, count => 0}}.

handle_call(increment, _From, #{count := C} = State) ->
    New = C + 1,
    {reply, New, State#{count := New}};

handle_call(get_count, _From, #{count := C} = State) ->
    {reply, C, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(crash, #{name := Name}) ->
    io:format("[pool_worker:~p] deliberate crash!~n", [Name]),
    error(deliberate_crash);

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, #{name := Name, count := C}) ->
    io:format("[pool_worker:~p] terminating: reason=~p, "
              "final_count=~p, pid=~p~n",
              [Name, Reason, C, self()]),
    ok.
