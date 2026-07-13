%%% @doc data_cache - A gen_server for in-memory caching backed by data_store.
%%%
%%% Demonstrates:
%%%   - Using ETS (Erlang Term Storage) for fast in-memory access
%%%   - Read-through cache pattern: cache miss -> fetch from data_store
%%%   - Write-through: writes go to both cache and data_store
%%%   - Supervised by data_store_sup alongside data_store
%%%
%%% Usage:
%%%   data_cache:put(key, "value").   %% writes to cache + disk
%%%   data_cache:get(key).            %% reads from cache, fallback to disk
%%%   data_cache:invalidate(key).     %% remove from cache only
%%%   data_cache:stats().             %% cache hit/miss statistics
-module(data_cache).
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([put/2, get/1, invalidate/1, flush/0, stats/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).
-define(CACHE_TABLE, data_cache_ets).

-record(state, {
    table :: ets:tid(),
    hits = 0 :: non_neg_integer(),
    misses = 0 :: non_neg_integer()
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% @doc Write-through: store in cache and persist to disk.
-spec put(term(), term()) -> ok.
put(Key, Value) ->
    gen_server:call(?SERVER, {put, Key, Value}).

%% @doc Read-through: try cache first, fallback to data_store.
-spec get(term()) -> {ok, term()} | {error, not_found}.
get(Key) ->
    gen_server:call(?SERVER, {get, Key}).

%% @doc Invalidate a cache entry (disk data remains).
-spec invalidate(term()) -> ok.
invalidate(Key) ->
    gen_server:call(?SERVER, {invalidate, Key}).

%% @doc Flush entire cache (disk data remains).
-spec flush() -> ok.
flush() ->
    gen_server:cast(?SERVER, flush).

%% @doc Return cache hit/miss statistics.
-spec stats() -> #{hits := non_neg_integer(), misses := non_neg_integer(),
                   cache_size := non_neg_integer()}.
stats() ->
    gen_server:call(?SERVER, stats).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    io:format("[data_cache] init: pid=~p~n", [self()]),
    Table = ets:new(?CACHE_TABLE, [set, private]),
    io:format("[data_cache] ETS cache table created~n"),
    {ok, #state{table = Table}}.

handle_call({put, Key, Value}, _From,
            #state{table = Table} = State) ->
    %% Write-through: update cache and persist
    ets:insert(Table, {Key, Value}),
    data_store:put(Key, Value),
    {reply, ok, State};

handle_call({get, Key}, _From,
            #state{table = Table, hits = H, misses = M} = State) ->
    case ets:lookup(Table, Key) of
        [{Key, Value}] ->
            %% Cache hit
            {reply, {ok, Value}, State#state{hits = H + 1}};
        [] ->
            %% Cache miss - try data_store (read-through)
            case data_store:get(Key) of
                {ok, Value} ->
                    %% Populate cache for next time
                    ets:insert(Table, {Key, Value}),
                    {reply, {ok, Value}, State#state{misses = M + 1}};
                {error, not_found} ->
                    {reply, {error, not_found}, State#state{misses = M + 1}}
            end
    end;

handle_call({invalidate, Key}, _From, #state{table = Table} = State) ->
    ets:delete(Table, Key),
    io:format("[data_cache] invalidated ~p~n", [Key]),
    {reply, ok, State};

handle_call(stats, _From,
            #state{table = Table, hits = H, misses = M} = State) ->
    Stats = #{
        hits       => H,
        misses     => M,
        cache_size => ets:info(Table, size)
    },
    {reply, Stats, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(flush, #state{table = Table} = State) ->
    ets:delete_all_objects(Table),
    io:format("[data_cache] cache flushed~n"),
    {noreply, State#state{hits = 0, misses = 0}};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, #state{table = Table}) ->
    io:format("[data_cache] terminate: reason=~p~n", [Reason]),
    ets:delete(Table),
    ok.
