%%%-------------------------------------------------------------------
%%% @doc Step 2: Frequency server using our custom generic server.
%%%      This is the "specific" part that works with my_server.erl.
%%%      It implements the callback functions: init/1, handle/2, terminate/1.
%%%
%%%      Reference: "Erlang and OTP in Action" Chapter 3 - Behavior
%%% @end
%%%-------------------------------------------------------------------
-module(frequency_generic).
-export([start/0, stop/0, allocate/0, deallocate/1]).
-export([init/1, handle/2, terminate/1]).
-export([demo/0]).

%%====================================================================
%% Client API (Specific)
%%====================================================================

%% @doc Start the frequency server using our generic server.
start() ->
    my_server:start(frequency_generic, frequency_generic).

%% @doc Stop the frequency server.
stop() ->
    my_server:stop(frequency_generic).

%% @doc Allocate a frequency.
allocate() ->
    my_server:call(frequency_generic, {allocate, self()}).

%% @doc Deallocate a frequency.
deallocate(Freq) ->
    my_server:call(frequency_generic, {deallocate, Freq}).

%%====================================================================
%% Callback Functions (called by my_server)
%%====================================================================

%% @doc Initialize the server state.
init(_Args) ->
    {get_frequencies(), []}.

%% @doc Handle allocate request.
handle({allocate, Pid}, Frequencies) ->
    allocate(Frequencies, Pid);

%% @doc Handle deallocate request.
handle({deallocate, Freq}, Frequencies) ->
    {deallocate(Frequencies, Freq), ok}.

%% @doc Clean up when server stops.
terminate(Frequencies) ->
    io:format("Frequency server terminating. State: ~p~n", [Frequencies]),
    ok.

%%====================================================================
%% Internal Helper Functions
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
    frequency_generic:start(),
    {ok, Freq1} = frequency_generic:allocate(),
    io:format("Allocated: ~p~n", [Freq1]),
    {ok, Freq2} = frequency_generic:allocate(),
    io:format("Allocated: ~p~n", [Freq2]),
    frequency_generic:deallocate(Freq1),
    io:format("Deallocated: ~p~n", [Freq1]),
    frequency_generic:stop(),
    ok.
