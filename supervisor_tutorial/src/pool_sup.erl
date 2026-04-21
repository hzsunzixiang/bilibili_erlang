%%%-------------------------------------------------------------------
%%% @doc pool_sup - A simple_one_for_one supervisor for dynamic workers.
%%%
%%% This module demonstrates the simple_one_for_one supervisor pattern,
%%% where all children share the same child spec template and are
%%% created dynamically at runtime via supervisor:start_child/2.
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
%%% Key concepts demonstrated:
%%%   - simple_one_for_one restart strategy
%%%   - Dynamic child creation via supervisor:start_child/2
%%%   - transient restart type (restart only on abnormal exit)
%%%   - ExtraArgs appended to template Args
%%%   - supervisor:terminate_child/2 with Pid (not Id)
%%%   - supervisor:which_children/1 and count_children/1
%%%
%%% Usage:
%%%   1> pool_sup:start_link().
%%%   {ok,<0.80.0>}
%%%   2> pool_sup:add_worker(worker_1).
%%%   {ok,<0.82.0>}
%%%   3> pool_worker:increment(worker_1).
%%%   1
%%%   4> pool_sup:remove_worker(worker_1).
%%%   ok
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(pool_sup).
-behaviour(supervisor).

%% Client API
-export([start_link/0, add_worker/1, remove_worker/1, stop/0]).

%% supervisor callback
-export([init/1]).

%% Demo
-export([demo/0]).

%%% ============================================================
%%% Client API
%%% ============================================================

%% @doc Start the pool supervisor, registered locally as ?MODULE.
-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% @doc Dynamically add a worker with the given Name.
%% The Name is appended to the template Args: apply(pool_worker, start_link, [] ++ [Name]).
-spec add_worker(atom()) -> {ok, pid()} | {error, term()}.
add_worker(Name) ->
    supervisor:start_child(?MODULE, [Name]).

%% @doc Remove (terminate) a worker by its registered Name.
%% For simple_one_for_one, we must use the Pid to terminate.
-spec remove_worker(atom()) -> ok | {error, term()}.
remove_worker(Name) ->
    case whereis(Name) of
        Pid when is_pid(Pid) ->
            supervisor:terminate_child(?MODULE, Pid);
        undefined ->
            {error, not_found}
    end.

%% @doc Stop the pool supervisor and all workers.
-spec stop() -> true.
stop() ->
    exit(whereis(?MODULE), shutdown).

%%% ============================================================
%%% supervisor callback
%%% ============================================================

%% @doc Initialize with simple_one_for_one strategy.
%%
%% SupFlags:
%%   strategy  = simple_one_for_one -- all children use same template
%%   intensity = 10                 -- max 10 restarts
%%   period    = 60                 -- within 60 seconds
%%
%% ChildSpec (template):
%%   id       = pool_worker         -- same id for all (unused)
%%   start    = {pool_worker, start_link, []}
%%   restart  = transient           -- restart only on abnormal exit
%%   shutdown = 2000                -- 2s graceful shutdown
%%   type     = worker
%%
%% When add_worker(Name) calls supervisor:start_child(pool_sup, [Name]),
%% the actual call becomes: pool_worker:start_link(Name)
%% because ExtraArgs=[Name] is appended to Args=[].
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

%% @doc demo/0 - Demonstrates supervisor with simple_one_for_one strategy.
%%
%% Shows:
%%   1. Starting the pool supervisor (no children initially)
%%   2. Dynamically adding workers
%%   3. Using workers independently
%%   4. Crash recovery (transient: restart on abnormal exit)
%%   5. Graceful stop (transient: no restart on normal exit)
%%   6. Inspecting children
%%   7. Removing workers
%%   8. Shutdown
demo() ->
    io:format("~n========================================~n"),
    io:format("  Example 2: pool_sup (simple_one_for_one)~n"),
    io:format("========================================~n~n"),

    %% Step 1: Start supervisor
    io:format("--- Step 1: Start pool supervisor ---~n"),
    {ok, SupPid} = start_link(),
    io:format("Pool supervisor started: ~p~n", [SupPid]),
    io:format("Initial children: ~p~n~n",
              [supervisor:count_children(?MODULE)]),

    %% Step 2: Dynamically add workers
    io:format("--- Step 2: Add workers dynamically ---~n"),
    {ok, Pid1} = add_worker(alpha),
    {ok, Pid2} = add_worker(beta),
    {ok, Pid3} = add_worker(gamma),
    io:format("Added alpha=~p, beta=~p, gamma=~p~n",
              [Pid1, Pid2, Pid3]),
    io:format("count_children: ~p~n~n",
              [supervisor:count_children(?MODULE)]),

    %% Step 3: Use workers independently
    io:format("--- Step 3: Use workers independently ---~n"),
    io:format("alpha increment: ~p~n", [pool_worker:increment(alpha)]),
    io:format("alpha increment: ~p~n", [pool_worker:increment(alpha)]),
    io:format("beta  increment: ~p~n", [pool_worker:increment(beta)]),
    io:format("alpha count: ~p~n", [pool_worker:get_count(alpha)]),
    io:format("beta  count: ~p~n", [pool_worker:get_count(beta)]),
    io:format("gamma count: ~p~n~n", [pool_worker:get_count(gamma)]),

    %% Step 4: Crash recovery (transient restart)
    io:format("--- Step 4: Crash recovery (transient) ---~n"),
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
    io:format("Stopping gamma gracefully...~n"),
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

    %% Step 7: Remove a worker
    io:format("--- Step 7: Remove worker ---~n"),
    io:format("Removing beta...~n"),
    ok = remove_worker(beta),
    timer:sleep(100),
    io:format("beta alive? ~p~n", [is_pid(whereis(beta))]),
    io:format("count_children: ~p~n~n",
              [supervisor:count_children(?MODULE)]),

    %% Step 8: Shutdown
    io:format("--- Step 8: Shutdown ---~n"),
    stop(),
    timer:sleep(100),
    io:format("Pool supervisor stopped.~n~n"),

    io:format("pool_sup demo completed.~n~n"),
    ok.
