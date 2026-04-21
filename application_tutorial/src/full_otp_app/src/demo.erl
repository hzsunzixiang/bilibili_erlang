%%% @doc demo - Interactive demo for the full_otp_app application.
%%%
%%% Provides a run/0 function that exercises all OTP behaviours
%%% in the application: gen_server, gen_event, and gen_statem.
%%%
%%% Usage:
%%%   demo:run().
-module(demo).

-export([run/0]).

%%====================================================================
%% Demo
%%====================================================================

run() ->
    io:format("~n========================================~n"),
    io:format("  full_otp_app Demo~n"),
    io:format("  Showcasing: supervisor + gen_server~n"),
    io:format("              + gen_event + gen_statem~n"),
    io:format("========================================~n~n"),

    %% Ensure the application is started
    case application:ensure_all_started(full_otp_app) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end,

    %% --- gen_server demo ---
    io:format("--- [gen_server] kv_server demo ---~n~n"),

    kv_server:put(language, "Erlang"),
    kv_server:put(version, "OTP 27"),
    kv_server:put(paradigm, "functional"),
    io:format("  put 3 keys: language, version, paradigm~n"),

    {ok, Lang} = kv_server:get(language),
    io:format("  get(language) = ~p~n", [Lang]),

    {error, not_found} = kv_server:get(nonexistent),
    io:format("  get(nonexistent) = not_found~n"),

    All = kv_server:all(),
    io:format("  all() = ~p~n", [All]),

    kv_server:delete(paradigm),
    io:format("  delete(paradigm)~n"),

    All2 = kv_server:all(),
    io:format("  all() = ~p~n~n", [All2]),

    %% --- gen_event demo ---
    io:format("--- [gen_event] event_bus demo ---~n~n"),

    Handlers = event_bus:which_handlers(),
    io:format("  active handlers: ~p~n", [Handlers]),

    event_bus:notify({custom, "Hello from demo!"}),
    event_bus:sync_notify({custom, "Sync hello!"}),
    io:format("  sent 2 custom events~n~n"),

    %% --- gen_statem demo ---
    io:format("--- [gen_statem] traffic_light demo ---~n~n"),

    State1 = traffic_light:current_state(),
    io:format("  current state: ~p~n", [State1]),

    traffic_light:next(),
    timer:sleep(100),
    State2 = traffic_light:current_state(),
    io:format("  after next(): ~p~n", [State2]),

    traffic_light:next(),
    timer:sleep(100),
    State3 = traffic_light:current_state(),
    io:format("  after next(): ~p~n", [State3]),

    traffic_light:emergency(),
    timer:sleep(100),
    State4 = traffic_light:current_state(),
    io:format("  after emergency(): ~p (should be red)~n", [State4]),

    traffic_light:resume(),
    timer:sleep(100),
    io:format("  resumed normal operation~n~n"),

    %% --- Supervisor tree ---
    io:format("--- [supervisor] tree info ---~n~n"),
    Children = supervisor:which_children(full_otp_app_sup),
    io:format("  supervised children:~n"),
    lists:foreach(
        fun({Id, Pid, Type, Modules}) ->
            io:format("    ~-20s pid=~p type=~p modules=~p~n",
                      [Id, Pid, Type, Modules])
        end,
        Children
    ),

    io:format("~n========================================~n"),
    io:format("  Demo Complete!~n"),
    io:format("========================================~n~n"),
    ok.
