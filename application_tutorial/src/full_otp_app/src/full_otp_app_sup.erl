%%% @doc Top-level supervisor for full_otp_app.
%%%
%%% Supervises three children demonstrating different OTP behaviours:
%%%   1. kv_server       - gen_server  (key-value store)
%%%   2. event_bus        - gen_event   (event manager)
%%%   3. traffic_light    - gen_statem  (traffic light FSM)
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
%%   - kv_server:      a gen_server that stores key-value pairs
%%   - event_bus:      a gen_event manager for publishing/subscribing events
%%   - traffic_light:  a gen_statem implementing a traffic light FSM
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
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.
