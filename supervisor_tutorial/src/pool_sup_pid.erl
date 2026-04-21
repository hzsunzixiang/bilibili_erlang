%%%-------------------------------------------------------------------
%%% @doc pool_sup_pid - A simple_one_for_one supervisor (nameless, Pid only).
%%%
%%% Demonstrates supervisor:start_link(Module, Args) -> {ok, Pid}.
%%% The supervisor is NOT registered with any name service.
%%% All subsequent operations use the returned Pid as SupRef.
%%%
%%% From the documentation:
%%%   start_link(Module, Args)
%%%   -spec start_link(Module, Args) -> startlink_ret()
%%%         when Module :: module(), Args :: term().
%%%   Creates a nameless supervisor process as part of a supervision tree.
%%%
%%% Architecture:
%%%
%%%   pool_sup_pid (supervisor, simple_one_for_one, nameless)
%%%       |
%%%       +-- pool_worker:worker_1 (gen_server, transient)
%%%       +-- pool_worker:worker_2 (gen_server, transient)
%%%       +-- ...
%%%
%%% Key concepts demonstrated:
%%%   - Nameless supervisor (no name registration)
%%%   - SupRef = pid() for all supervisor:* calls
%%%   - simple_one_for_one with dynamic children
%%%   - transient restart type
%%%
%%% Usage:
%%%   1> {ok, Pid} = pool_sup_pid:start_link().
%%%   {ok,<0.80.0>}
%%%   2> pool_sup_pid:add_worker(Pid, alpha).
%%%   {ok,<0.82.0>}
%%%   3> pool_worker:increment(alpha).
%%%   1
%%%   4> pool_sup_pid:remove_worker(Pid, alpha).
%%%   ok
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(pool_sup_pid).
-behaviour(supervisor).

%% Client API
-export([start_link/0, add_worker/2, remove_worker/2, stop/1]).

%% supervisor callback
-export([init/1]).

%% Demo
-export([demo/0]).

%%% ============================================================
%%% Client API
%%% ============================================================

%% @doc Start a nameless pool supervisor.
%% Returns {ok, Pid}. The Pid must be kept and passed to all
%% subsequent supervisor operations (SupRef = Pid).
%%
%% Equivalent to supervisor:start_link(?MODULE, []).
%% The supervisor is NOT registered with any name service.
-spec start_link() -> {ok, pid()} | ignore | {error, term()}.
start_link() ->
    supervisor:start_link(?MODULE, []).

%% @doc Dynamically add a worker with the given Name.
%% SupRef is the Pid returned by start_link/0.
-spec add_worker(pid(), atom()) -> {ok, pid()} | {error, term()}.
add_worker(SupPid, Name) ->
    supervisor:start_child(SupPid, [Name]).

%% @doc Remove (terminate) a worker by its registered Name.
%% SupRef is the Pid returned by start_link/0.
-spec remove_worker(pid(), atom()) -> ok | {error, term()}.
remove_worker(SupPid, Name) ->
    case whereis(Name) of
        Pid when is_pid(Pid) ->
            supervisor:terminate_child(SupPid, Pid);
        undefined ->
            {error, not_found}
    end.

%% @doc Stop the nameless pool supervisor and all workers.
-spec stop(pid()) -> true.
stop(SupPid) ->
    exit(SupPid, shutdown).

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

%% @doc demo/0 - Demonstrates nameless supervisor (Pid-based SupRef).
%%
%% Shows:
%%   1. Starting nameless supervisor (returns Pid, no registration)
%%   2. All operations use Pid as SupRef
%%   3. Dynamic child management
%%   4. Crash recovery (transient)
%%   5. Graceful stop (transient: no restart on normal exit)
%%   6. Inspect and shutdown
demo() ->
    io:format("~n========================================~n"),
    io:format("  pool_sup_pid (nameless, SupRef = Pid)~n"),
    io:format("========================================~n~n"),

    %% Step 1: Start nameless supervisor
    io:format("--- Step 1: Start nameless supervisor ---~n"),
    {ok, SupPid} = start_link(),
    io:format("Supervisor started: ~p (not registered)~n", [SupPid]),
    io:format("Initial children: ~p~n~n",
              [supervisor:count_children(SupPid)]),

    %% Step 2: Dynamically add workers (using Pid as SupRef)
    io:format("--- Step 2: Add workers (SupRef = Pid) ---~n"),
    {ok, Pid1} = add_worker(SupPid, alpha),
    {ok, Pid2} = add_worker(SupPid, beta),
    {ok, Pid3} = add_worker(SupPid, gamma),
    io:format("Added alpha=~p, beta=~p, gamma=~p~n",
              [Pid1, Pid2, Pid3]),
    io:format("count_children(~p): ~p~n~n",
              [SupPid, supervisor:count_children(SupPid)]),

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
              [supervisor:count_children(SupPid)]),

    %% Step 6: Inspect children
    io:format("--- Step 6: Inspect children ---~n"),
    Children = supervisor:which_children(SupPid),
    io:format("which_children (~p children):~n", [length(Children)]),
    lists:foreach(
        fun({Id, Pid, Type, Mods}) ->
            io:format("  id=~p, pid=~p, type=~p, modules=~p~n",
                      [Id, Pid, Type, Mods])
        end, Children),
    io:format("~n"),

    %% Step 7: Remove and shutdown
    io:format("--- Step 7: Remove worker and shutdown ---~n"),
    ok = remove_worker(SupPid, beta),
    timer:sleep(100),
    io:format("beta alive? ~p~n", [is_pid(whereis(beta))]),
    stop(SupPid),
    timer:sleep(100),
    io:format("Supervisor stopped.~n~n"),

    io:format("pool_sup_pid demo completed.~n~n"),
    ok.
