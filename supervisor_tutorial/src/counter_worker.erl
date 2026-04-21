%%%-------------------------------------------------------------------
%%% @doc counter_worker - A simple gen_server worker for supervisor demo.
%%%
%%% This module demonstrates a worker process managed by a supervisor.
%%% It implements a named counter that can be incremented, decremented,
%%% and queried. The worker traps exits so that terminate/2 is called
%%% on shutdown, allowing graceful cleanup.
%%%
%%% Architecture:
%%%
%%%   worker_sup (supervisor, one_for_one)
%%%       |
%%%       +-- counter_worker (gen_server, permanent)
%%%
%%% Usage:
%%%   1> worker_sup:start_link().
%%%   2> counter_worker:increment().
%%%   3> counter_worker:get_count().
%%%   4> counter_worker:crash().   %% supervisor auto-restarts
%%%   5> counter_worker:get_count(). %% count reset to 0
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(counter_worker).
-behaviour(gen_server).

%% Client API
-export([start_link/0, increment/0, decrement/0, get_count/0,
         reset/0, crash/0, stop/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

%%% ============================================================
%%% Client API
%%% ============================================================

%% @doc Start the counter worker, registered as ?MODULE.
%% Called by the supervisor via child spec {?MODULE, start_link, []}.
-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Increment the counter by 1, return new value.
-spec increment() -> integer().
increment() ->
    gen_server:call(?MODULE, increment).

%% @doc Decrement the counter by 1, return new value.
-spec decrement() -> integer().
decrement() ->
    gen_server:call(?MODULE, decrement).

%% @doc Get the current counter value.
-spec get_count() -> integer().
get_count() ->
    gen_server:call(?MODULE, get_count).

%% @doc Reset the counter to 0.
-spec reset() -> ok.
reset() ->
    gen_server:cast(?MODULE, reset).

%% @doc Deliberately crash the worker (for testing supervisor restart).
-spec crash() -> no_return().
crash() ->
    gen_server:cast(?MODULE, crash).

%% @doc Gracefully stop the worker.
-spec stop() -> ok.
stop() ->
    gen_server:stop(?MODULE).

%%% ============================================================
%%% gen_server callbacks
%%% ============================================================

init([]) ->
    process_flag(trap_exit, true),
    io:format("[counter_worker] started, pid=~p~n", [self()]),
    {ok, #{count => 0}}.

handle_call(increment, _From, #{count := C} = State) ->
    New = C + 1,
    {reply, New, State#{count := New}};

handle_call(decrement, _From, #{count := C} = State) ->
    New = C - 1,
    {reply, New, State#{count := New}};

handle_call(get_count, _From, #{count := C} = State) ->
    {reply, C, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(reset, State) ->
    io:format("[counter_worker] reset to 0~n"),
    {noreply, State#{count := 0}};

handle_cast(crash, _State) ->
    io:format("[counter_worker] deliberate crash!~n"),
    error(deliberate_crash);

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, #{count := C}) ->
    io:format("[counter_worker] terminating: reason=~p, "
              "final_count=~p, pid=~p~n", [Reason, C, self()]),
    ok.
