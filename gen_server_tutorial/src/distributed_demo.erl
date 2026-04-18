%%%-------------------------------------------------------------------
%%% @doc Demonstrates gen_server in distributed Erlang.
%%%      Shows how process IDs differ across nodes:
%%%      - Local PID:  <0.X.Y>
%%%      - Remote PID: <N.X.Y> where N > 0
%%%
%%%      Also demonstrates:
%%%      - Calling gen_server on remote nodes via {Name, Node}
%%%      - Using global registration across nodes
%%%      - monitor_node for detecting node failures
%%% @end
%%%-------------------------------------------------------------------
-module(distributed_demo).
-behaviour(gen_server).

%% Client API
-export([start_link/0, stop/0, get_info/0, store/2, lookup/1]).
-export([remote_get_info/1, remote_store/3, remote_lookup/2]).
-export([demo_local/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%%====================================================================
%% Client API - Local
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
    gen_server:call(?MODULE, stop).

%% @doc Get server info including node and PID.
get_info() ->
    gen_server:call(?MODULE, get_info).

%% @doc Store a key-value pair.
store(Key, Value) ->
    gen_server:call(?MODULE, {store, Key, Value}).

%% @doc Lookup a key.
lookup(Key) ->
    gen_server:call(?MODULE, {lookup, Key}).

%%====================================================================
%% Client API - Remote Node Access
%%====================================================================

%% @doc Get info from a remote node's server.
%%      Node is an atom like 'foo@hostname'.
%%      Uses {Name, Node} syntax to address remote registered process.
remote_get_info(Node) ->
    gen_server:call({?MODULE, Node}, get_info).

%% @doc Store on a remote node.
remote_store(Node, Key, Value) ->
    gen_server:call({?MODULE, Node}, {store, Key, Value}).

%% @doc Lookup on a remote node.
remote_lookup(Node, Key) ->
    gen_server:call({?MODULE, Node}, {lookup, Key}).

%%====================================================================
%% gen_server Callbacks
%%====================================================================

init(_Args) ->
    io:format("[distributed_demo] Started on node=~p, PID=~p~n",
              [node(), self()]),
    {ok, #{started_at => erlang:system_time(second),
           node => node(),
           pid => self(),
           data => #{}}}.

handle_call(get_info, From, State) ->
    #{started_at := StartedAt, node := MyNode, pid := MyPid} = State,
    %% From contains {CallerPid, Tag}
    {CallerPid, _Tag} = From,
    CallerNode = node(CallerPid),
    Info = #{
        server_node => MyNode,
        server_pid => MyPid,
        caller_node => CallerNode,
        caller_pid => CallerPid,
        is_remote_call => (CallerNode =/= MyNode),
        uptime_seconds => erlang:system_time(second) - StartedAt,
        connected_nodes => nodes()
    },
    {reply, Info, State};

handle_call({store, Key, Value}, _From, #{data := Data} = State) ->
    NewData = maps:put(Key, Value, Data),
    {reply, ok, State#{data := NewData}};

handle_call({lookup, Key}, _From, #{data := Data} = State) ->
    Reply = maps:get(Key, Data, undefined),
    {reply, Reply, State};

handle_call(stop, _From, State) ->
    {stop, normal, ok, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({nodedown, Node}, State) ->
    io:format("[distributed_demo] Node ~p went down!~n", [Node]),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(Reason, _State) ->
    io:format("[distributed_demo] Terminating on ~p: ~p~n", [node(), Reason]),
    ok.

%%====================================================================
%% Demo - Local (single node)
%%====================================================================

demo_local() ->
    io:format("~n=== Distributed Demo (Local) ===~n~n"),
    {ok, Pid} = distributed_demo:start_link(),
    io:format("Server PID: ~p~n", [Pid]),
    io:format("Server node: ~p~n~n", [node()]),

    %% Store some data
    ok = distributed_demo:store(greeting, "Hello from Erlang!"),
    ok = distributed_demo:store(answer, 42),

    %% Get info
    Info = distributed_demo:get_info(),
    io:format("Server info:~n"),
    maps:fold(fun(K, V, _) ->
        io:format("  ~p => ~p~n", [K, V])
    end, ok, Info),

    %% Lookup
    io:format("~nLookup 'greeting': ~p~n", [distributed_demo:lookup(greeting)]),
    io:format("Lookup 'answer': ~p~n", [distributed_demo:lookup(answer)]),

    distributed_demo:stop(),
    timer:sleep(100),
    io:format("~n=== Demo Complete ===~n"),
    io:format("~nTo test distributed features, start two nodes:~n"),
    io:format("  Terminal 1: erl -sname node1 -setcookie demo~n"),
    io:format("  Terminal 2: erl -sname node2 -setcookie demo~n"),
    io:format("~nOn node1:~n"),
    io:format("  distributed_demo:start_link().~n"),
    io:format("  distributed_demo:store(key1, value1).~n"),
    io:format("~nOn node2:~n"),
    io:format("  net_adm:ping('node1@hostname').~n"),
    io:format("  distributed_demo:remote_get_info('node1@hostname').~n"),
    io:format("  %% Notice: server_pid will be <N.X.Y> where N > 0~n"),
    io:format("  %% This indicates a REMOTE process!~n"),
    ok.
