%%%-------------------------------------------------------------------
%%% @doc worker_sup - A one_for_one supervisor managing a counter worker.
%%%
%%% This module demonstrates the most common supervisor pattern:
%%% one_for_one strategy with a static child specification.
%%%
%%% Architecture:
%%%
%%%   worker_sup (supervisor, one_for_one)
%%%       |
%%%       +-- counter_worker (gen_server, permanent)
%%%
%%% Key concepts demonstrated:
%%%   - one_for_one restart strategy
%%%   - permanent restart type (always restart)
%%%   - Restart intensity/period (max 3 restarts in 60 seconds)
%%%   - Graceful shutdown with 5000ms timeout
%%%   - Map-based SupFlags and ChildSpec (OTP 18+)
%%%   - supervisor:which_children/1 and count_children/1
%%%
%%% Usage:
%%%   1> worker_sup:start_link().
%%%   {ok,<0.80.0>}
%%%   2> counter_worker:increment().
%%%   3
%%%   3> counter_worker:crash().
%%%   ok
%%%   4> counter_worker:get_count().
%%%   0    %% restarted with fresh state
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(worker_sup).
-behaviour(supervisor).

%% Client API
-export([start_link/0, stop/0]).

%% supervisor callback
-export([init/1]).

%% Demo
-export([demo/0]).

%%% ============================================================
%%% Client API
%%% ============================================================

%% @doc Start the supervisor, registered locally as ?MODULE.
-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% @doc Stop the supervisor and all its children.
-spec stop() -> true.
stop() ->
    exit(whereis(?MODULE), shutdown).

%%% ============================================================
%%% supervisor callback
%%% ============================================================

%% @doc Initialize the supervisor with one_for_one strategy.
%%
%% Returns:
%%   {ok, {SupFlags, [ChildSpec]}}
%%
%% SupFlags:
%%   strategy  = one_for_one  -- only restart the crashed child
%%   intensity = 3            -- max 3 restarts
%%   period    = 60           -- within 60 seconds
%%
%% ChildSpec:
%%   id       = counter_worker
%%   start    = {counter_worker, start_link, []}
%%   restart  = permanent     -- always restart
%%   shutdown = 5000          -- 5s graceful shutdown timeout
%%   type     = worker
init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 3,
        period    => 60
    },
    ChildSpecs = [
        #{
            id       => counter_worker,
            start    => {counter_worker, start_link, []},
            restart  => permanent,
            shutdown => 5000,
            type     => worker,
            modules  => [counter_worker]
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.

%%% ============================================================
%%% Demo
%%% ============================================================

%% @doc demo/0 - Demonstrates supervisor with one_for_one strategy.
%%
%% Shows:
%%   1. Starting the supervisor (which starts counter_worker)
%%   2. Normal operations (increment, get_count)
%%   3. Crash recovery (counter_worker crashes, supervisor restarts it)
%%   4. Inspecting children (which_children, count_children)
%%   5. Graceful shutdown
demo() ->
    io:format("~n========================================~n"),
    io:format("  Example 1: worker_sup (one_for_one)~n"),
    io:format("========================================~n~n"),

    %% Step 1: Start supervisor
    io:format("--- Step 1: Start supervisor ---~n"),
    {ok, SupPid} = start_link(),
    io:format("Supervisor started: ~p~n", [SupPid]),
    io:format("counter_worker pid: ~p~n~n", [whereis(counter_worker)]),

    %% Step 2: Normal operations
    io:format("--- Step 2: Normal operations ---~n"),
    io:format("increment: ~p~n", [counter_worker:increment()]),
    io:format("increment: ~p~n", [counter_worker:increment()]),
    io:format("increment: ~p~n", [counter_worker:increment()]),
    io:format("get_count: ~p~n~n", [counter_worker:get_count()]),

    %% Step 3: Crash and auto-restart
    io:format("--- Step 3: Crash and auto-restart ---~n"),
    OldPid = whereis(counter_worker),
    io:format("Before crash, pid=~p~n", [OldPid]),
    counter_worker:crash(),
    timer:sleep(100),  %% wait for restart
    NewPid = whereis(counter_worker),
    io:format("After crash,  pid=~p (new process!)~n", [NewPid]),
    io:format("get_count after restart: ~p (reset to 0)~n~n",
              [counter_worker:get_count()]),

    %% Step 4: Inspect children
    io:format("--- Step 4: Inspect children ---~n"),
    io:format("which_children: ~p~n",
              [supervisor:which_children(?MODULE)]),
    io:format("count_children: ~p~n~n",
              [supervisor:count_children(?MODULE)]),

    %% Step 5: Kill with exit signal (supervisor restarts)
    io:format("--- Step 5: Kill with exit signal ---~n"),
    Pid2 = whereis(counter_worker),
    io:format("Before kill, pid=~p~n", [Pid2]),
    exit(Pid2, kill),
    timer:sleep(100),
    Pid3 = whereis(counter_worker),
    io:format("After kill,  pid=~p (restarted again!)~n~n", [Pid3]),

    %% Step 6: Graceful shutdown
    io:format("--- Step 6: Graceful shutdown ---~n"),
    stop(),
    timer:sleep(100),
    io:format("Supervisor stopped. counter_worker alive? ~p~n~n",
              [is_pid(whereis(counter_worker))]),

    io:format("worker_sup demo completed.~n~n"),
    ok.
