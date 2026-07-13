%%% @doc data_store_sup - Sub-supervisor for data persistence layer.
%%%
%%% Demonstrates supervisor-under-supervisor pattern.
%%% Supervises two children with rest_for_one strategy:
%%%   1. data_store  - gen_server wrapping DETS for disk persistence
%%%   2. data_cache  - gen_server wrapping ETS for in-memory cache
%%%
%%% rest_for_one: if data_store crashes, data_cache also restarts
%%% (because cache depends on the underlying store).
-module(data_store_sup).
-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%--------------------------------------------------------------------
%% @doc Start the data persistence sub-supervisor.
%%--------------------------------------------------------------------
-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%--------------------------------------------------------------------
%% @doc Initialize with rest_for_one strategy.
%%
%% rest_for_one means: if data_store crashes, data_cache (started
%% after it) will also be restarted, ensuring cache consistency.
%%--------------------------------------------------------------------
init([]) ->
    SupFlags = #{
        strategy  => rest_for_one,
        intensity => 5,
        period    => 60
    },
    ChildSpecs = [
        %% Child 1: data_store - DETS-based disk persistence
        #{
            id       => data_store,
            start    => {data_store, start_link, []},
            restart  => permanent,
            shutdown => 5000,
            type     => worker,
            modules  => [data_store]
        },
        %% Child 2: data_cache - ETS-based in-memory cache
        #{
            id       => data_cache,
            start    => {data_cache, start_link, []},
            restart  => permanent,
            shutdown => 5000,
            type     => worker,
            modules  => [data_cache]
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.
