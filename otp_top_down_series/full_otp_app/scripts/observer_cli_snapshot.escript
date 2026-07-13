#!/usr/bin/env escript
%%! -smp enable

%% observer_cli_snapshot.escript
%%
%% Collect observer_cli-like runtime data through Erlang APIs.
%%
%% Usage:
%%   scripts/observer_cli_snapshot.escript
%%   scripts/observer_cli_snapshot.escript application_demo@HOST COOKIE
%%
%% The no-argument form inspects the escript node itself. The remote form is
%% normally what you want for a running rebar3 shell node.

-mode(compile).

main([]) ->
    print_snapshot(node());
main([TargetNodeText, CookieText]) ->
    TargetNode = list_to_atom(TargetNodeText),
    Cookie = list_to_atom(CookieText),
    start_helper_node(TargetNode, Cookie),
    case net_adm:ping(TargetNode) of
        pong ->
            print_remote_snapshot(TargetNode);
        pang ->
            io:format("Could not connect to ~p. Check node name and cookie.~n", [TargetNode]),
            halt(1)
    end;
main(_) ->
    io:format("Usage: observer_cli_snapshot.escript [TargetNode Cookie]~n", []),
    halt(1).

start_helper_node(TargetNode, Cookie) ->
    NameType = name_type(TargetNode),
    HelperName = helper_name(NameType),
    case net_kernel:start([HelperName, NameType]) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok;
        {error, Reason} ->
            io:format("Could not start helper distributed node: ~p~n", [Reason]),
            halt(1)
    end,
    erlang:set_cookie(node(), Cookie).

name_type(TargetNode) ->
    case string:find(atom_to_list(TargetNode), "@") of
        nomatch -> shortnames;
        _ -> shortnames
    end.

helper_name(shortnames) ->
    list_to_atom("observer_cli_snapshot_" ++ integer_to_list(erlang:unique_integer([positive]))).

print_remote_snapshot(TargetNode) ->
    print_section("Remote Node"),
    io:format("target: ~p~n", [TargetNode]),
    {ok, Snapshot} = collect_remote_snapshot(TargetNode),
    print_snapshot_data(Snapshot).

print_snapshot(Node) ->
    print_section("Local Node"),
    io:format("node: ~p~n", [Node]),
    {ok, Snapshot} = collect_snapshot(),
    print_snapshot_data(Snapshot).

collect_snapshot() ->
    {ok, #{
        system => system_info(),
        applications => application_info(),
        top_processes => top_processes(memory, 15),
        ets_tables => ets_info(15)
    }}.

collect_remote_snapshot(Node) ->
    {ok, #{
        system => remote_system_info(Node),
        applications => remote_application_info(Node),
        top_processes => remote_top_processes(Node, memory, 15),
        ets_tables => remote_ets_info(Node, 15)
    }}.

system_info() ->
    #{
        otp_release => erlang:system_info(otp_release),
        process_count => erlang:system_info(process_count),
        process_limit => erlang:system_info(process_limit),
        port_count => erlang:system_info(port_count),
        port_limit => erlang:system_info(port_limit),
        atom_count => erlang:system_info(atom_count),
        atom_limit => erlang:system_info(atom_limit),
        memory => erlang:memory()
    }.

application_info() ->
    Running = maps:from_list([{App, Vsn} || {App, _Desc, Vsn} <- application:which_applications()]),
    Loaded = maps:from_list([{App, Vsn} || {App, _Desc, Vsn} <- application:loaded_applications()]),
    AppNames = lists:usort(maps:keys(Running) ++ maps:keys(Loaded)),
    AppStats0 = init_app_stats(AppNames, Running, Loaded),
    Leaders = app_group_leaders(),
    lists:foldl(fun(Pid, Acc) -> add_process_to_app(Pid, Leaders, Acc) end, AppStats0, processes()).

remote_system_info(Node) ->
    #{
        otp_release => rpc_call(Node, erlang, system_info, [otp_release]),
        process_count => rpc_call(Node, erlang, system_info, [process_count]),
        process_limit => rpc_call(Node, erlang, system_info, [process_limit]),
        port_count => rpc_call(Node, erlang, system_info, [port_count]),
        port_limit => rpc_call(Node, erlang, system_info, [port_limit]),
        atom_count => rpc_call(Node, erlang, system_info, [atom_count]),
        atom_limit => rpc_call(Node, erlang, system_info, [atom_limit]),
        memory => rpc_call(Node, erlang, memory, [])
    }.

remote_application_info(Node) ->
    Running = maps:from_list([{App, Vsn} || {App, _Desc, Vsn} <- rpc_call(Node, application, which_applications, [])]),
    Loaded = maps:from_list([{App, Vsn} || {App, _Desc, Vsn} <- rpc_call(Node, application, loaded_applications, [])]),
    AppNames = lists:usort(maps:keys(Running) ++ maps:keys(Loaded)),
    AppStats0 = init_app_stats(AppNames, Running, Loaded),
    Leaders = remote_app_group_leaders(Node),
    Pids = rpc_call(Node, erlang, processes, []),
    lists:foldl(fun(Pid, Acc) -> remote_add_process_to_app(Node, Pid, Leaders, Acc) end, AppStats0, Pids).

