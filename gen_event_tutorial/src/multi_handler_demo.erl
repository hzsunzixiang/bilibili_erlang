-module(multi_handler_demo).
-behaviour(gen_event).

%% API
-export([demo/0]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

%%====================================================================
%% API - Demonstrates multiple handlers on one event manager
%%====================================================================

demo() ->
    io:format("~n=== gen_event Multiple Handlers Demo ===~n~n"),

    %% Start event manager
    {ok, _} = gen_event:start_link({local, multi_mgr}),
    io:format("[1] Event manager started~n~n"),

    %% Add multiple handlers with different configurations
    %% Same module, different IDs (using {Module, Id} form)
    ok = gen_event:add_handler(multi_mgr, {?MODULE, error_filter},
                               #{name => "ErrorFilter", level => error}),
    ok = gen_event:add_handler(multi_mgr, {?MODULE, all_events},
                               #{name => "AllEvents", level => all}),
    ok = gen_event:add_handler(multi_mgr, {?MODULE, warning_filter},
                               #{name => "WarningFilter", level => warning}),
    io:format("[2] Added 3 handlers (same module, different IDs)~n"),

    %% Show which handlers are active
    Handlers = gen_event:which_handlers(multi_mgr),
    io:format("    Active handlers: ~p~n~n", [Handlers]),

    %% Send events - each handler filters differently
    io:format("--- Sending events ---~n"),
    gen_event:notify(multi_mgr, {info, "User logged in"}),
    gen_event:notify(multi_mgr, {warning, "Disk 80% full"}),
    gen_event:notify(multi_mgr, {error, "Database connection failed"}),
    gen_event:notify(multi_mgr, {info, "Request completed"}),

    %% Query each handler's count
    io:format("~n--- Handler event counts ---~n"),
    C1 = gen_event:call(multi_mgr, {?MODULE, error_filter}, get_count),
    C2 = gen_event:call(multi_mgr, {?MODULE, all_events}, get_count),
    C3 = gen_event:call(multi_mgr, {?MODULE, warning_filter}, get_count),
    io:format("  ErrorFilter:   ~p events~n", [C1]),
    io:format("  AllEvents:     ~p events~n", [C2]),
    io:format("  WarningFilter: ~p events~n", [C3]),

    %% Delete one handler
    io:format("~n--- Removing ErrorFilter handler ---~n"),
    gen_event:delete_handler(multi_mgr, {?MODULE, error_filter}, normal),
    Handlers2 = gen_event:which_handlers(multi_mgr),
    io:format("  Remaining handlers: ~p~n", [Handlers2]),

    %% Stop
    gen_event:stop(multi_mgr),
    io:format("~n=== Demo Complete ===~n~n").

%%====================================================================
%% gen_event callbacks
%%====================================================================

init(#{name := Name, level := Level}) ->
    io:format("    [~s] init: filtering level=~p~n", [Name, Level]),
    {ok, #{name => Name, level => Level, count => 0}}.

handle_event({EventLevel, Msg}, #{name := Name, level := Filter, count := Count} = State) ->
    case should_handle(EventLevel, Filter) of
        true ->
            io:format("    [~s] ~p: ~s~n", [Name, EventLevel, Msg]),
            {ok, State#{count := Count + 1}};
        false ->
            {ok, State}
    end;
handle_event(_Event, State) ->
    {ok, State}.

handle_call(get_count, #{count := Count} = State) ->
    {ok, Count, State};
handle_call(_Request, State) ->
    {ok, {error, unknown}, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(Reason, #{name := Name, count := Count}) ->
    io:format("    [~s] terminating: reason=~p, handled ~p events~n",
              [Name, Reason, Count]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Internal functions
%%====================================================================

%% Level filtering logic
should_handle(_Any, all) -> true;
should_handle(error, error) -> true;
should_handle(error, warning) -> true;   %% warning filter also catches errors
should_handle(warning, warning) -> true;
should_handle(_, _) -> false.
