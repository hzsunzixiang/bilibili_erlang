%%%-------------------------------------------------------------------
%%% @doc counter_server - A minimal gen_server callback module.
%%%
%%% This module corresponds to the "Callback Module (Your Code)"
%%% quadrant (bottom-right) in the gen_server architecture diagram
%%% described in gen_server_api_guide.tex (Section 1.2).
%%%
%%% Architecture Mapping:
%%%
%%%   +---------------------+-----------------------------+
%%%   | Client API          | Generic Server              |
%%%   | (gen_server:call,   | (gen_server.erl)            |
%%%   |  cast, stop, ...)   | message loop, routing, ...  |
%%%   +---------------------+-----------------------------+
%%%   | User / Developer    | Callback Module  <-- HERE   |
%%%   | writes this module  | init/1, handle_call/3, ...  |
%%%   +---------------------+-----------------------------+
%%%
%%% The dashed arrow from "User / Developer" to "Callback Module"
%%% represents the function registration process: the module name
%%% (an atom) is passed as a parameter to gen_server:start_link/3,4,
%%% enabling late binding via functional programming.
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(counter_server).
-behaviour(gen_server).

%% Client API
-export([start_link/0, start_link/1, start/0, start/1]).
-export([increment/1, decrement/1, get_count/1, reset/1]).
-export([slow_operation/2, crash/1]).
-export([demo/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, handle_continue/2,
         terminate/2, code_change/3, format_status/2]).

%%% ============================================================
%%% Client API (thin wrappers around gen_server library functions)
%%% ============================================================

start_link() ->
    gen_server:start_link(?MODULE, 0, []).

start_link(InitCount) ->
    gen_server:start_link(?MODULE, InitCount, []).

start() ->
    gen_server:start(?MODULE, 0, []).

start(InitCount) ->
    gen_server:start(?MODULE, InitCount, []).

increment(Server) ->
    gen_server:call(Server, increment).

decrement(Server) ->
    gen_server:call(Server, decrement).

get_count(Server) ->
    gen_server:call(Server, get_count).

reset(Server) ->
    gen_server:cast(Server, reset).

slow_operation(Server, Duration) ->
    gen_server:call(Server, {slow_op, Duration}).

crash(Server) ->
    gen_server:cast(Server, crash).

%%% ============================================================
%%% gen_server callbacks
%%% ============================================================

init(InitCount) when is_integer(InitCount) ->
    process_flag(trap_exit, true),
    io:format("[counter] init: count=~p, pid=~p~n",
              [InitCount, self()]),
    {ok, #{count => InitCount, history => []},
     {continue, post_init}};
init(_) ->
    {stop, {error, bad_init_arg}}.

handle_continue(post_init, State) ->
    io:format("[counter] post_init complete~n"),
    {noreply, State}.

handle_call(increment, _From, #{count := C} = State) ->
    NewCount = C + 1,
    {reply, NewCount, State#{count := NewCount,
        history := [{increment, NewCount} |
                    maps:get(history, State)]}};

handle_call(decrement, _From, #{count := C} = State) ->
    NewCount = C - 1,
    {reply, NewCount, State#{count := NewCount,
        history := [{decrement, NewCount} |
                    maps:get(history, State)]}};

handle_call(get_count, _From, #{count := C} = State) ->
    {reply, C, State};

handle_call({slow_op, Duration}, _From, State) ->
    timer:sleep(Duration),
    {reply, {ok, done_after, Duration}, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(reset, State) ->
    io:format("[counter] reset to 0~n"),
    {noreply, State#{count := 0, history := []}};

handle_cast(crash, _State) ->
    error(deliberate_crash);

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(timeout, State) ->
    io:format("[counter] timeout fired~n"),
    {noreply, State};

handle_info({custom_msg, Payload}, State) ->
    io:format("[counter] received custom_msg: ~p~n", [Payload]),
    {noreply, State};

handle_info({'EXIT', Pid, Reason}, State) ->
    io:format("[counter] linked process ~p exited: ~p~n",
              [Pid, Reason]),
    {noreply, State};

handle_info(Info, State) ->
    io:format("[counter] unexpected info: ~p~n", [Info]),
    {noreply, State}.

terminate(Reason, #{count := C}) ->
    io:format("[counter] terminating: reason=~p, "
              "final_count=~p~n", [Reason, C]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

format_status(_Opt, [_PDict, #{count := C, history := H}]) ->
    [{data, [{"State",
              #{count => C,
                history_length => length(H)}}]}].

%%% ============================================================
%%% Demo
%%% ============================================================

%% @doc demo/0 - Demonstrates basic gen_server usage via counter_server.
demo() ->
    io:format("~n=== counter_server demo ===~n~n"),

    {ok, Pid} = start_link(0),
    io:format("Started: ~p~n", [Pid]),

    io:format("increment: ~p~n", [increment(Pid)]),
    io:format("increment: ~p~n", [increment(Pid)]),
    io:format("increment: ~p~n", [increment(Pid)]),
    io:format("get_count: ~p~n", [get_count(Pid)]),
    io:format("decrement: ~p~n", [decrement(Pid)]),
    io:format("get_count: ~p~n", [get_count(Pid)]),

    reset(Pid),
    timer:sleep(10),
    io:format("after reset, get_count: ~p~n", [get_count(Pid)]),

    io:format("slow_operation(100ms): ~p~n", [slow_operation(Pid, 100)]),

    gen_server:stop(Pid),
    timer:sleep(50),
    io:format("~ncounter_server demo completed.~n"),
    ok.
