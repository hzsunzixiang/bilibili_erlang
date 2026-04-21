%%% @doc Top-level supervisor for full_otp_app.
%%%
%%% Supervises four children demonstrating different OTP behaviours:
%%%   1. kv_server        - gen_server  (key-value store)
%%%   2. event_bus         - gen_event   (event manager)
%%%   3. traffic_light     - gen_statem  (traffic light FSM)
%%%   4. data_store_sup    - supervisor  (data persistence sub-tree)
%%%
%%% Strategy: one_for_one - if one child crashes, only that child restarts.
-module(full_otp_app_sup).
-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%--------------------------------------------------------------------
%% @doc Start the supervisor, registered locally.
%%--------------------------------------------------------------------
-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%--------------------------------------------------------------------
%% @doc Initialize the supervisor with child specifications.
%%
%% Children:
%%   - kv_server:       a gen_server that stores key-value pairs
%%   - event_bus:       a gen_event manager for publishing/subscribing events
%%   - traffic_light:   a gen_statem implementing a traffic light FSM
%%   - data_store_sup:  a sub-supervisor for data persistence (DETS + ETS cache)
%%--------------------------------------------------------------------
init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 5,
        period    => 60
    },
    ChildSpecs = [
        %% Child 1: gen_server - Key-Value Store
        #{
            id       => kv_server,
            start    => {kv_server, start_link, []},
            restart  => permanent,
            shutdown => 5000,
            type     => worker,
            modules  => [kv_server]
        },
        %% Child 2: gen_event - Event Bus
        #{
            id       => event_bus,
            start    => {event_bus, start_link, []},
            restart  => permanent,
            shutdown => 5000,
            type     => worker,
            modules  => dynamic
        },
        %% Child 3: gen_statem - Traffic Light FSM
        #{
            id       => traffic_light,
            start    => {traffic_light, start_link, []},
            restart  => permanent,
            shutdown => 5000,
            type     => worker,
            modules  => [traffic_light]
        },
        %% Child 4: supervisor - Data Persistence Sub-tree
        %%   data_store_sup supervises: data_store (DETS) + data_cache (ETS)
        #{
            id       => data_store_sup,
            start    => {data_store_sup, start_link, []},
            restart  => permanent,
            shutdown => infinity,
            type     => supervisor,
            modules  => [data_store_sup]
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.
