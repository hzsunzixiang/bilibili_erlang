%%%-------------------------------------------------------------------
%%% @doc pool_sup_local - A simple_one_for_one supervisor with local
%%%      name registration ({local, Name}).
%%%
%%% Demonstrates supervisor:start_link({local, Name}, Module, Args).
%%% The supervisor is registered locally on the current node.
%%% Subsequent operations can use the registered Name as SupRef.
%%%
%%% From the documentation:
%%%   sup_name() = {local, Name :: atom()}
%%%              | {global, Name :: term()}
%%%              | {via, Module :: module(), Name :: any()}
%%%
%%%   start_link(SupName, Module, Args) -> startlink_ret()
%%%   Creates a supervisor as part of a supervision tree, registered
%%%   with the given SupName.
%%%
%%% Architecture:
%%%
%%%   pool_sup_local (supervisor, simple_one_for_one, {local, ?MODULE})
%%%       |
%%%       +-- pool_worker:worker_1 (gen_server, transient)
%%%       +-- pool_worker:worker_2 (gen_server, transient)
%%%       +-- ...
%%%
%%% Key concepts demonstrated:
%%%   - Local name registration: {local, pool_sup_local}
%%%   - SupRef = Name (atom) for all supervisor:* calls
%%%   - Name is scoped to the current Erlang node only
%%%   - simple_one_for_one with dynamic children
%%%   - transient restart type
%%%
%%% Usage:
%%%   1> pool_sup_local:start_link().
%%%   {ok,<0.80.0>}
%%%   2> pool_sup_local:add_worker(alpha).
%%%   {ok,<0.82.0>}
%%%   3> pool_worker:increment(alpha).
%%%   1
%%%   4> pool_sup_local:remove_worker(alpha).
%%%   ok
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(pool_sup_local).
-behaviour(supervisor).

%% Client API
-export([start_link/0, start_link/1, add_worker/1, remove_worker/1, stop/0]).

%% supervisor callback
-export([init/1]).

%% Demo
-export([demo/0]).

%%% ============================================================
%%% Client API
%%% ============================================================

%% @doc Start the pool supervisor, registered locally as ?MODULE.
%% Uses supervisor:start_link({local, ?MODULE}, ?MODULE, []).
%% After this, SupRef = ?MODULE (atom) can be used for all operations.
%%
%% The local name is registered via erlang:register/2, which is
%% scoped to the current node only. Other nodes cannot see it.
-spec start_link() -> {ok, pid()} | ignore | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% @doc Start with a custom local name.
-spec start_link(atom()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Name) ->
    supervisor:start_link({local, Name}, ?MODULE, []).

%% @doc Dynamically add a worker with the given Name.
%% SupRef = ?MODULE (local registered name).
-spec add_worker(atom()) -> {ok, pid()} | {error, term()}.
add_worker(Name) ->
    supervisor:start_child(?MODULE, [Name]).

%% @doc Remove (terminate) a worker by its registered Name.
%% SupRef = ?MODULE (local registered name).
-spec remove_worker(atom()) -> ok | {error, term()}.
remove_worker(Name) ->
    case whereis(Name) of
        Pid when is_pid(Pid) ->
            supervisor:terminate_child(?MODULE, Pid);
        undefined ->
            {error, not_found}
    end.

%% @doc Stop the locally registered pool supervisor and all workers.
-spec stop() -> true.
stop() ->
    exit(whereis(?MODULE), shutdown).

%%% ============================================================
%%% supervisor callback
%%% ============================================================

%% @doc Initialize with simple_one_for_one strategy.
%%
%% SupFlags:
%%   strategy  = simple_one_for_one
%%   intensity = 10
%%   period    = 60
%%
%% ChildSpec (template):
%%   start = {pool_worker, start_link, []}
%%   restart = transient (restart only on abnormal exit)
init([]) ->
    SupFlags = #{
        strategy  => simple_one_for_one,
        intensity => 10,
        period    => 60
    },
    ChildSpec = #{
        id       => pool_worker,
        start    => {pool_worker, start_link, []},
        restart  => transient,
        shutdown => 2000,
        type     => worker,
        modules  => [pool_worker]
    },
    {ok, {SupFlags, [ChildSpec]}}.

