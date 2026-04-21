%%% @doc Simple Application callback module example.
%%% This module demonstrates the minimum implementation of
%%% the application behaviour.
%%%
%%% Usage:
%%%   application:ensure_all_started(simple_app).
%%%   application:stop(simple_app).
-module(simple_app).
-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%%--------------------------------------------------------------------
%% @doc Start the application.
%% Called by the application controller when application:start/1,2
%% is invoked. Must return {ok, Pid} where Pid is the top supervisor.
%%--------------------------------------------------------------------
-spec start(StartType, StartArgs) -> {ok, pid()} | {error, term()} when
      StartType :: application:start_type(),
      StartArgs :: term().
start(_StartType, _StartArgs) ->
    io:format("[simple_app] starting...~n"),
    simple_app_sup:start_link().

%%--------------------------------------------------------------------
%% @doc Stop the application.
%% Called after the supervision tree has been terminated.
%%--------------------------------------------------------------------
-spec stop(State :: term()) -> ok.
stop(_State) ->
    io:format("[simple_app] stopped.~n"),
    ok.
