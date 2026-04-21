%%% @doc A simple gen_server worker for the simple_app example.
%%% Maintains a counter that can be incremented, decremented, and queried.
-module(simple_worker).
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([increment/0, decrement/0, get_count/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).

-record(state, {
    count = 0 :: integer()
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec increment() -> integer().
increment() ->
    gen_server:call(?SERVER, increment).

-spec decrement() -> integer().
decrement() ->
    gen_server:call(?SERVER, decrement).

-spec get_count() -> integer().
get_count() ->
    gen_server:call(?SERVER, get_count).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    io:format("[simple_worker] init: count=0, pid=~p~n", [self()]),
    {ok, #state{count = 0}}.

handle_call(increment, _From, #state{count = N} = State) ->
    NewCount = N + 1,
    {reply, NewCount, State#state{count = NewCount}};
handle_call(decrement, _From, #state{count = N} = State) ->
    NewCount = N - 1,
    {reply, NewCount, State#state{count = NewCount}};
handle_call(get_count, _From, #state{count = N} = State) ->
    {reply, N, State};
handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, #state{count = N}) ->
    io:format("[simple_worker] terminate: reason=~p, count=~p~n",
              [Reason, N]),
    ok.
