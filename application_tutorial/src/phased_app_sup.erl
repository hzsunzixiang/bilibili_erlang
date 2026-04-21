%%% @doc Top supervisor for phased_app.
%%% Identical to simple_app_sup but with a different registered name.
-module(phased_app_sup).
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
%%--------------------------------------------------------------------
init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 5,
        period    => 60
    },
    ChildSpecs = [
        #{
            id       => phased_worker,
            start    => {simple_worker, start_link, []},
            restart  => permanent,
            shutdown => 5000,
            type     => worker,
            modules  => [simple_worker]
        }
    ],
    {ok, {SupFlags, ChildSpecs}}.