init_app_stats(AppNames, Running, Loaded) ->
    maps:from_list([
        {App, #{process_count => 0, memory => 0, reductions => 0, msgq => 0,
                status => app_status(App, Running), version => maps:get(App, Loaded, maps:get(App, Running, unknown))}}
     || App <- AppNames
    ]).

app_status(App, Running) ->
    case maps:is_key(App, Running) of
        true -> started;
        false -> loaded
    end.

app_group_leaders() ->
    Info = application:info(),
    case lists:keyfind(running, 1, Info) of
        {running, Running} ->
            maps:from_list(lists:filtermap(fun app_group_leader/1, Running));
        false ->
            #{}
    end.

app_group_leader({App, Pid}) when is_pid(Pid) ->
    case process_info(Pid, group_leader) of
        {group_leader, Leader} -> {true, {Leader, App}};
        _ -> false
    end;
app_group_leader(_) ->
    false.

remote_app_group_leaders(Node) ->
    Info = rpc_call(Node, application, info, []),
    case lists:keyfind(running, 1, Info) of
        {running, Running} ->
            maps:from_list(lists:filtermap(fun(AppPid) -> remote_app_group_leader(Node, AppPid) end, Running));
        false ->
            #{}
    end.

remote_app_group_leader(Node, {App, Pid}) when is_pid(Pid) ->
    case rpc_call(Node, erlang, process_info, [Pid, group_leader]) of
        {group_leader, Leader} -> {true, {Leader, App}};
        _ -> false
    end;
remote_app_group_leader(_Node, _) ->
    false.

add_process_to_app(Pid, Leaders, AppStats) ->
    add_process_info_to_app(process_info(Pid, [group_leader, memory, reductions, message_queue_len]), Leaders, AppStats).

remote_add_process_to_app(Node, Pid, Leaders, AppStats) ->
    add_process_info_to_app(rpc_call(Node, erlang, process_info, [Pid, [group_leader, memory, reductions, message_queue_len]]), Leaders, AppStats).

add_process_info_to_app([{group_leader, Leader}, {memory, Memory}, {reductions, Reds}, {message_queue_len, MsgQ}], Leaders, AppStats) ->
    App = maps:get(Leader, Leaders, no_group),
    ensure_and_update_app(App, Memory, Reds, MsgQ, AppStats);
add_process_info_to_app(_, _Leaders, AppStats) ->
    AppStats.

ensure_and_update_app(App, Memory, Reds, MsgQ, AppStats) ->
    Default = #{process_count => 0, memory => 0, reductions => 0, msgq => 0,
                status => unknown, version => unknown},
    Stats = maps:get(App, AppStats, Default),
    AppStats#{App => Stats#{
        process_count => maps:get(process_count, Stats) + 1,
        memory => maps:get(memory, Stats) + Memory,
        reductions => maps:get(reductions, Stats) + Reds,
        msgq => maps:get(msgq, Stats) + MsgQ
    }}.

top_processes(Key, Limit) ->
    Items = lists:filtermap(fun(Pid) -> process_row(Pid, Key) end, processes()),
    Sorted = lists:reverse(lists:keysort(1, Items)),
    lists:sublist(Sorted, Limit).

remote_top_processes(Node, Key, Limit) ->
    Pids = rpc_call(Node, erlang, processes, []),
    Items = lists:filtermap(fun(Pid) -> remote_process_row(Node, Pid, Key) end, Pids),
    Sorted = lists:reverse(lists:keysort(1, Items)),
    lists:sublist(Sorted, Limit).

process_row(Pid, Key) ->
    Fields = [registered_name, memory, reductions, message_queue_len, current_function],
    case process_info(Pid, Fields) of
        undefined -> false;
        Info -> {true, process_row_from_info(Pid, Key, Info)}
    end.

remote_process_row(Node, Pid, Key) ->
    Fields = [registered_name, memory, reductions, message_queue_len, current_function],
    case rpc_call(Node, erlang, process_info, [Pid, Fields]) of
        undefined -> false;
        Info -> {true, process_row_from_info(Pid, Key, Info)}
    end.

process_row_from_info(Pid, Key, Info) ->
    Name = case proplists:get_value(registered_name, Info) of
        [] -> Pid;
        RegName -> RegName
    end,
    Metric = proplists:get_value(Key, Info, 0),
    {Metric, Pid, Name, proplists:get_value(memory, Info, 0),
     proplists:get_value(reductions, Info, 0),
     proplists:get_value(message_queue_len, Info, 0),
     proplists:get_value(current_function, Info)}.

