%%% @doc traffic_light - A gen_statem based traffic light FSM.
%%%
%%% Demonstrates gen_statem behaviour within an OTP application:
%%%   - State functions: red/3, green/3, yellow/3
%%%   - State timeouts for automatic transitions
%%%   - External events: manual next/0, emergency/0, resume/0
%%%
%%% State transitions:
%%%   red (30s) -> green (30s) -> yellow (30s) -> red ...
%%%   Any state + emergency -> red (stays until resume)
%%%
%%% Usage (after application started):
%%%   traffic_light:current_state().
%%%   traffic_light:next().
%%%   traffic_light:emergency().
%%%   traffic_light:resume().
-module(traffic_light).
-behaviour(gen_statem).

%% API
-export([start_link/0, current_state/0, next/0, emergency/0, resume/0, stop/0]).

%% gen_statem callbacks
-export([init/1, callback_mode/0, terminate/3, code_change/4]).
-export([red/3, green/3, yellow/3]).

-define(SERVER, ?MODULE).

-define(RED_TIMEOUT,    30000).
-define(GREEN_TIMEOUT,  30000).
-define(YELLOW_TIMEOUT, 30000).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_statem:start_link({local, ?SERVER}, ?MODULE, [], []).

%% @doc Get the current traffic light state.
-spec current_state() -> red | green | yellow.
current_state() ->
    gen_statem:call(?SERVER, current_state).

%% @doc Manually advance to the next state.
-spec next() -> ok.
next() ->
    gen_statem:cast(?SERVER, next).

%% @doc Trigger emergency mode (force red, stop auto-transition).
-spec emergency() -> ok.
emergency() ->
    gen_statem:cast(?SERVER, emergency).

%% @doc Resume normal operation from emergency.
-spec resume() -> ok.
resume() ->
    gen_statem:cast(?SERVER, resume).

-spec stop() -> ok.
stop() ->
    gen_statem:stop(?SERVER).

%%====================================================================
%% gen_statem callbacks
%%====================================================================

init([]) ->
    io:format("[traffic_light] init: starting at red, pid=~p~n", [self()]),
    {ok, red, #{emergency => false}, [{state_timeout, ?RED_TIMEOUT, auto}]}.

callback_mode() ->
    state_functions.

%%--------------------------------------------------------------------
%% State: red
%%--------------------------------------------------------------------
red(state_timeout, auto, #{emergency := false} = Data) ->
    io:format("[traffic_light] red -> green~n"),
    safe_notify({traffic_light, state_change, red, green}),
    {next_state, green, Data, [{state_timeout, ?GREEN_TIMEOUT, auto}]};
red(cast, next, #{emergency := false} = Data) ->
    io:format("[traffic_light] red -> green (manual)~n"),
    safe_notify({traffic_light, state_change, red, green}),
    {next_state, green, Data, [{state_timeout, ?GREEN_TIMEOUT, auto}]};
red(cast, emergency, Data) ->
    io:format("[traffic_light] EMERGENCY at red~n"),
    {keep_state, Data#{emergency := true}};
red(cast, resume, #{emergency := true} = Data) ->
    io:format("[traffic_light] resume from emergency at red~n"),
    {keep_state, Data#{emergency := false}, [{state_timeout, ?RED_TIMEOUT, auto}]};
red({call, From}, current_state, Data) ->
    {keep_state, Data, [{reply, From, red}]};
red(_EventType, _EventContent, Data) ->
    {keep_state, Data}.

%%--------------------------------------------------------------------
%% State: green
%%--------------------------------------------------------------------
green(state_timeout, auto, #{emergency := false} = Data) ->
    io:format("[traffic_light] green -> yellow~n"),
    safe_notify({traffic_light, state_change, green, yellow}),
    {next_state, yellow, Data, [{state_timeout, ?YELLOW_TIMEOUT, auto}]};
green(cast, next, #{emergency := false} = Data) ->
    io:format("[traffic_light] green -> yellow (manual)~n"),
    safe_notify({traffic_light, state_change, green, yellow}),
    {next_state, yellow, Data, [{state_timeout, ?YELLOW_TIMEOUT, auto}]};
green(cast, emergency, Data) ->
    io:format("[traffic_light] EMERGENCY at green -> red~n"),
    safe_notify({traffic_light, emergency, green, red}),
    {next_state, red, Data#{emergency := true}};
green({call, From}, current_state, Data) ->
    {keep_state, Data, [{reply, From, green}]};
green(_EventType, _EventContent, Data) ->
    {keep_state, Data}.

%%--------------------------------------------------------------------
%% State: yellow
%%--------------------------------------------------------------------
yellow(state_timeout, auto, #{emergency := false} = Data) ->
    io:format("[traffic_light] yellow -> red~n"),
    safe_notify({traffic_light, state_change, yellow, red}),
    {next_state, red, Data, [{state_timeout, ?RED_TIMEOUT, auto}]};
yellow(cast, next, #{emergency := false} = Data) ->
    io:format("[traffic_light] yellow -> red (manual)~n"),
    safe_notify({traffic_light, state_change, yellow, red}),
    {next_state, red, Data, [{state_timeout, ?RED_TIMEOUT, auto}]};
yellow(cast, emergency, Data) ->
    io:format("[traffic_light] EMERGENCY at yellow -> red~n"),
    safe_notify({traffic_light, emergency, yellow, red}),
    {next_state, red, Data#{emergency := true}};
yellow({call, From}, current_state, Data) ->
    {keep_state, Data, [{reply, From, yellow}]};
yellow(_EventType, _EventContent, Data) ->
    {keep_state, Data}.

%%====================================================================
%% Internal functions
%%====================================================================

terminate(Reason, State, _Data) ->
    io:format("[traffic_light] terminate: reason=~p, state=~p~n",
              [Reason, State]),
    ok.

code_change(_OldVsn, State, Data, _Extra) ->
    {ok, State, Data}.

%% @doc Safely notify event_bus; ignore if not yet started.
safe_notify(Event) ->
    try
        event_bus:notify(Event)
    catch
        _:_ -> ok
    end.
