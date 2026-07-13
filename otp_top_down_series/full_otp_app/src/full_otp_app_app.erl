%%% @doc Application callback module for full_otp_app.
%%%
%%% This application demonstrates how to combine multiple OTP behaviours
%%% (gen_server, gen_event, gen_statem) under a single supervisor tree.
%%%
%%% Usage:
%%%   application:ensure_all_started(full_otp_app).
%%%   application:stop(full_otp_app).
-module(full_otp_app_app).
-behaviour(application).

%% Application callbacks
-export([start/2, stop/1]).

%%--------------------------------------------------------------------
%% @doc Start the application.
%% Launches the top-level supervisor which manages all child processes.
%%--------------------------------------------------------------------
-spec start(StartType, StartArgs) -> {ok, pid()} | {error, term()} when
      StartType :: application:start_type(),
      StartArgs :: term().
start(_StartType, _StartArgs) ->
    io:format("[full_otp_app] starting...~n"),
    full_otp_app_sup:start_link().

%%--------------------------------------------------------------------
%% @doc Stop the application.
%%--------------------------------------------------------------------
-spec stop(State :: term()) -> ok.
stop(_State) ->
    io:format("[full_otp_app] stopped.~n"),
    ok.
