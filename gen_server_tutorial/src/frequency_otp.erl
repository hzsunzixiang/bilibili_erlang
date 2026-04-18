%%%-------------------------------------------------------------------
%%% @doc Step 3: Frequency server using OTP gen_server behavior.
%%%      This is the real OTP way to implement a client-server.
%%%      Demonstrates: start_link, call, cast, handle_call, handle_cast,
%%%      handle_info, terminate, format_status.
%%%
%%%      Reference: "Erlang and OTP in Action" Chapter 4
%%% @end
%%%-------------------------------------------------------------------
-module(frequency_otp).
-behaviour(gen_server).

%% Client API
-export([start_link/0, stop/0, allocate/0, deallocate/1]).
-export([demo/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3, format_status/2]).

%%====================================================================
%% Client API
%%====================================================================

%% @doc Start the frequency server, registered locally as 'frequency_otp'.
%%      start_link/0 links the server to the calling process.
%%      If the server crashes, the parent will receive an EXIT signal.
start_link() ->
    gen_server:start_link({local, frequency_otp}, ?MODULE, [], []).

%% @doc Stop the frequency server gracefully using cast.
stop() ->
    gen_server:cast(frequency_otp, stop).

%% @doc Allocate a frequency (synchronous call).
%%      Returns {ok, Frequency} | {error, no_frequency}.
allocate() ->
    gen_server:call(frequency_otp, {allocate, self()}).

%% @doc Deallocate a frequency (asynchronous cast).
deallocate(Frequency) ->
    gen_server:cast(frequency_otp, {deallocate, Frequency}).

%%====================================================================
%% gen_server Callbacks
%%====================================================================

%% @doc Initialize the server state.
%%      Called by gen_server:start_link/4.
%%      Must return {ok, State} | {ok, State, Timeout} | {stop, Reason}.
init(_Args) ->
    io:format("[frequency_otp] Server initialized. PID=~p~n", [self()]),
    Frequencies = {get_frequencies(), []},
    {ok, Frequencies}.

%% @doc Handle synchronous calls.
%%      Called when a client uses gen_server:call/2,3.
%%      Must return {reply, Reply, NewState} | {noreply, NewState} | {stop,...}.
handle_call({allocate, Pid}, _From, Frequencies) ->
    {NewFrequencies, Reply} = allocate(Frequencies, Pid),
    {reply, Reply, NewFrequencies};

handle_call(Request, _From, State) ->
    io:format("[frequency_otp] Unknown call: ~p~n", [Request]),
    {reply, {error, unknown_request}, State}.

%% @doc Handle asynchronous casts.
%%      Called when a client uses gen_server:cast/2.
%%      Must return {noreply, NewState} | {stop, Reason, NewState}.
handle_cast({deallocate, Freq}, Frequencies) ->
    NewFrequencies = deallocate(Frequencies, Freq),
    {noreply, NewFrequencies};

handle_cast(stop, State) ->
    {stop, normal, State};

handle_cast(Msg, State) ->
    io:format("[frequency_otp] Unknown cast: ~p~n", [Msg]),
    {noreply, State}.

%% @doc Handle all other messages (non call/cast).
%%      For example: plain Erlang messages sent with '!'.
handle_info(Info, State) ->
    io:format("[frequency_otp] Received info message: ~p~n", [Info]),
    {noreply, State}.

%% @doc Called when the server is about to terminate.
%%      Reason is the reason for termination.
terminate(Reason, {Free, Allocated}) ->
    io:format("[frequency_otp] Terminating. Reason=~p~n", [Reason]),
    io:format("  Free frequencies: ~p~n", [Free]),
    io:format("  Allocated frequencies: ~p~n", [Allocated]),
    ok.

%% @doc Format the server state for sys:get_status/1.
format_status(_Opt, [_ProcDict, {Available, Allocated}]) ->
    {data, [{"State", {{available, Available}, {allocated, Allocated}}}]}.

%% @doc Handle code change during hot upgrade.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Internal Functions
%%====================================================================

get_frequencies() -> [10, 11, 12, 13, 14, 15].

allocate({[], Allocated}, _Pid) ->
    {{[], Allocated}, {error, no_frequency}};
allocate({[Freq | Free], Allocated}, Pid) ->
    {{Free, [{Freq, Pid} | Allocated]}, {ok, Freq}}.

deallocate({Free, Allocated}, Freq) ->
    NewAllocated = lists:keydelete(Freq, 1, Allocated),
    {[Freq | Free], NewAllocated}.

%%====================================================================
%% Demo
%%====================================================================

demo() ->
    io:format("~n=== OTP gen_server Frequency Server Demo ===~n~n"),

    %% Start the server
    {ok, Pid} = frequency_otp:start_link(),
    io:format("Server started. PID=~p~n~n", [Pid]),

    %% Send a plain message to demonstrate handle_info
    Pid ! <<"Hello, this is a plain message">>,
    timer:sleep(100),

    %% Allocate frequencies
    {ok, Freq1} = frequency_otp:allocate(),
    io:format("Allocated: ~p~n", [Freq1]),
    {ok, Freq2} = frequency_otp:allocate(),
    io:format("Allocated: ~p~n", [Freq2]),
    {ok, Freq3} = frequency_otp:allocate(),
    io:format("Allocated: ~p~n", [Freq3]),

    %% Deallocate one
    frequency_otp:deallocate(Freq2),
    io:format("Deallocated: ~p~n", [Freq2]),
    timer:sleep(100),

    %% Allocate again (should get Freq2 back)
    {ok, Freq4} = frequency_otp:allocate(),
    io:format("Re-allocated: ~p~n", [Freq4]),

    %% Check server status
    io:format("~nServer status: ~p~n", [sys:get_status(frequency_otp)]),

    %% Stop the server
    io:format("~nStopping server...~n"),
    frequency_otp:stop(),
    timer:sleep(200),
    io:format("~n=== Demo Complete ===~n"),
    ok.