%%% ============================================================
%%% Demo
%%% ============================================================

%% @doc demo/0 - Demonstrates locally registered supervisor.
%%
%% Shows:
%%   1. Starting supervisor with {local, ?MODULE} registration
%%   2. All operations use the atom name as SupRef
%%   3. Dynamic child management
%%   4. Crash recovery (transient)
%%   5. Graceful stop (transient: no restart on normal exit)
%%   6. Inspect and shutdown
demo() ->
    io:format("~n========================================~n"),
    io:format("  pool_sup_local ({local, Name} registration)~n"),
    io:format("========================================~n~n"),

    %% Step 1: Start locally registered supervisor
    io:format("--- Step 1: Start supervisor ({local, pool_sup_local}) ---~n"),
    {ok, SupPid} = start_link(),
    io:format("Supervisor started: pid=~p, registered as '~p'~n",
              [SupPid, ?MODULE]),
    io:format("whereis(~p) = ~p~n", [?MODULE, whereis(?MODULE)]),
    io:format("Initial children: ~p~n~n",
              [supervisor:count_children(?MODULE)]),

    %% Step 2: Dynamically add workers (using Name as SupRef)
    io:format("--- Step 2: Add workers (SupRef = ~p) ---~n", [?MODULE]),
    {ok, Pid1} = add_worker(alpha),
    {ok, Pid2} = add_worker(beta),
    {ok, Pid3} = add_worker(gamma),
    io:format("Added alpha=~p, beta=~p, gamma=~p~n",
              [Pid1, Pid2, Pid3]),
    io:format("count_children(~p): ~p~n~n",
              [?MODULE, supervisor:count_children(?MODULE)]),

    %% Step 3: Use workers independently
    io:format("--- Step 3: Use workers ---~n"),
    io:format("alpha increment: ~p~n", [pool_worker:increment(alpha)]),
    io:format("alpha increment: ~p~n", [pool_worker:increment(alpha)]),
    io:format("beta  increment: ~p~n", [pool_worker:increment(beta)]),
    io:format("alpha count: ~p~n", [pool_worker:get_count(alpha)]),
    io:format("beta  count: ~p~n", [pool_worker:get_count(beta)]),
    io:format("gamma count: ~p~n~n", [pool_worker:get_count(gamma)]),

    %% Step 4: Crash recovery (transient restart)
    io:format("--- Step 4: Crash recovery ---~n"),
    OldAlpha = whereis(alpha),
    io:format("Before crash, alpha pid=~p, count=~p~n",
              [OldAlpha, pool_worker:get_count(alpha)]),
    pool_worker:crash(alpha),
    timer:sleep(100),
    NewAlpha = whereis(alpha),
    io:format("After crash,  alpha pid=~p (restarted!), count=~p~n~n",
              [NewAlpha, pool_worker:get_count(alpha)]),

    %% Step 5: Graceful stop (transient: no restart on normal exit)
    io:format("--- Step 5: Graceful stop (no restart) ---~n"),
    pool_worker:stop(gamma),
    timer:sleep(100),
    io:format("gamma alive? ~p~n", [is_pid(whereis(gamma))]),
    io:format("count_children: ~p~n~n",
              [supervisor:count_children(?MODULE)]),

    %% Step 6: Inspect children
    io:format("--- Step 6: Inspect children ---~n"),
    Children = supervisor:which_children(?MODULE),
    io:format("which_children (~p children):~n", [length(Children)]),
    lists:foreach(
        fun({Id, Pid, Type, Mods}) ->
            io:format("  id=~p, pid=~p, type=~p, modules=~p~n",
                      [Id, Pid, Type, Mods])
        end, Children),
    io:format("~n"),

    %% Step 7: Remove and shutdown
    io:format("--- Step 7: Remove worker and shutdown ---~n"),
    ok = remove_worker(beta),
    timer:sleep(100),
    io:format("beta alive? ~p~n", [is_pid(whereis(beta))]),
    stop(),
    timer:sleep(100),
    io:format("Supervisor stopped. whereis(~p) = ~p~n~n",
              [?MODULE, whereis(?MODULE)]),

    io:format("pool_sup_local demo completed.~n~n"),
    ok.
