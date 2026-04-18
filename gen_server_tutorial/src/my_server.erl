%%%-------------------------------------------------------------------
%%% @doc Step 2: Generic server abstraction.
%%%      This module extracts the generic parts of the client-server
%%%      pattern into a reusable library module. The callback module
%%%      (frequency_generic) provides the specific logic.
%%%
%%%      Reference: "Erlang and OTP in Action" Chapter 3 - Behavior
%%% @end
%%%-------------------------------------------------------------------
-module(my_server).
-export([start/2, stop/1, call/2]).
-export([init/2]).

%%====================================================================
%% Client API (Generic)
%%====================================================================

%% @doc Start a named server with the given callback module.
%%      Name: atom to register the process
%%      Mod:  callback module implementing init/1, handle/2, terminate/1
start(Name, Mod) ->
    register(Name, spawn(my_server, init, [Name, Mod])).

%% @doc Stop the named server.
stop(Name) ->
    Name ! {stop, self()},
    receive {reply, Reply} -> Reply end.

%% @doc Make a synchronous call to the named server.
call(Name, Msg) ->
    Name ! {request, self(), Msg},
    receive {reply, Reply} -> Reply end.

%%====================================================================
%% Server Implementation (Generic)
%%====================================================================

%% @doc Initialize the server by calling the callback module's init/1.
init(Mod, _Args) ->
    State = Mod:init([]),
    loop(Mod, State).

%% @doc Send reply to the client.
reply(To, Reply) ->
    To ! {reply, Reply}.

%% @doc Generic server loop.
%%      Dispatches requests to Mod:handle/2 and stop to Mod:terminate/1.
loop(Mod, State) ->
    receive
        {request, From, Msg} ->
            {NewState, Reply} = Mod:handle(Msg, State),
            reply(From, Reply),
            loop(Mod, NewState);
        {stop, From} ->
            Reply = Mod:terminate(State),
            reply(From, Reply)
    end.
