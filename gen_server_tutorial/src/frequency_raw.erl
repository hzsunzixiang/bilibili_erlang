%%%-------------------------------------------------------------------
%%% @doc Step 1: Raw frequency server using plain Erlang processes.
%%%      This demonstrates the basic client-server pattern WITHOUT
%%%      using gen_server. We will evolve this into a gen_server
%%%      implementation step by step.
%%%
%%%      Reference: "Erlang and OTP in Action" Chapter 3
%%%% @end
%%%-------------------------------------------------------------------
-module(frequency_raw).
-export([start/0, stop/0, allocate/0, deallocate/1]).
-export([init/0]).
-export([demo/0]).

%%====================================================================
%% Client API
%%====================================================================

%% @doc Start the frequency server process and register it locally.
start() ->
    register(frequency_raw, spawn(frequency_raw, init, [])).

%% @doc Stop the frequency server.
stop() ->
    call(stop).

%% @doc Allocate a frequency for the calling process.
allocate() ->
    call(allocate).

%% @doc Deallocate a previously allocated frequency.
deallocate(Freq) ->
    call({deallocate, Freq}).

%%====================================================================
%% Internal Client Helper
%%====================================================================

%% @doc Send a synchronous request to the server and wait for reply.
call(Message) ->
    frequency_raw ! {request, self(), Message},
    receive
        {reply, Reply} -> Reply
    end.

%%====================================================================
%% Server Implementation
%%====================================================================

%% @doc Initialize the server with available frequencies.
init() ->
    Frequencies = {get_frequencies(), []},
    loop(Frequencies).

%% @doc Hard-coded frequency list (in real system, from BSC).
get_frequencies() -> [10, 11, 12, 13, 14, 15].

%% @doc Send reply back to the client process.
reply(Pid, Reply) ->
    Pid ! {reply, Reply}.

%% @doc Main server loop - receives and processes requests.
loop(Frequencies) ->
    receive
        {request, Pid, allocate} ->
            {NewFrequencies, Reply} = allocate(Frequencies, Pid),
            reply(Pid, Reply),
            loop(NewFrequencies);
        {request, Pid, {deallocate, Freq}} ->
            NewFrequencies = deallocate(Frequencies, Freq),
            reply(Pid, ok),
            loop(NewFrequencies);
        {request, Pid, stop} ->
            reply(Pid, ok)
    end.

%%====================================================================
%% Internal Helper Functions
%%====================================================================

%% @doc Try to allocate a frequency. Returns {NewState, Reply}.
allocate({[], Allocated}, _Pid) ->
    {{[], Allocated}, {error, no_frequency}};
allocate({[Freq | Free], Allocated}, Pid) ->
    {{Free, [{Freq, Pid} | Allocated]}, {ok, Freq}}.

%% @doc Deallocate a frequency back to the free pool.
deallocate({Free, Allocated}, Freq) ->
    NewAllocated = lists:keydelete(Freq, 1, Allocated),
    {[Freq | Free], NewAllocated}.

%%====================================================================
%% Demo function
%%====================================================================

%% @doc Run a demo to show basic usage.
demo() ->
    frequency_raw:start(),
    {ok, Freq1} = frequency_raw:allocate(),
    io:format("Allocated frequency: ~p~n", [Freq1]),
    {ok, Freq2} = frequency_raw:allocate(),
    io:format("Allocated frequency: ~p~n", [Freq2]),
    frequency_raw:deallocate(Freq1),
    io:format("Deallocated frequency: ~p~n", [Freq1]),
    {ok, Freq3} = frequency_raw:allocate(),
    io:format("Re-allocated frequency: ~p~n", [Freq3]),
    frequency_raw:stop(),
    io:format("Server stopped.~n"),
    ok.
