%%% @doc data_store - A gen_server for disk-based data persistence using DETS.
%%%
%%% Demonstrates:
%%%   - Using DETS (Disk Erlang Term Storage) for persistence
%%%   - Data survives process restarts and application restarts
%%%   - Supervised by data_store_sup (sub-supervisor)
%%%
%%% Usage:
%%%   data_store:put(key, "value").
%%%   data_store:get(key).           %% => {ok, "value"}
%%%   data_store:delete(key).
%%%   data_store:all().
%%%   data_store:clear().
-module(data_store).
-behaviour(gen_server).

%% API
-export([start_link/0]).
-export([put/2, get/1, delete/1, all/0, clear/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
         handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).
-define(DETS_TABLE, full_otp_data_store).
-define(DETS_FILE, "data/full_otp_data_store.dets").

-record(state, {
    table :: dets:tab_name()
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% @doc Persist a key-value pair to disk.
-spec put(term(), term()) -> ok.
put(Key, Value) ->
    gen_server:call(?SERVER, {put, Key, Value}).

%% @doc Retrieve a value by key from disk.
-spec get(term()) -> {ok, term()} | {error, not_found}.
get(Key) ->
    gen_server:call(?SERVER, {get, Key}).

%% @doc Delete a key from disk.
-spec delete(term()) -> ok.
delete(Key) ->
    gen_server:call(?SERVER, {delete, Key}).

%% @doc Return all persisted key-value pairs.
-spec all() -> [{term(), term()}].
all() ->
    gen_server:call(?SERVER, all).

%% @doc Clear all persisted data.
-spec clear() -> ok.
clear() ->
    gen_server:cast(?SERVER, clear).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init([]) ->
    io:format("[data_store] init: pid=~p~n", [self()]),
    %% Ensure data directory exists
    ok = filelib:ensure_dir(?DETS_FILE),
    %% Open DETS table - data persists across restarts
    case dets:open_file(?DETS_TABLE, [{file, ?DETS_FILE}, {type, set}]) of
        {ok, Table} ->
            Size = dets:info(Table, size),
            io:format("[data_store] opened DETS file ~s (~p records)~n",
                      [?DETS_FILE, Size]),
            {ok, #state{table = Table}};
        {error, Reason} ->
            io:format("[data_store] failed to open DETS: ~p~n", [Reason]),
            {stop, {dets_open_failed, Reason}}
    end.

handle_call({put, Key, Value}, _From, #state{table = Table} = State) ->
    ok = dets:insert(Table, {Key, Value}),
    %% Sync to disk immediately for demo purposes
    ok = dets:sync(Table),
    io:format("[data_store] persisted ~p = ~p~n", [Key, Value]),
    {reply, ok, State};

handle_call({get, Key}, _From, #state{table = Table} = State) ->
    Reply = case dets:lookup(Table, Key) of
        [{Key, Value}] -> {ok, Value};
        [] -> {error, not_found}
    end,
    {reply, Reply, State};

handle_call({delete, Key}, _From, #state{table = Table} = State) ->
    ok = dets:delete(Table, Key),
    ok = dets:sync(Table),
    io:format("[data_store] deleted ~p~n", [Key]),
    {reply, ok, State};

handle_call(all, _From, #state{table = Table} = State) ->
    Records = dets:foldl(fun(Record, Acc) -> [Record | Acc] end, [], Table),
    {reply, Records, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(clear, #state{table = Table} = State) ->
    dets:delete_all_objects(Table),
    dets:sync(Table),
    io:format("[data_store] all data cleared~n"),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, #state{table = Table}) ->
    io:format("[data_store] terminate: reason=~p, closing DETS~n", [Reason]),
    dets:close(Table),
    ok.