ets_info(Limit) ->
    Items = lists:filtermap(fun ets_row/1, ets:all()),
    Sorted = lists:reverse(lists:keysort(1, Items)),
    lists:sublist(Sorted, Limit).

remote_ets_info(Node, Limit) ->
    Tabs = rpc_call(Node, ets, all, []),
    Items = lists:filtermap(fun(Tab) -> remote_ets_row(Node, Tab) end, Tabs),
    Sorted = lists:reverse(lists:keysort(1, Items)),
    lists:sublist(Sorted, Limit).

ets_row(Tab) ->
    case catch ets:info(Tab) of
        undefined -> false;
        {'EXIT', _} -> false;
        Info -> {true, ets_row_from_info(Tab, Info)}
    end.

remote_ets_row(Node, Tab) ->
    case rpc_call(Node, ets, info, [Tab]) of
        undefined -> false;
        Info -> {true, ets_row_from_info(Tab, Info)}
    end.

ets_row_from_info(Tab, Info) ->
    MemoryWords = proplists:get_value(memory, Info, 0),
    {MemoryWords, proplists:get_value(name, Info, Tab),
     proplists:get_value(size, Info, 0),
     proplists:get_value(type, Info, unknown),
     proplists:get_value(owner, Info, undefined)}.

rpc_call(Node, Module, Function, Args) ->
    case rpc:call(Node, Module, Function, Args) of
        {badrpc, Reason} ->
            io:format("RPC failed: ~p:~p/~p on ~p: ~p~n", [Module, Function, length(Args), Node, Reason]),
            halt(1);
        Result ->
            Result
    end.

print_snapshot_data(#{system := System, applications := Apps, top_processes := Processes, ets_tables := Ets}) ->
    print_system(System),
    print_applications(Apps),
    print_processes(Processes),
    print_ets(Ets).

print_system(System) ->
    print_section("System"),
    io:format("OTP: ~s~n", [maps:get(otp_release, System)]),
    io:format("Processes: ~p/~p~n", [maps:get(process_count, System), maps:get(process_limit, System)]),
    io:format("Ports: ~p/~p~n", [maps:get(port_count, System), maps:get(port_limit, System)]),
    io:format("Atoms: ~p/~p~n", [maps:get(atom_count, System), maps:get(atom_limit, System)]),
    io:format("Memory: ~p~n", [maps:get(memory, System)]).

print_applications(Apps) ->
    print_section("Applications"),
    Rows = lists:sort(maps:to_list(Apps)),
    io:format("~-24s ~10s ~12s ~12s ~8s ~10s ~s~n",
              ["App", "Processes", "Memory", "Reductions", "MsgQ", "Status", "Version"]),
    lists:foreach(fun({App, S}) ->
        io:format("~-24s ~10s ~12s ~12s ~8s ~10s ~s~n", [
            term(App),
            term(maps:get(process_count, S)),
            text(bytes(maps:get(memory, S))),
            term(maps:get(reductions, S)),
            term(maps:get(msgq, S)),
            term(maps:get(status, S)),
            term(maps:get(version, S))
        ])
    end, Rows).

print_processes(Processes) ->
    print_section("Top Processes By Memory"),
    io:format("~-16s ~-24s ~12s ~12s ~8s ~s~n", ["Pid", "Name", "Memory", "Reductions", "MsgQ", "CurrentFunction"]),
    lists:foreach(fun({_Metric, Pid, Name, Memory, Reds, MsgQ, Current}) ->
        io:format("~-16s ~-24s ~12s ~12s ~8s ~s~n", [
            term(Pid), term(Name), text(bytes(Memory)), term(Reds), term(MsgQ), term(Current)
        ])
    end, Processes).

print_ets(Ets) ->
    print_section("ETS Tables By Memory Words"),
    io:format("~-32s ~10s ~12s ~12s ~s~n", ["Name", "Size", "MemoryWords", "Type", "Owner"]),
    lists:foreach(fun({MemoryWords, Name, Size, Type, Owner}) ->
        io:format("~-32s ~10s ~12s ~12s ~s~n", [
            term(Name), term(Size), term(MemoryWords), term(Type), term(Owner)
        ])
    end, Ets).

print_section(Title) ->
    io:format("~n== ~s ==~n", [Title]).

bytes(Bytes) when is_integer(Bytes), Bytes >= 1024 * 1024 ->
    io_lib:format("~.2f MiB", [Bytes / (1024 * 1024)]);
bytes(Bytes) when is_integer(Bytes), Bytes >= 1024 ->
    io_lib:format("~.2f KiB", [Bytes / 1024]);
bytes(Bytes) when is_integer(Bytes) ->
    io_lib:format("~p B", [Bytes]);
bytes(Other) ->
    io_lib:format("~p", [Other]).

term(Term) ->
    lists:flatten(io_lib:format("~p", [Term])).

text(IoData) ->
    lists:flatten(IoData).
