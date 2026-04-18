%%%-------------------------------------------------------------------
%%% @doc Demonstrates gen_server:reply/2 for explicit reply.
%%%      Instead of returning {reply, Reply, NewState}, we can
%%%      use gen_server:reply(From, Reply) and return {noreply, NewState}.
%%%      This is useful when you need to do work AFTER sending the reply.
%%%
%%%      Reference: "Erlang and OTP in Action" Chapter 4
%%% @end
%%%-------------------------------------------------------------------
-module(frequency_reply).
-behaviour(gen_server).

%% Client API
-export([start_link/0, stop/0, allocate/0, deallocate/1]).
-export([demo/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2]).

%%====================================================================
%% Client API
%%====================================================================

start_link() ->
    gen_server:start_link({local, frequency_reply}, ?MODULE, [], []).

stop() ->
    gen_server:cast(frequency_reply, stop).

allocate() ->
    gen_server:call(frequency_reply, {allocate, self()}).

deallocate(Frequency) ->
    gen_server:cast(frequency_reply, {deallocate, Frequency}).

%%====================================================================
%% gen_server Callbacks
%%====================================================================

init(_Args) ->
    {ok, {get_frequencies(), []}}.

get_frequencies() -> [10, 11, 12, 13, 14, 15].

%% @doc Using explicit gen_server:reply/2 instead of {reply, ...}.
%%      This allows us to send the reply BEFORE doing additional work.
%%      The client unblocks immediately, while the server continues processing.
handle_call({allocate, Pid}, From, Frequencies) ->
    {NewFrequencies, Reply} = allocate(Frequencies, Pid),
    %% Explicitly reply to the caller
    gen_server:reply(From, Reply),
    %% Do some post-reply work (client already got the response)
    io:format("[frequency_reply] Post-reply work: From=~p~n", [From]),
    %% Return noreply since we already replied
    {noreply, NewFrequencies};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast({deallocate, Freq}, Frequencies) ->
    {noreply, deallocate(Frequencies, Freq)};

handle_cast(stop, State) ->
    {stop, normal, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, _State) ->
    io:format("[frequency_reply] Terminating: ~p~n", [Reason]),
    ok.

%%====================================================================
%% Internal Functions
%%====================================================================

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
    io:format("~n=== Explicit Reply Demo ===~n~n"),
    {ok, _Pid} = frequency_reply:start_link(),
    {ok, Freq1} = frequency_reply:allocate(),
    io:format("Client got reply: ~p~n", [Freq1]),
    {ok, Freq2} = frequency_reply:allocate(),
    io:format("Client got reply: ~p~n", [Freq2]),
    frequency_reply:deallocate(Freq1),
    frequency_reply:stop(),
    timer:sleep(100),
    io:format("~n=== Demo Complete ===~n"),
    ok.
