%%%-------------------------------------------------------------------
%%% @doc Demonstrates gen_server call timeout behavior.
%%%      - gen_server:call/2 has a default 5-second timeout
%%%      - gen_server:call/3 allows custom timeout
%%%      - When timeout occurs, the CALLER crashes (not the server)
%%%      - start_link vs start: different crash propagation behavior
%%%
%%%      Reference: "Erlang and OTP in Action" Chapter 4
%%% @end
%%%-------------------------------------------------------------------
-module(call_timeout_demo).
-behaviour(gen_server).

%% Client API
-export([start_link/0, start/0, slow_call/1, slow_call/2]).
-export([demo/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%%====================================================================
%% Client API
%%====================================================================

%% @doc Start with link (crash propagation).
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Start without link (no crash propagation).
start() ->
    gen_server:start({local, ?MODULE}, ?MODULE, [], []).

%% @doc Make a slow call. The server sleeps for Ms milliseconds.
%%      Uses default 5-second timeout.
slow_call(Ms) ->
    gen_server:call(?MODULE, {sleep, Ms}).

%% @doc Make a slow call with custom timeout.
slow_call(Ms, Timeout) ->
    gen_server:call(?MODULE, {sleep, Ms}, Timeout).

%%====================================================================
%% gen_server Callbacks
%%====================================================================

init(_Args) ->
    io:format("[call_timeout] Server started. PID=~p~n", [self()]),
    {ok, undefined}.

handle_call({sleep, Ms}, _From, State) ->
    io:format("[call_timeout] Sleeping ~p ms...~n", [Ms]),
    timer:sleep(Ms),
    io:format("[call_timeout] Woke up after ~p ms~n", [Ms]),
    {reply, ok, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, _State) ->
    io:format("[call_timeout] Terminating: ~p~n", [Reason]),
    ok.

%%====================================================================
%% Demo
%%====================================================================

demo() ->
    io:format("~n=== Call Timeout Demo ===~n~n"),

    %% Demo 1: Normal call (within timeout)
    io:format("--- Demo 1: Normal call (1 second sleep, default 5s timeout) ---~n"),
    {ok, _Pid1} = call_timeout_demo:start_link(),
    ok = call_timeout_demo:slow_call(1000),
    io:format("Call succeeded!~n~n"),

    %% Stop and restart for next demo
    gen_server:stop(?MODULE),
    timer:sleep(100),

    %% Demo 2: Custom short timeout
    io:format("--- Demo 2: Custom timeout (2s sleep, 1s timeout) ---~n"),
    {ok, _Pid2} = call_timeout_demo:start(),  %% Note: start, not start_link!
    try
        call_timeout_demo:slow_call(2000, 1000)
    catch
        exit:{timeout, _} ->
            io:format("Caught timeout! Client crashed but server is alive.~n"),
            io:format("Server still running? ~p~n",
                      [erlang:is_process_alive(whereis(?MODULE))])
    end,
    timer:sleep(2500),  %% Wait for server to finish sleeping

    %% Demo 3: Show server is still alive after client timeout
    io:format("~n--- Demo 3: Server still works after client timeout ---~n"),
    ok = call_timeout_demo:slow_call(100),
    io:format("Server responded normally!~n"),

    gen_server:stop(?MODULE),
    timer:sleep(100),
    io:format("~n=== Demo Complete ===~n"),
    ok.
