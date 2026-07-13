%%% @doc event_bus - A gen_event based event manager.
%%%
%%% Demonstrates gen_event behaviour within an OTP application:
%%%   - Acts as a central event bus for the application
%%%   - Supports adding/removing event handlers at runtime
%%%   - Ships with a built-in log_handler that prints events to stdout
%%%
%%% Usage (after application started):
%%%   event_bus:notify({info, "something happened"}).
%%%   event_bus:add_handler(event_bus_handler, []).
%%%   event_bus:remove_handler(event_bus_handler, normal).
-module(event_bus).

%% API
-export([start_link/0, notify/1, sync_notify/1]).
-export([add_handler/2, remove_handler/2, which_handlers/0]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API
%%====================================================================

%% @doc Start the event manager and install the default log handler.
-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    case gen_event:start_link({local, ?SERVER}) of
        {ok, Pid} ->
            %% Install the default log handler
            gen_event:add_handler(?SERVER, event_bus_handler, []),
            io:format("[event_bus] started with default handler, pid=~p~n", [Pid]),
            {ok, Pid};
        Error ->
            Error
    end.

%% @doc Send an asynchronous event.
-spec notify(term()) -> ok.
notify(Event) ->
    gen_event:notify(?SERVER, Event).

%% @doc Send a synchronous event (blocks until all handlers processed).
-spec sync_notify(term()) -> ok.
sync_notify(Event) ->
    gen_event:sync_notify(?SERVER, Event).

%% @doc Add a handler module to the event bus.
-spec add_handler(module(), term()) -> ok | {'EXIT', term()} | term().
add_handler(Handler, Args) ->
    gen_event:add_handler(?SERVER, Handler, Args).

%% @doc Remove a handler from the event bus.
-spec remove_handler(module(), term()) -> term().
remove_handler(Handler, Args) ->
    gen_event:delete_handler(?SERVER, Handler, Args).

%% @doc List all active handlers.
-spec which_handlers() -> [module()].
which_handlers() ->
    gen_event:which_handlers(?SERVER).
