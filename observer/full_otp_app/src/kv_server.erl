%%% @doc kv_server - A gen_server based key-value store.
%%%
%%% Demonstrates gen_server behaviour within an OTP application:
%%%   - Synchronous calls: put/2, get/1, delete/1, all/0
%%%   - Asynchronous cast: clear/0
%%%   - handle_info: periodic stats logging via timer
%%%
%%% Usage (after application started):
%%%   kv_server:put(name, "Erlang").
%%%   kv_server:get(name).
%%%   kv_server:delete(name).
%%%   kv_server:all().
%%%   kv_server:clear().
-module(kv_server).
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([put/2, get/1, delete/1, all/0, clear/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).

-record(state, {
    store = #{} :: map(),
    ops_count = 0 :: non_neg_integer()
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% @doc Store a key-value pair.
-spec put(term(), term()) -> ok.
put(Key, Value) ->
    gen_server:call(?SERVER, {put, Key, Value}).

%% @doc Retrieve a value by key.
-spec get(term()) -> {ok, term()} | {error, not_found}.
get(Key) ->
    gen_server:call(?SERVER, {get, Key}).

%% @doc Delete a key.
-spec delete(term()) -> ok.
delete(Key) ->
    gen_server:call(?SERVER, {delete, Key}).

%% @doc Return all key-value pairs.
-spec all() -> map().
all() ->
    gen_server:call(?SERVER, all).

%% @doc Clear all data (async).
-spec clear() -> ok.
clear() ->
    gen_server:cast(?SERVER, clear).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    io:format("[kv_server] init: pid=~p~n", [self()]),
    %% Schedule periodic stats report every 30 seconds
    erlang:send_after(30000, self(), report_stats),
    {ok, #state{}}.

handle_call({put, Key, Value}, _From, #state{store = Store, ops_count = N} = State) ->
    NewStore = maps:put(Key, Value, Store),
    %% Publish event to event_bus if available
    safe_notify({kv_updated, Key, Value}),
    {reply, ok, State#state{store = NewStore, ops_count = N + 1}};

handle_call({get, Key}, _From, #state{store = Store, ops_count = N} = State) ->
    Reply = case maps:find(Key, Store) of
        {ok, Value} -> {ok, Value};
        error -> {error, not_found}
    end,
    {reply, Reply, State#state{ops_count = N + 1}};

handle_call({delete, Key}, _From, #state{store = Store, ops_count = N} = State) ->
    NewStore = maps:remove(Key, Store),
    safe_notify({kv_deleted, Key}),
    {reply, ok, State#state{store = NewStore, ops_count = N + 1}};

handle_call(all, _From, #state{store = Store, ops_count = N} = State) ->
    {reply, Store, State#state{ops_count = N + 1}};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(clear, #state{} = State) ->
    io:format("[kv_server] store cleared~n"),
    safe_notify({kv_cleared}),
    {noreply, State#state{store = #{}, ops_count = 0}};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(report_stats, #state{store = Store, ops_count = N} = State) ->
    io:format("[kv_server] stats: ~p keys, ~p ops~n",
              [maps:size(Store), N]),
    erlang:send_after(30000, self(), report_stats),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, #state{store = Store}) ->
    io:format("[kv_server] terminate: reason=~p, keys=~p~n",
              [Reason, maps:size(Store)]),
    ok.

%%====================================================================
%% Internal functions
%%====================================================================

%% @doc Safely notify event_bus; ignore if not yet started.
safe_notify(Event) ->
    try
        event_bus:notify(Event)
    catch
        _:_ -> ok
    end.
