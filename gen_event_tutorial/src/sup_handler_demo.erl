-module(sup_handler_demo).
-behaviour(gen_event).

%% API
-export([demo/0]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

%%====================================================================
%% API - Demonstrates add_sup_handler (supervised handlers)
%%====================================================================

demo() ->
    io:format("~n=== gen_event Supervised Handler Demo ===~n~n"),
    io:format("add_sup_handler links the handler to the calling process.~n"),
    io:format("If the handler crashes or is removed, the caller gets notified.~n~n"),

    %% Start event manager
    {ok, Mgr} = gen_event:start_link({local, sup_mgr}),
    io:format("[1] Event manager started: ~p~n", [Mgr]),

    %% Add a supervised handler from a spawned process
    Self = self(),
    Watcher = spawn_link(fun() -> watcher_loop(Self) end),
    io:format("[2] Watcher process started: ~p~n~n", [Watcher]),

    %% Tell watcher to add supervised handler
    Watcher ! {add_handler, sup_mgr},
    timer:sleep(100),

    %% Send some events
    io:format("--- Sending events ---~n"),
    gen_event:notify(sup_mgr, {info, "Normal event 1"}),
    gen_event:notify(sup_mgr, {info, "Normal event 2"}),
    timer:sleep(100),

    %% Now send an event that will crash the handler
    io:format("~n--- Sending crash event ---~n"),
    gen_event:notify(sup_mgr, crash_now),
    timer:sleep(200),

    %% The watcher should have been notified and re-added the handler
    io:format("~n--- After crash recovery ---~n"),
    Handlers = gen_event:which_handlers(sup_mgr),
    io:format("  Active handlers: ~p~n", [Handlers]),

    %% Send more events to prove it works
    gen_event:notify(sup_mgr, {info, "Event after recovery"}),
    timer:sleep(100),

    %% Cleanup
    Watcher ! stop,
    timer:sleep(100),
    gen_event:stop(sup_mgr),
    io:format("~n=== Demo Complete ===~n~n").

%%====================================================================
%% Watcher process - monitors the supervised handler
%%====================================================================

watcher_loop(Parent) ->
    receive
        {add_handler, Manager} ->
            io:format("    [watcher] Adding supervised handler~n"),
            ok = gen_event:add_sup_handler(Manager, ?MODULE, []),
            watcher_loop(Parent, Manager);
        stop ->
            ok
    end.

watcher_loop(Parent, Manager) ->
    receive
        {gen_event_EXIT, ?MODULE, Reason} ->
            %% Handler was removed or crashed
            io:format("    [watcher] Handler exited! Reason: ~p~n", [Reason]),
            io:format("    [watcher] Re-adding handler...~n"),
            timer:sleep(50),
            ok = gen_event:add_sup_handler(Manager, ?MODULE, []),
            watcher_loop(Parent, Manager);
        stop ->
            gen_event:delete_handler(Manager, ?MODULE, normal),
            ok
    end.

%%====================================================================
%% gen_event callbacks
%%====================================================================

init([]) ->
    io:format("    [sup_handler] init~n"),
    {ok, #{count => 0}}.

handle_event(crash_now, _State) ->
    io:format("    [sup_handler] Crashing on purpose!~n"),
    error(intentional_crash);
handle_event({Level, Msg}, #{count := Count} = State) ->
    io:format("    [sup_handler] ~p: ~s (event #~p)~n", [Level, Msg, Count + 1]),
    {ok, State#{count := Count + 1}};
handle_event(_Event, State) ->
    {ok, State}.

handle_call(_Request, State) ->
    {ok, ok, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(Reason, #{count := Count}) ->
    io:format("    [sup_handler] terminate: reason=~p, events=~p~n", [Reason, Count]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
