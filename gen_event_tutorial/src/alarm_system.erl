-module(alarm_system).
-behaviour(gen_event).

%% API
-export([demo/0]).
-export([start_link/0, set_alarm/2, clear_alarm/1, get_alarms/0, stop/0]).

%% gen_event callbacks
-export([init/1, handle_event/2, handle_call/2, handle_info/2,
         terminate/2, code_change/3]).

%%====================================================================
%% API - A practical alarm system using gen_event
%%====================================================================

start_link() ->
    gen_event:start_link({local, alarm_mgr}).

set_alarm(AlarmId, Description) ->
    gen_event:notify(alarm_mgr, {set_alarm, AlarmId, Description}).

clear_alarm(AlarmId) ->
    gen_event:notify(alarm_mgr, {clear_alarm, AlarmId}).

get_alarms() ->
    {ok, gen_event:call(alarm_mgr, ?MODULE, get_alarms)}.

stop() ->
    gen_event:stop(alarm_mgr).

%%====================================================================
%% Demo
%%====================================================================

demo() ->
    io:format("~n=== gen_event Alarm System Demo ===~n~n"),
    io:format("A practical example: alarm management system~n"),
    io:format("Similar to OTP's built-in alarm_handler in SASL~n~n"),

    %% Start alarm manager
    {ok, _} = start_link(),
    io:format("[1] Alarm manager started~n"),

    %% Add our alarm handler
    ok = gen_event:add_handler(alarm_mgr, ?MODULE, []),
    io:format("[2] Alarm handler installed~n~n"),

    %% Set some alarms
    io:format("--- Setting alarms ---~n"),
    set_alarm(cpu_high, "CPU usage above 90%"),
    set_alarm(disk_full, "Disk /dev/sda1 is 95% full"),
    set_alarm(mem_low, "Available memory below 100MB"),

    %% Check active alarms
    timer:sleep(100),
    {ok, Alarms1} = get_alarms(),
    io:format("~n--- Active alarms (~p) ---~n", [length(Alarms1)]),
    lists:foreach(fun({Id, Desc, Time}) ->
        io:format("  [~p] ~s (set at ~s)~n", [Id, Desc, format_time(Time)])
    end, Alarms1),

    %% Clear an alarm
    io:format("~n--- Clearing cpu_high alarm ---~n"),
    clear_alarm(cpu_high),
    timer:sleep(100),

    {ok, Alarms2} = get_alarms(),
    io:format("~n--- Active alarms (~p) ---~n", [length(Alarms2)]),
    lists:foreach(fun({Id, Desc, _Time}) ->
        io:format("  [~p] ~s~n", [Id, Desc])
    end, Alarms2),

    %% Set duplicate alarm (should update, not duplicate)
    io:format("~n--- Setting duplicate alarm (disk_full) ---~n"),
    set_alarm(disk_full, "Disk /dev/sda1 is 99% full (CRITICAL)"),
    timer:sleep(100),

    {ok, Alarms3} = get_alarms(),
    io:format("  Active alarms: ~p (no duplicates)~n", [length(Alarms3)]),
    lists:foreach(fun({Id, Desc, _Time}) ->
        io:format("  [~p] ~s~n", [Id, Desc])
    end, Alarms3),

    %% Stop
    stop(),
    io:format("~n=== Demo Complete ===~n~n").

%%====================================================================
%% gen_event callbacks
%%====================================================================

init([]) ->
    io:format("    [alarm_system] init: alarm handler ready~n"),
    {ok, #{alarms => []}}.

handle_event({set_alarm, AlarmId, Description}, #{alarms := Alarms} = State) ->
    Now = erlang:timestamp(),
    %% Remove existing alarm with same ID (update behavior)
    Alarms1 = lists:keydelete(AlarmId, 1, Alarms),
    NewAlarms = [{AlarmId, Description, Now} | Alarms1],
    io:format("  ALARM SET: [~p] ~s~n", [AlarmId, Description]),
    {ok, State#{alarms := NewAlarms}};

handle_event({clear_alarm, AlarmId}, #{alarms := Alarms} = State) ->
    case lists:keyfind(AlarmId, 1, Alarms) of
        {AlarmId, Desc, _Time} ->
            NewAlarms = lists:keydelete(AlarmId, 1, Alarms),
            io:format("  ALARM CLEARED: [~p] ~s~n", [AlarmId, Desc]),
            {ok, State#{alarms := NewAlarms}};
        false ->
            io:format("  ALARM CLEAR: [~p] not found (ignored)~n", [AlarmId]),
            {ok, State}
    end;

handle_event(_Event, State) ->
    {ok, State}.

handle_call(get_alarms, #{alarms := Alarms} = State) ->
    {ok, Alarms, State};
handle_call(_Request, State) ->
    {ok, {error, unknown}, State}.

handle_info(_Info, State) ->
    {ok, State}.

terminate(_Reason, #{alarms := Alarms}) ->
    io:format("    [alarm_system] terminating with ~p active alarms~n", [length(Alarms)]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Internal functions
%%====================================================================

format_time({MegaSecs, Secs, _MicroSecs}) ->
    TotalSecs = MegaSecs * 1000000 + Secs,
    {{_Y, _M, _D}, {H, Mi, S}} = calendar:gregorian_seconds_to_datetime(
        TotalSecs + 62167219200), %% Unix epoch offset
    io_lib:format("~2..0w:~2..0w:~2..0w", [H, Mi, S]).
