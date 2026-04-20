-module(swap_handler_demo).
-behaviour(gen_event).

%% API
-export([demo/0]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

%%====================================================================
%% API - Demonstrates swap_handler mechanism
%%====================================================================

demo() ->
    io:format("~n=== gen_event Swap Handler Demo ===~n~n"),
    io:format("This demo shows how to hot-swap handlers while preserving state.~n~n"),

    %% Start event manager
    {ok, _} = gen_event:start_link({local, swap_mgr}),

    %% Add handler in "file" mode
    ok = gen_event:add_handler(swap_mgr, ?MODULE, {mode, file, "events.log"}),
    io:format("[1] Handler added in FILE mode~n~n"),

    %% Send some events
    gen_event:notify(swap_mgr, {info, "Event 1 - goes to file"}),
    gen_event:notify(swap_mgr, {info, "Event 2 - goes to file"}),

    %% Query state before swap
    State1 = gen_event:call(swap_mgr, ?MODULE, get_state),
    io:format("[2] State before swap: ~p~n~n", [State1]),

    %% Swap handler: file mode -> stdout mode
    %% The old handler's terminate/2 returns transfer data
    %% The new handler's init/1 receives {NewArgs, TransferData}
    io:format("[3] Swapping handler: file -> stdout~n"),
    ok = gen_event:swap_handler(
        swap_mgr,
        {?MODULE, {swap_to, stdout}},    %% {OldHandler, Args1} -> terminate(Args1, State)
        {?MODULE, {mode, stdout}}         %% {NewHandler, Args2} -> init({Args2, TransferData})
    ),

    io:format("~n[4] Now in STDOUT mode, sending more events:~n"),
    gen_event:notify(swap_mgr, {warning, "Event 3 - goes to stdout"}),
    gen_event:notify(swap_mgr, {error, "Event 4 - goes to stdout"}),

    %% Query state after swap
    State2 = gen_event:call(swap_mgr, ?MODULE, get_state),
    io:format("~n[5] State after swap: ~p~n", [State2]),
    io:format("    Note: count was preserved across swap!~n"),

    %% Cleanup
    gen_event:stop(swap_mgr),
    file:delete("events.log"),
    io:format("~n=== Demo Complete ===~n~n").

%%====================================================================
%% gen_event callbacks
%%====================================================================

%% Normal init (first time add_handler)
init({mode, file, Filename}) ->
    {ok, Fd} = file:open(Filename, [write]),
    io:format("    [swap_demo] init: FILE mode -> ~s~n", [Filename]),
    {ok, #{mode => file, fd => Fd, filename => Filename, count => 0}};
init({mode, stdout}) ->
    io:format("    [swap_demo] init: STDOUT mode (fresh start)~n"),
    {ok, #{mode => stdout, count => 0}};

%% Swap init - receives {NewArgs, TransferData} from old handler's terminate
init({{mode, stdout}, TransferData}) ->
    #{count := OldCount} = TransferData,
    io:format("    [swap_demo] swap init: STDOUT mode, inherited count=~p~n", [OldCount]),
    {ok, #{mode => stdout, count => OldCount}};
init({{mode, file, Filename}, TransferData}) ->
    #{count := OldCount} = TransferData,
    {ok, Fd} = file:open(Filename, [write]),
    io:format("    [swap_demo] swap init: FILE mode -> ~s, inherited count=~p~n",
              [Filename, OldCount]),
    {ok, #{mode => file, fd => Fd, filename => Filename, count => OldCount}}.

%% handle_event - write to appropriate output
handle_event({Level, Msg}, #{mode := file, fd := Fd, count := Count} = State) ->
    io:format(Fd, "[~p] ~s~n", [Level, Msg]),
    io:format("    [swap_demo] wrote to file: [~p] ~s~n", [Level, Msg]),
    {ok, State#{count := Count + 1}};
handle_event({Level, Msg}, #{mode := stdout, count := Count} = State) ->
    io:format("    [swap_demo] stdout: [~p] ~s~n", [Level, Msg]),
    {ok, State#{count := Count + 1}};
handle_event(_Event, State) ->
    {ok, State}.

handle_call(get_state, State) ->
    {ok, State, State};
handle_call(_Request, State) ->
    {ok, {error, unknown}, State}.

handle_info(_Info, State) ->
    {ok, State}.

%% terminate - when swap is requested, return transfer data
terminate({swap_to, _NewMode}, #{mode := file, fd := Fd} = State) ->
    file:close(Fd),
    TransferData = maps:without([fd, filename], State),
    io:format("    [swap_demo] terminate(swap): closing file, transferring state~n"),
    TransferData;
terminate({swap_to, _NewMode}, State) ->
    TransferData = State,
    io:format("    [swap_demo] terminate(swap): transferring state~n"),
    TransferData;
terminate(Reason, #{mode := file, fd := Fd, count := Count}) ->
    file:close(Fd),
    io:format("    [swap_demo] terminate(~p): closing file, total events=~p~n",
              [Reason, Count]),
    ok;
terminate(Reason, #{count := Count}) ->
    io:format("    [swap_demo] terminate(~p): total events=~p~n", [Reason, Count]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.
