%%% @doc Application callback module with start_phase support.
%%% Demonstrates the use of start_phases for phased application startup.
%%%
%%% Usage:
%%%   application:ensure_all_started(phased_app).
%%%   application:stop(phased_app).
-module(phased_app).
-behaviour(application).

%% Application callbacks
-export([start/2, start_phase/3, stop/1, prep_stop/1]).

%%--------------------------------------------------------------------
%% @doc Start the application.
%%--------------------------------------------------------------------
-spec start(StartType, StartArgs) -> {ok, pid()} | {error, term()} when
      StartType :: application:start_type(),
      StartArgs :: term().
start(StartType, _StartArgs) ->
    io:format("[phased_app] start: type=~p~n", [StartType]),
    phased_app_sup:start_link().

%%--------------------------------------------------------------------
%% @doc Handle each start phase.
%% Called for each phase defined in the .app file's start_phases key.
%%--------------------------------------------------------------------
-spec start_phase(Phase, StartType, PhaseArgs) -> ok when
      Phase :: atom(),
      StartType :: application:start_type(),
      PhaseArgs :: term().
start_phase(Phase, StartType, PhaseArgs) ->
    io:format("[phased_app] start_phase: phase=~p, type=~p, args=~p~n",
              [Phase, StartType, PhaseArgs]),
    ok.

%%--------------------------------------------------------------------
%% @doc Called before the application processes are terminated.
%% Useful for saving state or performing pre-shutdown cleanup.
%%--------------------------------------------------------------------
-spec prep_stop(State :: term()) -> term().
prep_stop(State) ->
    io:format("[phased_app] prep_stop: state=~p~n", [State]),
    State.

%%--------------------------------------------------------------------
%% @doc Stop the application.
%% Called after all processes have been terminated.
%%--------------------------------------------------------------------
-spec stop(State :: term()) -> ok.
stop(State) ->
    io:format("[phased_app] stop: state=~p~n", [State]),
    ok.
