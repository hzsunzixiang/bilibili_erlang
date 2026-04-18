%%%-------------------------------------------------------------------
%%% @doc Demonstrates gen_server timeout mechanism.
%%%      - init can return {ok, State, Timeout}
%%%      - handle_call/handle_cast/handle_info can return with Timeout
%%%      - When timeout fires, handle_info(timeout, State) is called
%%%      - Timeout resets on every incoming message
%%%
%%%      Reference: "Erlang and OTP in Action" Chapter 4
%%% @end
%%%-------------------------------------------------------------------
-module(timeout_demo).
-behaviour(gen_server).

%% Client API
-export([start_link/0, start_link/1, ping/0, pause/0, resume/0]).
-export([demo/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(DEFAULT_TIMEOUT, 3000).

%%====================================================================
%% Client API
%%====================================================================

%% @doc Start with default timeout (3 seconds).
start_link() ->
    start_link(?DEFAULT_TIMEOUT).

%% @doc Start with custom timeout in milliseconds.
start_link(Timeout) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, Timeout, []).

%% @doc Ping the server (resets timeout timer).
ping() ->
    gen_server:call(?MODULE, ping).

%% @doc Pause the periodic timeout (set to infinity).
pause() ->
    gen_server:call(?MODULE, pause).

%% @doc Resume the periodic timeout.
resume() ->
    gen_server:call(?MODULE, resume).

%%====================================================================
%% gen_server Callbacks
%%====================================================================

%% @doc Init with timeout - handle_info(timeout,...) will fire after Timeout ms.
init(Timeout) ->
    io:format("[timeout_demo] Started with timeout=~p ms~n", [Timeout]),
    {ok, #{timeout => Timeout, count => 0}, Timeout}.

%% @doc Handle ping - returns with timeout to keep the timer running.
handle_call(ping, _From, #{timeout := Timeout} = State) ->
    io:format("[timeout_demo] Ping received! Timer reset.~n"),
    {reply, pong, State, Timeout};

%% @doc Handle pause - returns WITHOUT timeout (infinity).
handle_call(pause, _From, State) ->
    io:format("[timeout_demo] Paused. No more timeouts.~n"),
    {reply, paused, State};

%% @doc Handle resume - returns WITH timeout.
handle_call(resume, _From, #{timeout := Timeout} = State) ->
    io:format("[timeout_demo] Resumed with timeout=~p ms~n", [Timeout]),
    {reply, resumed, State, Timeout};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% @doc This is called when the timeout fires.
%%      The timeout resets every time a message arrives.
handle_info(timeout, #{timeout := Timeout, count := Count} = State) ->
    NewCount = Count + 1,
    {_Hour, _Min, Sec} = time(),
    io:format("[timeout_demo] Timeout #~p fired at second :~2..0w~n",
              [NewCount, Sec]),
    {noreply, State#{count := NewCount}, Timeout};

handle_info(Info, State) ->
    io:format("[timeout_demo] Unexpected info: ~p~n", [Info]),
    {noreply, State}.

terminate(Reason, _State) ->
    io:format("[timeout_demo] Terminating: ~p~n", [Reason]),
    ok.

%%====================================================================
%% Demo
%%====================================================================

demo() ->
    io:format("~n=== Timeout Demo ===~n~n"),
    io:format("Starting server with 2-second timeout...~n"),
    {ok, _Pid} = timeout_demo:start_link(2000),

    %% Wait for 2 timeouts
    io:format("Waiting 5 seconds for timeouts...~n"),
    timer:sleep(5000),

    %% Ping to reset timer
    io:format("~nSending ping (resets timer)...~n"),
    pong = timeout_demo:ping(),
    timer:sleep(3000),

    %% Pause
    io:format("~nPausing timeout...~n"),
    paused = timeout_demo:pause(),
    io:format("Waiting 4 seconds (no timeout should fire)...~n"),
    timer:sleep(4000),

    %% Resume
    io:format("~nResuming timeout...~n"),
    resumed = timeout_demo:resume(),
    timer:sleep(3000),

    io:format("~n=== Demo Complete ===~n"),
    ok.
