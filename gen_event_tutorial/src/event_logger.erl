-module(event_logger).
-behaviour(gen_event).

%% API
-export([demo/0]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

%%====================================================================
%% API - Demo function
%%====================================================================

demo() ->
    io:format("~n=== gen_event Event Logger Demo ===~n~n"),

    %% Step 1: Start an event manager
    {ok, Mgr} = gen_event:start_link({local, my_event_mgr}),
    io:format("[1] Event manager started: ~p~n", [Mgr]),

    %% Step 2: Add a handler that logs to stdout
    ok = gen_event:add_handler(my_event_mgr, ?MODULE, {stdout}),
    io:format("[2] Added stdout logger handler~n~n"),

    %% Step 3: Send some events
    io:format("--- Sending events ---~n"),
    gen_event:notify(my_event_mgr, {info, "System started"}),
    gen_event:notify(my_event_mgr, {warning, "Memory usage high"}),
    gen_event:notify(my_event_mgr, {error, "Connection lost"}),
    gen_event:sync_notify(my_event_mgr, {info, "Connection restored"}),

    %% Step 4: Query handler state
    io:format("~n--- Query handler state ---~n"),
    Count = gen_event:call(my_event_mgr, ?MODULE, get_count),
    io:format("Total events logged: ~p~n", [Count]),

    %% Step 5: List handlers
    Handlers = gen_event:which_handlers(my_event_mgr),
    io:format("Active handlers: ~p~n", [Handlers]),

    %% Step 6: Delete handler
    gen_event:delete_handler(my_event_mgr, ?MODULE, normal),
    io:format("~n[6] Handler removed~n"),

    %% Step 7: Stop event manager
    gen_event:stop(my_event_mgr),
    io:format("[7] Event manager stopped~n"),

    io:format("~n=== Demo Complete ===~n~n").

%%====================================================================
%% gen_event callbacks
%%====================================================================

%% init/1 - Initialize handler state
%% Called when handler is added via add_handler/3
init({stdout}) ->
    io:format("    [event_logger] init: logging to stdout~n"),
    {ok, #{output => stdout, count => 0}};
init({file, Filename}) ->
    {ok, Fd} = file:open(Filename, [write, append]),
    io:format("    [event_logger] init: logging to file ~s~n", [Filename]),
    {ok, #{output => {file, Fd}, count => 0}}.

%% handle_event/2 - Handle async events (notify/sync_notify)
handle_event({Level, Message}, #{output := Output, count := Count} = State) ->
    Timestamp = format_time(),
    Line = io_lib:format("  [~s] ~s: ~s~n", [Timestamp, Level, Message]),
    write_output(Output, Line),
    {ok, State#{count := Count + 1}};
handle_event(_Event, State) ->
    {ok, State}.

%% handle_call/2 - Handle sync requests (gen_event:call)
handle_call(get_count, #{count := Count} = State) ->
    {ok, Count, State};
handle_call(get_state, State) ->
    {ok, State, State};
handle_call(_Request, State) ->
    {ok, {error, unknown_request}, State}.

%% handle_info/2 - Handle other messages
handle_info(_Info, State) ->
    {ok, State}.

%% terminate/2 - Cleanup when handler is removed
terminate(Reason, #{output := Output, count := Count}) ->
    io:format("    [event_logger] terminating: reason=~p, logged ~p events~n",
              [Reason, Count]),
    case Output of
        {file, Fd} -> file:close(Fd);
        stdout -> ok
    end,
    ok.

%% code_change/3 - Hot code upgrade
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Internal functions
%%====================================================================

write_output(stdout, Line) ->
    io:format(Line);
write_output({file, Fd}, Line) ->
    io:format(Fd, "~s", [Line]).

format_time() ->
    {{_Y, _M, _D}, {H, Mi, S}} = calendar:local_time(),
    io_lib:format("~2..0w:~2..0w:~2..0w", [H, Mi, S]).
