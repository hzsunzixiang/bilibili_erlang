-module(event_counter).
-behaviour(gen_event).

%% API
-export([get_counts/1, demo/0]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

%%====================================================================
%% API
%%====================================================================

%% Get current event counts from the handler
get_counts(Manager) ->
    {ok, gen_event:call(Manager, ?MODULE, get_counts)}.

demo() ->
    io:format("~n=== gen_event Event Counter Demo ===~n~n"),

    %% Start event manager
    {ok, Mgr} = gen_event:start_link({local, counter_mgr}),
    io:format("[1] Event manager started: ~p~n", [Mgr]),

    %% Add counter handler (uses ETS for counting)
    ok = gen_event:add_handler(counter_mgr, ?MODULE, []),
    io:format("[2] Counter handler added~n~n"),

    %% Send various events
    io:format("--- Sending events ---~n"),
    gen_event:notify(counter_mgr, {error, "disk full"}),
    gen_event:notify(counter_mgr, {error, "timeout"}),
    gen_event:notify(counter_mgr, {warning, "high load"}),
    gen_event:notify(counter_mgr, {info, "user login"}),
    gen_event:notify(counter_mgr, {info, "request handled"}),
    gen_event:notify(counter_mgr, {info, "cache hit"}),
    io:format("  Sent 6 events (2 errors, 1 warning, 3 infos)~n~n"),

    %% Query counts
    {ok, Counts} = get_counts(counter_mgr),
    io:format("--- Event counts ---~n"),
    lists:foreach(fun({Type, Count}) ->
        io:format("  ~p: ~p~n", [Type, Count])
    end, lists:sort(Counts)),

    %% Stop
    gen_event:stop(counter_mgr),
    io:format("~n=== Demo Complete ===~n~n").

%%====================================================================
%% gen_event callbacks
%%====================================================================

init([]) ->
    %% Use ETS table to store event counts
    TableId = ets:new(?MODULE, [set, private]),
    io:format("    [event_counter] init: ETS table created~n"),
    {ok, #{table => TableId}}.

handle_event({Type, _Msg}, #{table := Tab} = State) when is_atom(Type) ->
    %% Increment counter for this event type
    try ets:update_counter(Tab, Type, 1) of
        _ -> ok
    catch
        error:badarg ->
            ets:insert(Tab, {Type, 1})
    end,
    {ok, State};
handle_event(_Event, State) ->
    {ok, State}.

handle_call(get_counts, #{table := Tab} = State) ->
    Counts = ets:tab2list(Tab),
    {ok, Counts, State};
handle_call(get_count, #{table := Tab} = State) ->
    Count = lists:foldl(fun({_, C}, Acc) -> Acc + C end, 0, ets:tab2list(Tab)),
    {ok, Count, State};
handle_call(_Request, State) ->
    {ok, {error, unknown}, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(_Reason, #{table := Tab}) ->
    ets:delete(Tab),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
